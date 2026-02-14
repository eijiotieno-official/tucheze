import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../base/compatibility_layer_model.dart';
import '../enum/compatibility_layer_type.dart';

/// Service class for managing DXVK and VKD3D-Proton compatibility layers
/// Handles fetching, downloading, and storing compatibility layers
class CompatibilityLayerService {
  static const String _metadataFileName = 'metadata.json';
  static const String _dxvkRepo = 'doitsujin/dxvk';
  static const String _vkd3dProtonRepo = 'HansKristian-Work/vkd3d-proton';
  static const String _zstdRepo = 'facebook/zstd';
  static const String _zstdVersion = 'v1.5.6'; // Update as needed

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

  /// Fetch available DXVK versions from GitHub releases
  Future<Either<String, List<CompatibilityLayer>>>
  getAvailableDXVKLayers() async {
    _logger.i('Fetching available DXVK versions...');
    return _fetchLayersFromGitHub(_dxvkRepo, CompatibilityLayerType.dxvk);
  }

  /// Fetch available VKD3D-Proton versions from GitHub releases
  Future<Either<String, List<CompatibilityLayer>>>
  getAvailableVKD3DProtonLayers() async {
    _logger.i('Fetching available VKD3D-Proton versions...');
    return _fetchLayersFromGitHub(
      _vkd3dProtonRepo,
      CompatibilityLayerType.vkd3dProton,
    );
  }

  /// Generic method to fetch compatibility layers from GitHub releases
  Future<Either<String, List<CompatibilityLayer>>> _fetchLayersFromGitHub(
    String repo,
    CompatibilityLayerType type,
  ) async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$repo/releases');
      _logger.d('Fetching from: $url');

      final response = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        final error =
            'Failed to fetch compatibility layers: HTTP ${response.statusCode}';
        _logger.e(error);
        return Left(error);
      }

      final List<dynamic> releases = json.decode(response.body);
      final List<CompatibilityLayer> layers = [];

      // Get compatibility layers directory to check what's downloaded
      final layersDir = await _getCompatibilityLayersDirectory();

      for (final release in releases) {
        try {
          final name = release['name'] ?? release['tag_name'] ?? '';
          if (name.isEmpty) continue;

          final assets = release['assets'] as List?;
          if (assets == null || assets.isEmpty) continue;

          // Find tar.gz, tar.xz, or tar.zst asset for Linux
          final asset = assets.firstWhere((a) {
            final assetName = (a['name'] as String).toLowerCase();
            // For DXVK, look for linux tar.gz files
            // For VKD3D-Proton, look for tar.zst files
            return (assetName.endsWith('.tar.gz') ||
                    assetName.endsWith('.tar.xz') ||
                    assetName.endsWith('.tar.zst')) &&
                !assetName.contains('macos') &&
                !assetName.contains('mingw') &&
                !assetName.contains('native');
          }, orElse: () => null);

          if (asset == null) continue;

          // Check if layer is downloaded by checking if directory exists
          final layerDir = Directory('${layersDir.path}/$name');
          final isDownloaded = await layerDir.exists();
          final localPath = isDownloaded ? layerDir.path : null;

          final layer = CompatibilityLayer(
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

          layers.add(layer);
        } catch (e) {
          _logger.w('Failed to parse release: $e');
          continue;
        }
      }

      _logger.i('Found ${layers.length} ${type.displayName} versions');
      return Right(layers);
    } catch (e, stackTrace) {
      final error = 'Error fetching compatibility layers: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Download a compatibility layer
  Future<Either<String, CompatibilityLayer>> downloadLayer(
    CompatibilityLayer layer,
    Function(double progress)? onProgress,
  ) async {
    _logger.i('Starting download: ${layer.name}');

    try {
      // Get storage directory
      final dir = await _getCompatibilityLayersDirectory();
      final layerDir = Directory('${dir.path}/${layer.name}');

      if (await layerDir.exists()) {
        _logger.w('Compatibility layer already exists: ${layer.name}');
        return Left('Compatibility layer already downloaded');
      }

      // Determine file extension from download URL
      final url = layer.downloadUrl;
      String extension = '.tar.gz';
      if (url.endsWith('.tar.zst')) {
        extension = '.tar.zst';
      } else if (url.endsWith('.tar.xz')) {
        extension = '.tar.xz';
      } else if (url.endsWith('.tar.gz')) {
        extension = '.tar.gz';
      } else if (url.contains('.tar.zst')) {
        extension = '.tar.zst';
      } else if (url.contains('.tar.xz')) {
        extension = '.tar.xz';
      }

      _logger.d('Detected archive extension: $extension from URL: $url');

      // Download file with correct extension
      final downloadPath = '${dir.path}/${layer.name}$extension';
      final downloadResult = await _downloadFile(
        layer.downloadUrl,
        downloadPath,
        onProgress,
      );

      if (downloadResult.isLeft()) {
        return Left(downloadResult.fold((error) => error, (r) => ''));
      }

      _logger.i('Download complete, extracting...');

      // Extract archive
      await layerDir.create(recursive: true);
      final extractResult = await _extractArchive(downloadPath, layerDir.path);

      // Delete downloaded archive
      await File(downloadPath).delete();

      if (extractResult.isLeft()) {
        await layerDir.delete(recursive: true);
        return Left(extractResult.fold((error) => error, (r) => ''));
      }

      // Update layer with local path
      final updatedLayer = layer.copyWith(
        isDownloaded: true,
        localPath: layerDir.path,
      );

      // Save metadata to layer directory
      await _saveLayerMetadata(updatedLayer);

      _logger.i('Successfully downloaded and extracted: ${layer.name}');
      return Right(updatedLayer);
    } catch (e, stackTrace) {
      final error = 'Download failed: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Download file from URL with progress tracking
  Future<Either<String, String>> _downloadFile(
    String url,
    String savePath,
    Function(double progress)? onProgress,
  ) async {
    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        return Left('Download failed: HTTP ${response.statusCode}');
      }

      final file = File(savePath);
      final sink = file.openWrite();

      final contentLength = response.contentLength;
      int downloaded = 0;

      await for (final chunk in response) {
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

  /// Extract tar.gz, tar.xz, or tar.zst archive
  Future<Either<String, void>> _extractArchive(
    String archivePath,
    String extractPath,
  ) async {
    try {
      _logger.d('Extracting: $archivePath to $extractPath');

      // Determine compression type from file extension
      final isTarZst = archivePath.endsWith('.tar.zst');
      final isTarXz = archivePath.endsWith('.tar.xz');
      final isTarGz = archivePath.endsWith('.tar.gz');

      if (!isTarZst && !isTarXz && !isTarGz) {
        return Left('Unsupported archive format: $archivePath');
      }

      // For tar.zst files, use system command as Dart archive package doesn't support zstd
      if (isTarZst) {
        _logger.d(
          'Archive format: tar.zst (Zstandard compression) - using system command',
        );
        return _extractTarZstWithSystemCommand(archivePath, extractPath);
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

  /// Extract tar.zst archive using system command
  Future<Either<String, void>> _extractTarZstWithSystemCommand(
    String archivePath,
    String extractPath,
  ) async {
    try {
      // Get zstd path (system or local)
      final zstdPath = await _ensureZstdAvailable();
      if (zstdPath == null) {
        return Left(
          'Failed to get zstd. Please install it manually: sudo dnf install zstd',
        );
      }

      _logger.d('Using zstd: $zstdPath');

      // Extract tar.zst file using system command
      // tar --use-compress-program=zstd -xf archive.tar.zst -C extract_path
      final result = await Process.run('tar', [
        '--use-compress-program=$zstdPath',
        '-xf',
        archivePath,
        '-C',
        extractPath,
      ]);

      if (result.exitCode != 0) {
        final error = 'tar extraction failed: ${result.stderr}';
        _logger.e(error);
        return Left(error);
      }

      _logger.d('tar.zst extraction complete');
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.e('tar.zst extraction error', error: e, stackTrace: stackTrace);
      return Left('Failed to extract tar.zst: $e');
    }
  }

  /// Ensure zstd is available - check system, then download if needed
  /// Returns path to zstd binary or null if unavailable
  Future<String?> _ensureZstdAvailable() async {
    try {
      // First, check if system zstd is available
      final systemZstdCheck = await Process.run('which', ['zstd']);
      if (systemZstdCheck.exitCode == 0) {
        final path = (systemZstdCheck.stdout as String).trim();
        _logger.d('Found system zstd: $path');
        return path;
      }

      _logger.i('System zstd not found, checking for local zstd...');

      // Get local zstd path in app directory
      final localZstdPath = await _getLocalZstdPath();
      final localZstdFile = File(localZstdPath);

      // Check if local zstd exists and is executable
      if (await localZstdFile.exists()) {
        _logger.d('Found local zstd: $localZstdPath');
        // Ensure it's executable
        await Process.run('chmod', ['+x', localZstdPath]);
        return localZstdPath;
      }

      _logger.i('Local zstd not found, downloading static binary...');

      // Download static zstd binary
      final downloadResult = await _downloadZstdBinary(localZstdPath);
      if (downloadResult.isLeft()) {
        _logger.e(
          'Failed to download zstd: ${downloadResult.fold((l) => l, (r) => "")}',
        );
        return null;
      }

      _logger.i('Successfully downloaded zstd to: $localZstdPath');
      return localZstdPath;
    } catch (e, stackTrace) {
      _logger.e(
        'Error ensuring zstd availability',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get path where local zstd binary should be stored
  Future<String> _getLocalZstdPath() async {
    final layersDir = await _getCompatibilityLayersDirectory();
    return '${layersDir.parent.path}/bin/zstd';
  }

  /// Download static zstd binary from GitHub releases
  Future<Either<String, void>> _downloadZstdBinary(String savePath) async {
    try {
      // Determine architecture
      final unameResult = await Process.run('uname', ['-m']);
      final arch = (unameResult.stdout as String).trim();

      String archSuffix;
      if (arch == 'x86_64') {
        archSuffix = 'linux-x86_64';
      } else if (arch == 'aarch64' || arch == 'arm64') {
        archSuffix = 'linux-aarch64';
      } else {
        return Left('Unsupported architecture: $arch');
      }

      // Construct download URL for static zstd binary
      // Instead of downloading the tar, we'll use a direct static binary source
      // Using a reliable static build from GitHub releases
      final url =
          'https://github.com/$_zstdRepo/releases/download/$_zstdVersion/zstd-$_zstdVersion-$archSuffix.tar.gz';

      _logger.d('Downloading zstd from: $url');

      // Download the archive
      final tempDir = await Directory.systemTemp.createTemp('zstd_download');
      final tempArchive = '${tempDir.path}/zstd.tar.gz';

      final downloadResult = await _downloadFile(url, tempArchive, null);
      if (downloadResult.isLeft()) {
        await tempDir.delete(recursive: true);
        return Left(downloadResult.fold((error) => error, (r) => ''));
      }

      // Extract the archive
      final bytes = File(tempArchive).readAsBytesSync();
      final archive = TarDecoder().decodeBytes(
        GZipDecoder().decodeBytes(bytes),
      );

      // Find the zstd binary in the archive
      for (final file in archive) {
        if (file.name.endsWith('/zstd') && file.isFile) {
          // Create bin directory if it doesn't exist
          final saveFile = File(savePath);
          await saveFile.parent.create(recursive: true);

          // Write the binary
          await saveFile.writeAsBytes(file.content as List<int>);

          // Make it executable
          await Process.run('chmod', ['+x', savePath]);

          _logger.d('Extracted zstd binary to: $savePath');
          break;
        }
      }

      // Clean up temp directory
      await tempDir.delete(recursive: true);

      // Verify the binary works
      final testResult = await Process.run(savePath, ['--version']);
      if (testResult.exitCode != 0) {
        return Left('Downloaded zstd binary is not functional');
      }

      return const Right(null);
    } catch (e, stackTrace) {
      _logger.e('Error downloading zstd', error: e, stackTrace: stackTrace);
      return Left('Failed to download zstd: $e');
    }
  }

  /// Delete a downloaded compatibility layer
  Future<Either<String, void>> deleteLayer(CompatibilityLayer layer) async {
    _logger.i('Deleting compatibility layer: ${layer.name}');

    try {
      if (layer.localPath == null) {
        return Left('Compatibility layer has no local path');
      }

      final dir = Directory(layer.localPath!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        _logger.d('Deleted directory: ${layer.localPath}');
      }

      _logger.i('Successfully deleted: ${layer.name}');
      return const Right(null);
    } catch (e, stackTrace) {
      final error = 'Failed to delete compatibility layer: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Get list of downloaded compatibility layers by scanning filesystem
  Future<Either<String, List<CompatibilityLayer>>> getDownloadedLayers() async {
    try {
      final layersDir = await _getCompatibilityLayersDirectory();
      final layers = <CompatibilityLayer>[];

      // List all directories in compatibility layers directory
      final entities = await layersDir.list().toList();

      for (final entity in entities) {
        if (entity is Directory) {
          try {
            // Try to read metadata.json from layer directory
            final metadataFile = File('${entity.path}/$_metadataFileName');

            if (await metadataFile.exists()) {
              final jsonContent = await metadataFile.readAsString();
              final layer = CompatibilityLayer.fromJson(jsonContent);
              layers.add(layer);
            } else {
              // If no metadata file, create a basic layer object
              final layerName = entity.path.split('/').last;
              _logger.w('No metadata found for layer: $layerName');

              layers.add(
                CompatibilityLayer(
                  name: layerName,
                  version: 'unknown',
                  type: CompatibilityLayerType.dxvk, // Default fallback
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
              'Failed to load layer from ${entity.path}',
              error: e,
              stackTrace: stackTrace,
            );
            continue;
          }
        }
      }

      _logger.d('Found ${layers.length} downloaded compatibility layers');
      return Right(layers);
    } catch (e, stackTrace) {
      final error = 'Failed to load downloaded compatibility layers: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Save compatibility layer metadata to its directory
  Future<void> _saveLayerMetadata(CompatibilityLayer layer) async {
    try {
      if (layer.localPath == null) {
        throw Exception('Compatibility layer has no local path');
      }

      final metadataFile = File('${layer.localPath}/$_metadataFileName');
      await metadataFile.writeAsString(layer.toJson());
      _logger.d('Saved metadata for layer: ${layer.name}');
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to save layer metadata',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get the directory where compatibility layers are stored
  /// Uses ~/.local/share/tucheze/compatibility_layers on Linux
  Future<Directory> _getCompatibilityLayersDirectory() async {
    String layersPath;

    if (Platform.isLinux) {
      // Use XDG standard: ~/.local/share/tucheze/compatibility_layers
      final home = Platform.environment['HOME'];
      if (home == null) {
        throw Exception('HOME environment variable not set');
      }
      layersPath = '$home/.local/share/tucheze/compatibility_layers';
    } else {
      // Fallback for other platforms
      final appDir = await getApplicationDocumentsDirectory();
      layersPath = '${appDir.path}/tucheze/compatibility_layers';
    }

    final layersDir = Directory(layersPath);

    if (!await layersDir.exists()) {
      await layersDir.create(recursive: true);
      _logger.d('Created compatibility layers directory: ${layersDir.path}');
    }

    return layersDir;
  }
}
