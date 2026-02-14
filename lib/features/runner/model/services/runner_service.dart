import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../base/runner_model.dart';
import '../enum/runner_type.dart';

/// Service class for managing Wine/Proton runners
/// Handles fetching, downloading, and storing runners
class RunnerService {
  static const String _metadataFileName = 'metadata.json';
  static const String _protonGERepo = 'GloriousEggroll/proton-ge-custom';
  static const String _wineGERepo = 'GloriousEggroll/wine-ge-custom';
  static const String _lutrisWineRepo = 'lutris/wine';

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Fetch available Proton-GE runners from GitHub releases
  Future<Either<String, List<Runner>>> getAvailableProtonRunners() async {
    _logger.i('Fetching available Proton-GE runners...');
    return _fetchRunnersFromGitHub(_protonGERepo, RunnerType.protonGE);
  }

  /// Fetch available Wine-GE runners from GitHub releases
  Future<Either<String, List<Runner>>> getAvailableWineRunners() async {
    _logger.i('Fetching available Wine-GE runners...');
    return _fetchRunnersFromGitHub(_wineGERepo, RunnerType.wineGE);
  }

  /// Fetch available Lutris Wine runners from GitHub releases
  Future<Either<String, List<Runner>>> getAvailableLutrisRunners() async {
    _logger.i('Fetching available Lutris Wine runners...');
    return _fetchRunnersFromGitHub(_lutrisWineRepo, RunnerType.lutrisWine);
  }

  /// Generic method to fetch runners from GitHub releases
  Future<Either<String, List<Runner>>> _fetchRunnersFromGitHub(
    String repo,
    RunnerType type,
  ) async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$repo/releases');
      _logger.d('Fetching from: $url');

      final response = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        final error = 'Failed to fetch runners: HTTP ${response.statusCode}';
        _logger.e(error);
        return Left(error);
      }

      final List<dynamic> releases = json.decode(response.body);
      final List<Runner> runners = [];

      // Get runners directory to check what's downloaded
      final runnersDir = await _getRunnersDirectory();

      for (final release in releases) {
        try {
          final name = release['name'] ?? release['tag_name'] ?? '';
          if (name.isEmpty) continue;

          final assets = release['assets'] as List?;
          if (assets == null || assets.isEmpty) continue;

          // Find tar.gz or tar.xz asset
          final asset = assets.firstWhere(
            (a) =>
                (a['name'] as String).endsWith('.tar.gz') ||
                (a['name'] as String).endsWith('.tar.xz'),
            orElse: () => null,
          );

          if (asset == null) continue;

          // Check if runner is downloaded by checking if directory exists
          final runnerDir = Directory('${runnersDir.path}/$name');
          final isDownloaded = await runnerDir.exists();
          final localPath = isDownloaded ? runnerDir.path : null;

          final runner = Runner(
            name: name,
            version: release['tag_name'] ?? '',
            type: type,
            downloadUrl: asset['browser_download_url'] ?? '',
            sizeBytes: asset['size'] ?? 0,
            description: release['body'] ?? '',
            releaseDate: DateTime.parse(
              release['published_at'] ?? DateTime.now().toIso8601String(),
            ),
            isDownloaded: isDownloaded,
            localPath: localPath,
          );

          runners.add(runner);
        } catch (e) {
          _logger.w('Failed to parse release: $e');
          continue;
        }
      }

      _logger.i('Found ${runners.length} ${type.displayName} runners');
      return Right(runners);
    } catch (e, stackTrace) {
      final error = 'Error fetching runners: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Download a runner
  Future<Either<String, Runner>> downloadRunner(
    Runner runner,
    Function(double progress)? onProgress,
  ) async {
    _logger.i('Starting download: ${runner.name}');

    try {
      // Get storage directory
      final dir = await _getRunnersDirectory();
      final runnerDir = Directory('${dir.path}/${runner.name}');

      if (await runnerDir.exists()) {
        _logger.w('Runner already exists: ${runner.name}');
        return Left('Runner already downloaded');
      }

      // Determine file extension from download URL
      final url = runner.downloadUrl;
      String extension = '.tar.gz';
      if (url.endsWith('.tar.xz')) {
        extension = '.tar.xz';
      } else if (url.endsWith('.tar.gz')) {
        extension = '.tar.gz';
      } else if (url.contains('.tar.xz')) {
        extension = '.tar.xz';
      }

      _logger.d('Detected archive extension: $extension from URL: $url');

      // Download file with correct extension
      final downloadPath = '${dir.path}/${runner.name}$extension';
      final downloadResult = await _downloadFile(
        runner.downloadUrl,
        downloadPath,
        onProgress,
      );

      if (downloadResult.isLeft()) {
        return Left(downloadResult.fold((error) => error, (r) => ''));
      }

      _logger.i('Download complete, extracting...');

      // Extract archive
      await runnerDir.create(recursive: true);
      final extractResult = await _extractArchive(downloadPath, runnerDir.path);

      // Delete downloaded archive
      await File(downloadPath).delete();

      if (extractResult.isLeft()) {
        await runnerDir.delete(recursive: true);
        return Left(extractResult.fold((error) => error, (r) => ''));
      }

      // Update runner with local path
      final updatedRunner = runner.copyWith(
        isDownloaded: true,
        localPath: runnerDir.path,
      );

      // Save metadata to runner directory
      await _saveRunnerMetadata(updatedRunner);

      _logger.i('Successfully downloaded and extracted: ${runner.name}');
      return Right(updatedRunner);
    } catch (e, stackTrace) {
      final error = 'Failed to download runner: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Download a file with progress tracking
  Future<Either<String, String>> _downloadFile(
    String url,
    String savePath,
    Function(double progress)? onProgress,
  ) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        return Left('Download failed: HTTP ${response.statusCode}');
      }

      final file = File(savePath);
      final sink = file.openWrite();
      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;

        if (onProgress != null && contentLength > 0) {
          onProgress(downloaded / contentLength);
        }
      }

      await sink.close();
      _logger.d('Downloaded to: $savePath');
      return Right(savePath);
    } catch (e, stackTrace) {
      _logger.e('Download error', error: e, stackTrace: stackTrace);
      return Left('Download failed: $e');
    }
  }

  /// Extract tar.gz or tar.xz archive
  Future<Either<String, void>> _extractArchive(
    String archivePath,
    String extractPath,
  ) async {
    try {
      _logger.d('Extracting: $archivePath to $extractPath');

      // Determine compression type from file extension
      final isTarXz = archivePath.endsWith('.tar.xz');
      final isTarGz = archivePath.endsWith('.tar.gz');

      if (!isTarXz && !isTarGz) {
        return Left('Unsupported archive format: $archivePath');
      }

      _logger.d(
        'Archive format: ${isTarXz ? 'tar.xz (XZ compression)' : 'tar.gz (GZip compression)'}',
      );

      // Read archive file into bytes
      final bytes = File(archivePath).readAsBytesSync();

      // Decompress based on format
      final decompressedBytes = isTarXz
          ? XZDecoder().decodeBytes(bytes)
          : GZipDecoder().decodeBytes(bytes);

      // Decode tar archive
      final archive = TarDecoder().decodeBytes(decompressedBytes);

      _logger.d('Archive contains ${archive.length} files/directories');

      // Extract files
      int filesExtracted = 0;
      for (final file in archive) {
        final filename = '$extractPath/${file.name}';
        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
          filesExtracted++;
        } else {
          await Directory(filename).create(recursive: true);
        }
      }

      _logger.d('Extraction complete: $filesExtracted files extracted');
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.e('Extraction error', error: e, stackTrace: stackTrace);
      return Left('Failed to extract archive: $e');
    }
  }

  /// Delete a downloaded runner
  Future<Either<String, void>> deleteRunner(Runner runner) async {
    _logger.i('Deleting runner: ${runner.name}');

    try {
      if (runner.localPath == null) {
        return Left('Runner has no local path');
      }

      final dir = Directory(runner.localPath!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        _logger.d('Deleted directory: ${runner.localPath}');
      }

      _logger.i('Successfully deleted: ${runner.name}');
      return const Right(null);
    } catch (e, stackTrace) {
      final error = 'Failed to delete runner: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Get list of downloaded runners by scanning filesystem
  Future<Either<String, List<Runner>>> getDownloadedRunners() async {
    try {
      final runnersDir = await _getRunnersDirectory();
      final runners = <Runner>[];

      // List all directories in runners directory
      final entities = await runnersDir.list().toList();

      for (final entity in entities) {
        if (entity is Directory) {
          try {
            // Try to read metadata.json from runner directory
            final metadataFile = File('${entity.path}/$_metadataFileName');

            if (await metadataFile.exists()) {
              final jsonContent = await metadataFile.readAsString();
              final runner = Runner.fromJson(jsonContent);
              runners.add(runner);
            } else {
              // If no metadata file, create a basic runner object
              final runnerName = entity.path.split('/').last;
              _logger.w('No metadata found for runner: $runnerName');

              runners.add(
                Runner(
                  name: runnerName,
                  version: 'unknown',
                  type: RunnerType.wineGE, // Default fallback
                  downloadUrl: '',
                  sizeBytes: 0,
                  description: 'Metadata not available',
                  releaseDate: DateTime.now(),
                  isDownloaded: true,
                  localPath: entity.path,
                ),
              );
            }
          } catch (e, stackTrace) {
            _logger.w(
              'Failed to load runner from ${entity.path}',
              error: e,
              stackTrace: stackTrace,
            );
            continue;
          }
        }
      }

      _logger.d('Found ${runners.length} downloaded runners');
      return Right(runners);
    } catch (e, stackTrace) {
      final error = 'Failed to load downloaded runners: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Save runner metadata to its directory
  Future<void> _saveRunnerMetadata(Runner runner) async {
    try {
      if (runner.localPath == null) {
        throw Exception('Runner has no local path');
      }

      final metadataFile = File('${runner.localPath}/$_metadataFileName');
      await metadataFile.writeAsString(runner.toJson());
      _logger.d('Saved metadata for runner: ${runner.name}');
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to save runner metadata',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get the directory where runners are stored
  /// Uses ~/.local/share/tucheze/runners on Linux
  Future<Directory> _getRunnersDirectory() async {
    String runnersPath;

    if (Platform.isLinux) {
      // Use XDG standard: ~/.local/share/tucheze/runners
      final home = Platform.environment['HOME'];
      if (home == null) {
        throw Exception('HOME environment variable not set');
      }
      runnersPath = '$home/.local/share/tucheze/runners';
    } else {
      // Fallback for other platforms
      final appDir = await getApplicationDocumentsDirectory();
      runnersPath = '${appDir.path}/tucheze/runners';
    }

    final runnersDir = Directory(runnersPath);

    if (!await runnersDir.exists()) {
      await runnersDir.create(recursive: true);
      _logger.d('Created runners directory: ${runnersDir.path}');
    }

    return runnersDir;
  }
}
