import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../base/performance_tool_model.dart';
import '../enum/performance_tool_type.dart';

/// Service class for managing performance tools (MangoHud, GameMode)
/// Handles checking, downloading, and toggling performance tools
class PerformanceToolService {
  static const String _mangoHudEnabledKey = 'mangohud_enabled';
  static const String _gameModeEnabledKey = 'gamemode_enabled';
  static const String _vkBasaltEnabledKey = 'vkbasalt_enabled';
  static const String _cpuGovernorEnabledKey = 'cpugovernor_enabled';

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

  /// Check if MangoHud is available (system or local)
  Future<Either<String, PerformanceTool>> checkMangoHud() async {
    _logger.i('Checking MangoHud availability...');

    try {
      // Check if system MangoHud is available
      final systemCheck = await Process.run('which', ['mangohud']);
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_mangoHudEnabledKey) ?? false;

      if (systemCheck.exitCode == 0) {
        final path = (systemCheck.stdout as String).trim();
        _logger.d('Found system MangoHud: $path');

        return Right(
          PerformanceTool(
            name: 'MangoHud (System)',
            version: 'system',
            type: PerformanceToolType.mangoHud,
            downloadUrl: '',
            sizeBytes: 0,
            description: 'Performance overlay for Vulkan and OpenGL',
            releaseDate: DateTime.now(),
            isDownloaded: true,
            localPath: path,
            isEnabled: isEnabled,
          ),
        );
      }

      // Check for local MangoHud
      final localPath = await _getMangoHudLocalPath();
      final localFile = File(localPath);

      if (await localFile.exists()) {
        _logger.d('Found local MangoHud: $localPath');

        return Right(
          PerformanceTool(
            name: 'MangoHud (Local)',
            version: 'local',
            type: PerformanceToolType.mangoHud,
            downloadUrl: '',
            sizeBytes: 0,
            description: 'Performance overlay for Vulkan and OpenGL',
            releaseDate: DateTime.now(),
            isDownloaded: true,
            localPath: localPath,
            isEnabled: isEnabled,
          ),
        );
      }

      // Not installed
      _logger.d('MangoHud not found');
      return Right(
        PerformanceTool(
          name: 'MangoHud',
          version: 'latest',
          type: PerformanceToolType.mangoHud,
          downloadUrl: _getMangoHudInstallInstructions(),
          sizeBytes: 0,
          description: 'Performance overlay for Vulkan and OpenGL',
          releaseDate: DateTime.now(),
          isDownloaded: false,
          isEnabled: false,
        ),
      );
    } catch (e, stackTrace) {
      final error = 'Error checking MangoHud: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Check if GameMode is available (system or local)
  Future<Either<String, PerformanceTool>> checkGameMode() async {
    _logger.i('Checking GameMode availability...');

    try {
      // Check if system GameMode is available
      final systemCheck = await Process.run('which', ['gamemoderun']);
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_gameModeEnabledKey) ?? false;

      if (systemCheck.exitCode == 0) {
        final path = (systemCheck.stdout as String).trim();
        _logger.d('Found system GameMode: $path');

        return Right(
          PerformanceTool(
            name: 'GameMode (System)',
            version: 'system',
            type: PerformanceToolType.gameMode,
            downloadUrl: '',
            sizeBytes: 0,
            description: 'CPU governor optimization for gaming',
            releaseDate: DateTime.now(),
            isDownloaded: true,
            localPath: path,
            isEnabled: isEnabled,
          ),
        );
      }

      // Not installed
      _logger.d('GameMode not found');
      return Right(
        PerformanceTool(
          name: 'GameMode',
          version: 'latest',
          type: PerformanceToolType.gameMode,
          downloadUrl: _getGameModeInstallInstructions(),
          sizeBytes: 0,
          description: 'CPU governor optimization for gaming',
          releaseDate: DateTime.now(),
          isDownloaded: false,
          isEnabled: false,
        ),
      );
    } catch (e, stackTrace) {
      final error = 'Error checking GameMode: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Check if vkBasalt is available
  Future<Either<String, PerformanceTool>> checkVkBasalt() async {
    _logger.i('Checking vkBasalt availability...');

    try {
      // Check for Vulkan layer manifest (most reliable method)
      final manifestPaths = [
        '/usr/share/vulkan/implicit_layer.d/vkBasalt.json',
        '/usr/local/share/vulkan/implicit_layer.d/vkBasalt.json',
      ];

      // Check if vkBasalt library exists (note: library is in subdirectory)
      final systemPaths = [
        '/usr/lib64/vkbasalt/libvkbasalt.so',
        '/usr/lib/vkbasalt/libvkbasalt.so',
        '/usr/lib/x86_64-linux-gnu/vkbasalt/libvkbasalt.so',
        '/usr/lib32/vkbasalt/libvkbasalt.so',
        // Fallback: check directly in lib dirs
        '/usr/lib64/libvkbasalt.so',
        '/usr/lib/libvkbasalt.so',
      ];

      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_vkBasaltEnabledKey) ?? false;

      // Check manifest first (more reliable)
      for (final manifestPath in manifestPaths) {
        if (await File(manifestPath).exists()) {
          _logger.d('Found vkBasalt manifest: $manifestPath');

          return Right(
            PerformanceTool(
              name: 'vkBasalt (System)',
              version: 'system',
              type: PerformanceToolType.vkBasalt,
              downloadUrl: '',
              sizeBytes: 0,
              description: 'Post-processing effects for Vulkan games',
              releaseDate: DateTime.now(),
              isDownloaded: true,
              localPath: manifestPath,
              isEnabled: isEnabled,
            ),
          );
        }
      }

      // Fallback: check for library files
      for (final path in systemPaths) {
        if (await File(path).exists()) {
          _logger.d('Found vkBasalt library: $path');

          return Right(
            PerformanceTool(
              name: 'vkBasalt (System)',
              version: 'system',
              type: PerformanceToolType.vkBasalt,
              downloadUrl: '',
              sizeBytes: 0,
              description: 'Post-processing effects for Vulkan games',
              releaseDate: DateTime.now(),
              isDownloaded: true,
              localPath: path,
              isEnabled: isEnabled,
            ),
          );
        }
      }

      // Not installed
      _logger.d('vkBasalt not found');
      return Right(
        PerformanceTool(
          name: 'vkBasalt',
          version: 'latest',
          type: PerformanceToolType.vkBasalt,
          downloadUrl: _getVkBasaltInstallInstructions(),
          sizeBytes: 0,
          description: 'Post-processing effects for Vulkan games',
          releaseDate: DateTime.now(),
          isDownloaded: false,
          isEnabled: false,
        ),
      );
    } catch (e, stackTrace) {
      final error = 'Error checking vkBasalt: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Check if CPU Governor control is available
  Future<Either<String, PerformanceTool>> checkCpuGovernor() async {
    _logger.i('Checking CPU Governor availability...');

    try {
      // Check if cpupower is available
      final systemCheck = await Process.run('which', ['cpupower']);
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_cpuGovernorEnabledKey) ?? false;

      if (systemCheck.exitCode == 0) {
        final path = (systemCheck.stdout as String).trim();
        _logger.d('Found cpupower: $path');

        // Check current governor
        String currentGovernor = 'unknown';
        try {
          final governorFile = File(
            '/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor',
          );
          if (await governorFile.exists()) {
            currentGovernor = (await governorFile.readAsString()).trim();
          }
        } catch (e) {
          _logger.w('Could not read current governor: $e');
        }

        return Right(
          PerformanceTool(
            name: 'CPU Governor (System)',
            version: currentGovernor,
            type: PerformanceToolType.cpuGovernor,
            downloadUrl: '',
            sizeBytes: 0,
            description: 'Set CPU to performance mode for better gaming',
            releaseDate: DateTime.now(),
            isDownloaded: true,
            localPath: path,
            isEnabled: isEnabled,
          ),
        );
      }

      // cpupower not installed
      _logger.d('cpupower not found');
      return Right(
        PerformanceTool(
          name: 'CPU Governor',
          version: 'latest',
          type: PerformanceToolType.cpuGovernor,
          downloadUrl: _getCpuGovernorInstallInstructions(),
          sizeBytes: 0,
          description: 'Set CPU to performance mode for better gaming',
          releaseDate: DateTime.now(),
          isDownloaded: false,
          isEnabled: false,
        ),
      );
    } catch (e, stackTrace) {
      final error = 'Error checking CPU Governor: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Install MangoHud from package manager
  Future<Either<String, void>> installMangoHud() async {
    _logger.i('Installing MangoHud...');

    try {
      // Detect package manager and install
      final installCommand = await _detectAndInstallMangoHud();

      if (installCommand == null) {
        return Left(
          'Could not detect package manager. Please install MangoHud manually:\\n'
          'Fedora: sudo dnf install mangohud\\n'
          'Ubuntu/Debian: sudo apt install mangohud\\n'
          'Arch: sudo pacman -S mangohud',
        );
      }

      _logger.i('Successfully initiated MangoHud installation');
      return const Right(null);
    } catch (e, stackTrace) {
      final error = 'Error installing MangoHud: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Install GameMode from package manager
  Future<Either<String, void>> installGameMode() async {
    _logger.i('Installing GameMode...');

    try {
      // Detect package manager and install
      final installCommand = await _detectAndInstallGameMode();

      if (installCommand == null) {
        return Left(
          'Could not detect package manager. Please install GameMode manually:\\n'
          'Fedora: sudo dnf install gamemode\\n'
          'Ubuntu/Debian: sudo apt install gamemode\\n'
          'Arch: sudo pacman -S gamemode',
        );
      }

      _logger.i('Successfully initiated GameMode installation');
      return const Right(null);
    } catch (e, stackTrace) {
      final error = 'Error installing GameMode: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Install vkBasalt from package manager
  Future<Either<String, void>> installVkBasalt() async {
    _logger.i('Installing vkBasalt...');

    try {
      // Detect package manager and install
      final installCommand = await _detectAndInstallVkBasalt();

      if (installCommand == null) {
        return Left(
          'Could not detect package manager. Please install vkBasalt manually:\\n'
          'Fedora: sudo dnf install vkBasalt\\n'
          'Ubuntu/Debian: sudo apt install vkbasalt\\n'
          'Arch: sudo pacman -S vkbasalt',
        );
      }

      _logger.i('Successfully initiated vkBasalt installation');
      return const Right(null);
    } catch (e, stackTrace) {
      final error = 'Error installing vkBasalt: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Install CPU Governor tools (cpupower)
  Future<Either<String, void>> installCpuGovernor() async {
    _logger.i('Installing CPU Governor tools...');

    try {
      // Detect package manager and install
      final installCommand = await _detectAndInstallCpuGovernor();

      if (installCommand == null) {
        return Left(
          'Could not detect package manager. Please install cpupower manually:\\n'
          'Fedora: sudo dnf install kernel-tools\\n'
          'Ubuntu/Debian: sudo apt install linux-tools-generic\\n'
          'Arch: sudo pacman -S cpupower',
        );
      }

      _logger.i('Successfully initiated CPU Governor tools installation');
      return const Right(null);
    } catch (e, stackTrace) {
      final error = 'Error installing CPU Governor tools: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Toggle MangoHud enabled state
  Future<Either<String, bool>> toggleMangoHud(bool enabled) async {
    _logger.i('Toggling MangoHud: $enabled');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mangoHudEnabledKey, enabled);
      _logger.d('MangoHud enabled state saved: $enabled');
      return Right(enabled);
    } catch (e, stackTrace) {
      final error = 'Error toggling MangoHud: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Toggle GameMode enabled state
  Future<Either<String, bool>> toggleGameMode(bool enabled) async {
    _logger.i('Toggling GameMode: $enabled');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_gameModeEnabledKey, enabled);
      _logger.d('GameMode enabled state saved: $enabled');
      return Right(enabled);
    } catch (e, stackTrace) {
      final error = 'Error toggling GameMode: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Toggle vkBasalt enabled state
  Future<Either<String, bool>> toggleVkBasalt(bool enabled) async {
    _logger.i('Toggling vkBasalt: $enabled');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_vkBasaltEnabledKey, enabled);
      _logger.d('vkBasalt enabled state saved: $enabled');
      return Right(enabled);
    } catch (e, stackTrace) {
      final error = 'Error toggling vkBasalt: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Toggle CPU Governor (performance vs powersave)
  Future<Either<String, bool>> toggleCpuGovernor(bool enabled) async {
    _logger.i('Toggling CPU Governor: $enabled');

    try {
      // Set governor using cpupower
      final governor = enabled ? 'performance' : 'powersave';
      final result = await Process.run('pkexec', [
        'cpupower',
        'frequency-set',
        '-g',
        governor,
      ]);

      if (result.exitCode != 0) {
        final error = 'Failed to set CPU governor: ${result.stderr}';
        _logger.e(error);
        return Left(error);
      }

      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cpuGovernorEnabledKey, enabled);
      _logger.d('CPU Governor set to $governor and state saved: $enabled');
      return Right(enabled);
    } catch (e, stackTrace) {
      final error = 'Error toggling CPU Governor: $e';
      _logger.e(error, error: e, stackTrace: stackTrace);
      return Left(error);
    }
  }

  /// Get MangoHud enabled state
  Future<bool> isMangoHudEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_mangoHudEnabledKey) ?? false;
  }

  /// Get GameMode enabled state
  Future<bool> isGameModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_gameModeEnabledKey) ?? false;
  }

  /// Get vkBasalt enabled state
  Future<bool> isVkBasaltEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vkBasaltEnabledKey) ?? false;
  }

  /// Get CPU Governor enabled state
  Future<bool> isCpuGovernorEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cpuGovernorEnabledKey) ?? false;
  }

  /// Detect package manager and install MangoHud
  Future<String?> _detectAndInstallMangoHud() async {
    // Check for common package managers
    final packageManagers = {
      'dnf': 'pkexec dnf install -y mangohud',
      'apt': 'pkexec apt install -y mangohud',
      'pacman': 'pkexec pacman -S --noconfirm mangohud',
      'zypper': 'pkexec zypper install -y mangohud',
    };

    for (final entry in packageManagers.entries) {
      final checkResult = await Process.run('which', [entry.key]);
      if (checkResult.exitCode == 0) {
        _logger.d('Found package manager: ${entry.key}');

        // Launch installation in terminal (non-blocking)
        Process.start('sh', ['-c', entry.value]).then((process) {
          process.stdout.listen((data) {
            _logger.d('Install output: ${String.fromCharCodes(data)}');
          });
          process.stderr.listen((data) {
            // Package managers often output normal info to stderr
            _logger.d('Install info: ${String.fromCharCodes(data)}');
          });
        });

        return entry.value;
      }
    }

    return null;
  }

  /// Detect package manager and install GameMode
  Future<String?> _detectAndInstallGameMode() async {
    // Check for common package managers
    final packageManagers = {
      'dnf': 'pkexec dnf install -y gamemode',
      'apt': 'pkexec apt install -y gamemode',
      'pacman': 'pkexec pacman -S --noconfirm gamemode',
      'zypper': 'pkexec zypper install -y gamemode',
    };

    for (final entry in packageManagers.entries) {
      final checkResult = await Process.run('which', [entry.key]);
      if (checkResult.exitCode == 0) {
        _logger.d('Found package manager: ${entry.key}');

        // Launch installation in terminal (non-blocking)
        Process.start('sh', ['-c', entry.value]).then((process) {
          process.stdout.listen((data) {
            _logger.d('Install output: ${String.fromCharCodes(data)}');
          });
          process.stderr.listen((data) {
            // Package managers often output normal info to stderr
            _logger.d('Install info: ${String.fromCharCodes(data)}');
          });
        });

        return entry.value;
      }
    }

    return null;
  }

  /// Detect package manager and install vkBasalt
  Future<String?> _detectAndInstallVkBasalt() async {
    // Check for common package managers
    final packageManagers = {
      'dnf': 'pkexec dnf install -y vkBasalt',
      'apt': 'pkexec apt install -y vkbasalt',
      'pacman': 'pkexec pacman -S --noconfirm vkbasalt',
      'zypper': 'pkexec zypper install -y vkbasalt',
    };

    for (final entry in packageManagers.entries) {
      final checkResult = await Process.run('which', [entry.key]);
      if (checkResult.exitCode == 0) {
        _logger.d('Found package manager: ${entry.key}');

        // Launch installation in terminal (non-blocking)
        Process.start('sh', ['-c', entry.value]).then((process) {
          process.stdout.listen((data) {
            _logger.d('Install output: ${String.fromCharCodes(data)}');
          });
          process.stderr.listen((data) {
            // Package managers often output normal info to stderr
            _logger.d('Install info: ${String.fromCharCodes(data)}');
          });
        });

        return entry.value;
      }
    }

    return null;
  }

  /// Detect package manager and install CPU Governor tools
  Future<String?> _detectAndInstallCpuGovernor() async {
    // Check for common package managers
    // Note: Package names vary significantly across distros
    final packageManagers = {
      'dnf': 'pkexec dnf install -y kernel-tools',
      'apt': 'pkexec apt install -y linux-tools-generic',
      'pacman': 'pkexec pacman -S --noconfirm cpupower',
      'zypper': 'pkexec zypper install -y cpupower',
    };

    for (final entry in packageManagers.entries) {
      final checkResult = await Process.run('which', [entry.key]);
      if (checkResult.exitCode == 0) {
        _logger.d('Found package manager: ${entry.key}');

        // Launch installation in terminal (non-blocking)
        Process.start('sh', ['-c', entry.value]).then((process) {
          process.stdout.listen((data) {
            _logger.d('Install output: ${String.fromCharCodes(data)}');
          });
          process.stderr.listen((data) {
            // Package managers often output normal info to stderr
            _logger.d('Install info: ${String.fromCharCodes(data)}');
          });
        });

        return entry.value;
      }
    }

    return null;
  }

  /// Get local MangoHud path
  Future<String> _getMangoHudLocalPath() async {
    final toolsDir = await _getPerformanceToolsDirectory();
    return '${toolsDir.path}/mangohud/bin/mangohud';
  }

  /// Get MangoHud install instructions
  String _getMangoHudInstallInstructions() {
    return 'Install via package manager or click Install button';
  }

  /// Get GameMode install instructions
  String _getGameModeInstallInstructions() {
    return 'Install via package manager or click Install button';
  }

  /// Get vkBasalt install instructions
  String _getVkBasaltInstallInstructions() {
    return 'Install via package manager or click Install button';
  }

  /// Get CPU Governor install instructions
  String _getCpuGovernorInstallInstructions() {
    return 'Install via package manager or click Install button';
  }

  /// Get the directory where performance tools are stored
  /// Uses ~/.local/share/tucheze/performance_tools on Linux
  Future<Directory> _getPerformanceToolsDirectory() async {
    String toolsPath;

    if (Platform.isLinux) {
      // Use XDG standard: ~/.local/share/tucheze/performance_tools
      final home = Platform.environment['HOME'];
      if (home == null) {
        throw Exception('HOME environment variable not set');
      }
      toolsPath = '$home/.local/share/tucheze/performance_tools';
    } else {
      // Fallback for other platforms
      final appDir = await getApplicationDocumentsDirectory();
      toolsPath = '${appDir.path}/tucheze/performance_tools';
    }

    final toolsDir = Directory(toolsPath);

    if (!await toolsDir.exists()) {
      await toolsDir.create(recursive: true);
      _logger.d('Created performance tools directory: ${toolsDir.path}');
    }

    return toolsDir;
  }
}
