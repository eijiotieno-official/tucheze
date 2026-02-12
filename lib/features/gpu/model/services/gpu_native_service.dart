// gpu_native_service.dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:logger/logger.dart';

import '../base/gpu_model.dart';

class _OpenCLBindings {
  final DynamicLibrary lib;

  // Function typedefs
  late final int Function(int, Pointer<Pointer<Void>>?, Pointer<Uint32>?)
  clGetPlatformIDs;
  late final int Function(
    Pointer<Void>,
    int,
    int,
    Pointer<Pointer<Void>>?,
    Pointer<Uint32>?,
  )
  clGetDeviceIDs;
  late final int Function(
    Pointer<Void>,
    int,
    int,
    Pointer<Void>?,
    Pointer<Uint64>?,
  )
  clGetDeviceInfo;
  late final int Function(
    Pointer<Void>,
    int,
    int,
    Pointer<Void>?,
    Pointer<Uint64>?,
  )
  clGetPlatformInfo;

  _OpenCLBindings._(this.lib) {
    clGetPlatformIDs = lib
        .lookup<
          NativeFunction<
            Int32 Function(Uint32, Pointer<Pointer<Void>>?, Pointer<Uint32>?)
          >
        >('clGetPlatformIDs')
        .asFunction();
    clGetDeviceIDs = lib
        .lookup<
          NativeFunction<
            Int32 Function(
              Pointer<Void>,
              Uint64,
              Uint32,
              Pointer<Pointer<Void>>?,
              Pointer<Uint32>?,
            )
          >
        >('clGetDeviceIDs')
        .asFunction();
    clGetDeviceInfo = lib
        .lookup<
          NativeFunction<
            Int32 Function(
              Pointer<Void>,
              Uint32,
              Uint64,
              Pointer<Void>?,
              Pointer<Uint64>?,
            )
          >
        >('clGetDeviceInfo')
        .asFunction();
    clGetPlatformInfo = lib
        .lookup<
          NativeFunction<
            Int32 Function(
              Pointer<Void>,
              Uint32,
              Uint64,
              Pointer<Void>?,
              Pointer<Uint64>?,
            )
          >
        >('clGetPlatformInfo')
        .asFunction();
  }

  static _OpenCLBindings? tryLoad() {
    final names = ['libOpenCL.so', 'libOpenCL.so.1', 'libOpenCL.so.2'];
    for (final n in names) {
      try {
        final lib = DynamicLibrary.open(n);
        return _OpenCLBindings._(lib);
      } catch (_) {
        // try next
      }
    }
    return null;
  }
}

// OpenCL constants used (from cl.h)
const CL_SUCCESS = 0;
const CL_DEVICE_TYPE_GPU = 1 << 2; // 4
const CL_DEVICE_TYPE_CPU = 1 << 1; // 2
const CL_DEVICE_TYPE_ACCELERATOR = 1 << 3;
const CL_DEVICE_TYPE_ALL = 0xFFFFFFFF;

const CL_DEVICE_NAME = 0x102B;
const CL_DEVICE_VENDOR = 0x102C;
const CL_DEVICE_GLOBAL_MEM_SIZE = 0x101F;
const CL_DEVICE_MAX_COMPUTE_UNITS = 0x1002;
const CL_DRIVER_VERSION = 0x102D;
const CL_DEVICE_TYPE = 0x1000;

const CL_PLATFORM_NAME = 0x0902;
const CL_PLATFORM_VENDOR = 0x0903;

/// Native service class that handles the underlying OpenCL FFI code
/// for GPU enumeration and detection.
class GpuNativeService {
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

  /// Primary method: returns a list of GPUs and their details.
  ///
  /// Uses OpenCL via FFI to query all device types (GPUs, integrated graphics, etc.).
  /// If OpenCL is not available / returns no devices, it falls back to:
  /// 1. DRM subsystem (/sys/class/drm/) - Lutris approach, most reliable for all GPUs
  /// 2. nvidia-smi for NVIDIA-specific details
  /// 3. lspci for basic PCI device information
  Future<List<GPU>> listGpus() async {
    _logger.d(
      'Starting device enumeration using OpenCL (querying all device types)...',
    );
    final bindings = _OpenCLBindings.tryLoad();

    if (bindings == null) {
      _logger.w(
        'OpenCL library not available, falling back to command-line tools',
      );
      // OpenCL library not available: fallback to command-line
      return await _fallbackListGpus();
    }

    _logger.d('OpenCL bindings loaded successfully');
    final results = <GPU>[];

    // 1) get platform count
    final platformCountPtr = calloc<Uint32>();
    try {
      final r1 = bindings.clGetPlatformIDs(0, nullptr, platformCountPtr);
      if (r1 != CL_SUCCESS) {
        _logger.w(
          'Failed to get platform count (error code: $r1), using fallback',
        );
        // fallback
        return await _fallbackListGpus();
      }
      final platformCount = platformCountPtr.value;
      _logger.d('Found $platformCount OpenCL platform(s)');
      if (platformCount == 0) {
        _logger.w('No OpenCL platforms found, using fallback');
        return await _fallbackListGpus();
      }

      // allocate array for platform ids
      final platforms = calloc<Pointer<Void>>(platformCount);
      try {
        final r2 = bindings.clGetPlatformIDs(platformCount, platforms, nullptr);
        if (r2 != CL_SUCCESS) {
          _logger.w('Failed to get platform IDs, using fallback');
          return await _fallbackListGpus();
        }

        // iterate platforms
        for (var p = 0; p < platformCount; p++) {
          final platform = platforms[p];

          // get platform name
          final platformName =
              _getPlatformString(bindings, platform, CL_PLATFORM_NAME) ??
              'Unknown Platform';
          _logger.d('Processing platform: $platformName');
          // get device count for all devices on this platform (GPUs, CPUs, accelerators)
          final deviceCountPtr = calloc<Uint32>();
          try {
            final r3 = bindings.clGetDeviceIDs(
              platform,
              CL_DEVICE_TYPE_ALL,
              0,
              nullptr,
              deviceCountPtr,
            );
            // deviceCountPtr undefined if CL_DEVICE_NOT_FOUND - handle gracefully
            if (r3 != CL_SUCCESS) {
              // no devices on this platform, continue
              continue;
            }
            final deviceCount = deviceCountPtr.value;
            _logger.d(
              'Found $deviceCount device(s) on platform: $platformName',
            );
            if (deviceCount == 0) continue;

            final devices = calloc<Pointer<Void>>(deviceCount);
            try {
              final r4 = bindings.clGetDeviceIDs(
                platform,
                CL_DEVICE_TYPE_ALL,
                deviceCount,
                devices,
                nullptr,
              );
              if (r4 != CL_SUCCESS) continue;

              for (var d = 0; d < deviceCount; d++) {
                final dev = devices[d];

                final name =
                    _getDeviceString(bindings, dev, CL_DEVICE_NAME) ??
                    'Unknown Device';
                final vendor =
                    _getDeviceString(bindings, dev, CL_DEVICE_VENDOR) ??
                    'Unknown Vendor';
                final driver =
                    _getDeviceString(bindings, dev, CL_DRIVER_VERSION) ?? '';

                final globalMem =
                    _getDeviceUint64(
                      bindings,
                      dev,
                      CL_DEVICE_GLOBAL_MEM_SIZE,
                    ) ??
                    0;
                final computeUnits =
                    _getDeviceUint32(
                      bindings,
                      dev,
                      CL_DEVICE_MAX_COMPUTE_UNITS,
                    ) ??
                    0;
                final dtype =
                    _getDeviceUint64(bindings, dev, CL_DEVICE_TYPE) ?? 0;

                final deviceTypeStr = _deviceTypeToString(dtype);

                _logger.d(
                  'Detected device: $name by $vendor (Type: $deviceTypeStr)',
                );

                results.add(
                  GPU(
                    platformName: platformName,
                    vendor: vendor,
                    name: name,
                    globalMemBytes: globalMem,
                    maxComputeUnits: computeUnits,
                    driverVersion: driver,
                    deviceType: deviceTypeStr,
                    // OpenCL doesn't provide these, will be supplemented by DRM
                    pciAddress: '',
                    renderNode: null,
                    isActive: false,
                    vulkanSupported: false,
                    openGLVersion: '',
                  ),
                );
              }
            } finally {
              calloc.free(devices);
            }
          } finally {
            calloc.free(deviceCountPtr);
          }
        }
      } finally {
        calloc.free(platforms);
      }
    } finally {
      calloc.free(platformCountPtr);
    }

    _logger.i('OpenCL found ${results.length} device(s)');

    // Always supplement with DRM detection to catch any GPUs OpenCL might have missed
    // (e.g., Intel integrated graphics that may not be exposed via OpenCL)
    _logger.d('Supplementing OpenCL results with DRM detection...');
    try {
      final drmGpus = await _detectGpusViaDRM();
      if (drmGpus.isNotEmpty) {
        _logger.d('DRM found ${drmGpus.length} device(s)');

        // Merge and deduplicate results intelligently
        for (final drmGpu in drmGpus) {
          if (!_isDuplicateGpu(drmGpu, results)) {
            _logger.i(
              'Adding GPU from DRM that was not in OpenCL: ${drmGpu.name}',
            );
            results.add(drmGpu);
          } else {
            _logger.d('Skipping duplicate GPU from DRM: ${drmGpu.name}');
          }
        }

        // Enhance NVIDIA GPUs with nvidia-smi details
        await _enhanceNvidiaGpusWithSmi(results);
      }
    } catch (e) {
      _logger.d('DRM supplemental detection failed: $e');
    }

    if (results.isEmpty) {
      _logger.w('No devices discovered, using complete fallback');
      return await _fallbackListGpus();
    }

    _logger.i('Total devices enumerated: ${results.length}');
    return results;
  }

  /* -------------------------
     Helper FFI helpers
     ------------------------- */

  String? _getPlatformString(
    _OpenCLBindings b,
    Pointer<Void> platform,
    int param,
  ) {
    final sizePtr = calloc<Uint64>();
    try {
      final err = b.clGetPlatformInfo(platform, param, 0, nullptr, sizePtr);
      if (err != CL_SUCCESS) return null;
      final size = sizePtr.value;
      if (size == 0) return null;
      final buf = calloc<Uint8>(size);
      try {
        final err2 = b.clGetPlatformInfo(
          platform,
          param,
          size,
          buf.cast<Void>(),
          nullptr,
        );
        if (err2 != CL_SUCCESS) return null;
        return buf.cast<Utf8>().toDartString();
      } finally {
        calloc.free(buf);
      }
    } finally {
      calloc.free(sizePtr);
    }
  }

  String? _getDeviceString(_OpenCLBindings b, Pointer<Void> device, int param) {
    final sizePtr = calloc<Uint64>();
    try {
      final err = b.clGetDeviceInfo(device, param, 0, nullptr, sizePtr);
      if (err != CL_SUCCESS) return null;
      final size = sizePtr.value;
      if (size == 0) return null;
      final buf = calloc<Uint8>(size);
      try {
        final err2 = b.clGetDeviceInfo(
          device,
          param,
          size,
          buf.cast<Void>(),
          nullptr,
        );
        if (err2 != CL_SUCCESS) return null;
        return buf.cast<Utf8>().toDartString();
      } finally {
        calloc.free(buf);
      }
    } finally {
      calloc.free(sizePtr);
    }
  }

  int? _getDeviceUint32(_OpenCLBindings b, Pointer<Void> device, int param) {
    final out = calloc<Uint32>();
    try {
      final err = b.clGetDeviceInfo(
        device,
        param,
        sizeOf<Uint32>(),
        out.cast<Void>(),
        nullptr,
      );
      if (err != CL_SUCCESS) return null;
      return out.value;
    } finally {
      calloc.free(out);
    }
  }

  int? _getDeviceUint64(_OpenCLBindings b, Pointer<Void> device, int param) {
    final out = calloc<Uint64>();
    try {
      final err = b.clGetDeviceInfo(
        device,
        param,
        sizeOf<Uint64>(),
        out.cast<Void>(),
        nullptr,
      );
      if (err != CL_SUCCESS) return null;
      // dart int can hold 64-bit on 64-bit runtime
      return out.value.toInt();
    } finally {
      calloc.free(out);
    }
  }

  String _deviceTypeToString(int dtype) {
    final parts = <String>[];
    if ((dtype & CL_DEVICE_TYPE_GPU) != 0) parts.add('GPU');
    if ((dtype & CL_DEVICE_TYPE_CPU) != 0) parts.add('CPU');
    if ((dtype & CL_DEVICE_TYPE_ACCELERATOR) != 0) parts.add('ACCELERATOR');
    if (parts.isEmpty) return 'UNKNOWN';
    return parts.join('|');
  }

  /* -------------------------
     Fallback: simple shell helpers
     ------------------------- */

  Future<List<GPU>> _fallbackListGpus() async {
    _logger.d('Using fallback methods to detect GPUs');
    final results = <GPU>[];

    // Try DRM subsystem first (Lutris approach - most reliable for all GPUs)
    _logger.d('Attempting to use DRM subsystem (/sys/class/drm/)...');
    try {
      final drmGpus = await _detectGpusViaDRM();
      if (drmGpus.isNotEmpty) {
        results.addAll(drmGpus);
        _logger.i('Found ${drmGpus.length} GPU(s) via DRM subsystem');

        // Enhance NVIDIA GPUs with nvidia-smi details if available
        await _enhanceNvidiaGpusWithSmi(results);

        return results;
      }
    } catch (e) {
      _logger.d('DRM subsystem detection failed: $e');
    }

    // Try nvidia-smi (NVIDIA-specific)
    _logger.d('Attempting to use nvidia-smi...');
    try {
      final smi = await Process.run('nvidia-smi', [
        '--query-gpu=index,name,driver_version,memory.total',
        '--format=csv,noheader,nounits',
      ]);
      if (smi.exitCode == 0) {
        _logger.d('nvidia-smi executed successfully');
        final lines = (smi.stdout as String).trim().split('\n');
        for (final ln in lines) {
          final cols = ln.split(',').map((s) => s.trim()).toList();
          if (cols.length >= 4) {
            results.add(
              GPU(
                platformName: 'NVIDIA (nvidia-smi)',
                vendor: 'NVIDIA Corporation',
                name: cols[1],
                globalMemBytes: int.tryParse(cols[3]) != null
                    ? int.parse(cols[3]) * 1024 * 1024
                    : 0,
                maxComputeUnits: 0,
                driverVersion: cols[2],
                deviceType: 'GPU (NVIDIA)',
                pciAddress: '',
                renderNode: null,
                isActive: false,
                vulkanSupported: true, // NVIDIA typically supports Vulkan
                openGLVersion: '',
              ),
            );
          }
        }
        if (results.isNotEmpty) {
          _logger.i('Found ${results.length} GPU(s) via nvidia-smi');
          return results;
        }
      }
    } catch (e) {
      _logger.d('nvidia-smi not available or failed: $e');
      // ignore
    }

    // Next: use lspci and parse lines for VGA / 3D controller
    _logger.d('Attempting to use lspci...');
    try {
      final lsp = await Process.run('lspci', ['-vmm']);
      if (lsp.exitCode == 0) {
        _logger.d('lspci executed successfully');
        // simple parse: blocks separated by blank lines, look for "Class: VGA compatible controller" or "3D controller"
        final raw = (lsp.stdout as String).split('\n\n');
        for (final block in raw) {
          if (block.toLowerCase().contains('vga compatible controller') ||
              block.toLowerCase().contains('3d controller')) {
            final vendorLine = block
                .split('\n')
                .firstWhere(
                  (l) => l.startsWith('Vendor:'),
                  orElse: () => 'Vendor: Unknown',
                );
            final deviceLine = block
                .split('\n')
                .firstWhere(
                  (l) => l.startsWith('Device:'),
                  orElse: () => 'Device: Unknown',
                );
            final vendor = vendorLine.split(':').length > 1
                ? vendorLine.split(':')[1].trim()
                : 'Unknown';
            final name = deviceLine.split(':').length > 1
                ? deviceLine.split(':')[1].trim()
                : 'Unknown';
            results.add(
              GPU(
                platformName: 'PCI',
                vendor: vendor,
                name: name,
                globalMemBytes: 0,
                maxComputeUnits: 0,
                driverVersion: '',
                deviceType: 'GPU (PCI)',
                pciAddress: '',
                renderNode: null,
                isActive: false,
                vulkanSupported: false,
                openGLVersion: '',
              ),
            );
          }
        }
        if (results.isNotEmpty) {
          _logger.i('Found ${results.length} GPU(s) via lspci');
          return results;
        }
      }
    } catch (e) {
      _logger.d('lspci not available or failed: $e');
      // ignore
    }

    _logger.w('No GPUs found using any detection method');
    // If nothing found, return empty list
    return results;
  }

  /// Check if a GPU is a duplicate of one already in the list
  /// Uses vendor matching and fuzzy name matching to detect duplicates
  bool _isDuplicateGpu(GPU candidate, List<GPU> existingGpus) {
    final candidateVendor = candidate.vendor.toLowerCase();
    final candidateName = candidate.name.toLowerCase();

    // Extract key model identifiers from the candidate name
    // e.g., "1660 ti", "uhd", "radeon", etc.
    final candidateTokens = _extractGpuTokens(candidateName);

    for (final existing in existingGpus) {
      final existingVendor = existing.vendor.toLowerCase();
      final existingName = existing.name.toLowerCase();

      // Must be from the same vendor
      if (!_isSameVendor(candidateVendor, existingVendor)) {
        continue;
      }

      // Extract key model identifiers from existing GPU name
      final existingTokens = _extractGpuTokens(existingName);

      // Check if they share key identifiers
      final sharedTokens = candidateTokens.intersection(existingTokens);

      // If they share 2+ significant tokens and same vendor, likely duplicate
      if (sharedTokens.length >= 2) {
        _logger.d(
          'Detected duplicate: "$candidateName" matches "$existingName" '
          '(shared tokens: ${sharedTokens.join(", ")})',
        );
        return true;
      }

      // Special case: exact substring match for unique model numbers
      if (candidateName.contains('1660') && existingName.contains('1660')) {
        return true;
      }
      if (candidateName.contains('3060') && existingName.contains('3060')) {
        return true;
      }
      if (candidateName.contains('4090') && existingName.contains('4090')) {
        return true;
      }
    }

    return false;
  }

  /// Extract significant tokens from GPU name for matching
  Set<String> _extractGpuTokens(String name) {
    final tokens = <String>{};
    final normalized = name.toLowerCase();

    // Extract model numbers (like 1660, 3060, etc.)
    final modelNumbers = RegExp(r'\b\d{3,4}\b').allMatches(normalized);
    for (final match in modelNumbers) {
      tokens.add(match.group(0)!);
    }

    // Extract key identifiers
    if (normalized.contains('ti')) tokens.add('ti');
    if (normalized.contains('super')) tokens.add('super');
    if (normalized.contains('max-q')) tokens.add('max-q');
    if (normalized.contains('mobile')) tokens.add('mobile');

    // GPU series/family
    if (normalized.contains('geforce')) tokens.add('geforce');
    if (normalized.contains('quadro')) tokens.add('quadro');
    if (normalized.contains('rtx')) tokens.add('rtx');
    if (normalized.contains('gtx')) tokens.add('gtx');
    if (normalized.contains('radeon')) tokens.add('radeon');
    if (normalized.contains('uhd')) tokens.add('uhd');
    if (normalized.contains('iris')) tokens.add('iris');
    if (normalized.contains('arc')) tokens.add('arc');

    return tokens;
  }

  /// Check if two vendor strings refer to the same vendor
  bool _isSameVendor(String vendor1, String vendor2) {
    // Normalize vendor names
    if (vendor1.contains('nvidia') && vendor2.contains('nvidia')) return true;
    if (vendor1.contains('intel') && vendor2.contains('intel')) return true;
    if (vendor1.contains('amd') && vendor2.contains('amd')) return true;
    if (vendor1.contains('advanced micro devices') && vendor2.contains('amd')) {
      return true;
    }
    if (vendor1.contains('amd') && vendor2.contains('advanced micro devices')) {
      return true;
    }

    return vendor1 == vendor2;
  }

  /// Detect GPUs using DRM subsystem (Lutris approach)
  /// This method reads from /sys/class/drm/ which exposes all graphics devices
  Future<List<GPU>> _detectGpusViaDRM() async {
    final results = <GPU>[];
    final drmPath = '/sys/class/drm';

    final drmDir = Directory(drmPath);
    if (!await drmDir.exists()) {
      _logger.d('DRM directory does not exist');
      return results;
    }

    // Map to track unique GPUs by their device path
    final Map<String, GPU> uniqueGpus = {};

    // List the DRM directory entries with followLinks to resolve symlinks
    await for (final entity in drmDir.list(followLinks: true)) {
      final entityPath = entity.path;
      final cardName = entityPath.split('/').last;

      // Look for card entries (card0, card1, etc.)
      if (cardName.startsWith('card') &&
          RegExp(r'^card\d+$').hasMatch(cardName)) {
        _logger.d('Processing DRM card: $cardName');
        try {
          _logger.d('Checking device path: $drmPath/$cardName/device');

          // Read vendor and device IDs using the symlink path directly
          final vendorFile = File('$drmPath/$cardName/device/vendor');
          final deviceFile = File('$drmPath/$cardName/device/device');

          final vendorExists = await vendorFile.exists();
          final deviceExists = await deviceFile.exists();

          _logger.d(
            'Vendor file exists: $vendorExists, Device file exists: $deviceExists',
          );

          if (!vendorExists || !deviceExists) {
            _logger.d('Skipping $cardName: missing vendor/device files');
            continue;
          }

          final vendorId = (await vendorFile.readAsString()).trim();
          final deviceId = (await deviceFile.readAsString()).trim();

          // Get GPU name and vendor name using lspci
          String gpuName = 'Unknown GPU';
          String vendorName = 'Unknown Vendor';
          String driverVersion = '';
          String pciAddress = '';
          int memoryBytes = 0;

          // Try to get detailed info via lspci
          try {
            final lspciResult = await Process.run('lspci', [
              '-d',
              '${vendorId.replaceFirst('0x', '')}:${deviceId.replaceFirst('0x', '')}',
              '-vmm',
            ]);

            if (lspciResult.exitCode == 0) {
              final output = lspciResult.stdout as String;
              final lines = output.split('\n');

              for (final line in lines) {
                if (line.startsWith('Vendor:')) {
                  vendorName = line.split(':')[1].trim();
                } else if (line.startsWith('Device:')) {
                  gpuName = line.split(':')[1].trim();
                } else if (line.startsWith('Slot:')) {
                  pciAddress = line.split(':').skip(1).join(':').trim();
                }
              }
            }
          } catch (e) {
            _logger.d('Could not get detailed info for $cardName: $e');
          }

          // Determine GPU type based on vendor ID
          String deviceType = 'GPU';
          if (vendorId.toLowerCase().contains('8086')) {
            deviceType = 'GPU (Intel Integrated)';
            if (vendorName == 'Unknown Vendor')
              vendorName = 'Intel Corporation';
          } else if (vendorId.toLowerCase().contains('10de')) {
            deviceType = 'GPU (NVIDIA)';
            if (vendorName == 'Unknown Vendor')
              vendorName = 'NVIDIA Corporation';
          } else if (vendorId.toLowerCase().contains('1002')) {
            deviceType = 'GPU (AMD)';
            if (vendorName == 'Unknown Vendor')
              vendorName = 'Advanced Micro Devices';
          }

          // Try to read memory info if available
          final sysDevicePath = '$drmPath/$cardName/device';
          try {
            final memFile = File('$sysDevicePath/mem_info_vram_total');
            if (await memFile.exists()) {
              memoryBytes =
                  int.tryParse((await memFile.readAsString()).trim()) ?? 0;
            }
          } catch (_) {
            // Memory info might not be available for all GPUs
          }

          // Get render node (for direct rendering)
          String? renderNode;
          try {
            // Look for renderD128, renderD129, etc. associated with this card
            final cardNumber = cardName.replaceFirst('card', '');
            final renderNodePath =
                '/dev/dri/renderD${128 + int.parse(cardNumber)}';
            if (await File(renderNodePath).exists()) {
              renderNode = renderNodePath;
            }
          } catch (_) {
            // Render node detection failed
          }

          // Check if this is the active/primary GPU
          bool isActive = false;
          try {
            final bootVgaFile = File('$sysDevicePath/boot_vga');
            if (await bootVgaFile.exists()) {
              final bootVga = (await bootVgaFile.readAsString()).trim();
              isActive = bootVga == '1';
            }
          } catch (_) {
            // Assume card0 is active if we can't determine
            isActive = cardName == 'card0';
          }

          // Check Vulkan support by running vulkaninfo and checking for this device ID
          bool vulkanSupported = false;
          try {
            final vulkanResult = await Process.run('vulkaninfo', [
              '--summary',
            ], runInShell: true);
            if (vulkanResult.exitCode == 0) {
              final output = vulkanResult.stdout.toString().toLowerCase();
              // Check if this GPU's device ID appears in vulkaninfo output
              final deviceIdEntry = deviceId.toLowerCase().replaceAll('0x', '');
              if (output.contains(deviceIdEntry)) {
                vulkanSupported = true;
              }
            }
          } catch (_) {
            // vulkaninfo not available, assume no Vulkan support
          }

          // Get OpenGL version (from glxinfo if available)
          String openGLVersion = '';
          try {
            final glxResult = await Process.run('glxinfo', ['-B']);
            if (glxResult.exitCode == 0) {
              final output = glxResult.stdout as String;
              final versionMatch = RegExp(
                r'OpenGL version string: (.+)',
              ).firstMatch(output);
              if (versionMatch != null) {
                openGLVersion = versionMatch.group(1)!.trim();
              }
            }
          } catch (_) {
            // glxinfo not available
          }

          // Use card name as unique key to avoid duplicates
          final uniqueKey = cardName;

          if (!uniqueGpus.containsKey(uniqueKey)) {
            uniqueGpus[uniqueKey] = GPU(
              platformName: 'DRM (Direct Rendering Manager)',
              vendor: vendorName,
              name: gpuName,
              globalMemBytes: memoryBytes,
              maxComputeUnits: 0,
              driverVersion: driverVersion,
              deviceType: deviceType,
              pciAddress: pciAddress,
              renderNode: renderNode,
              isActive: isActive,
              vulkanSupported: vulkanSupported,
              openGLVersion: openGLVersion,
            );

            _logger.d('Detected via DRM: $gpuName ($vendorName) - $deviceType');
          }
        } catch (e) {
          _logger.d('Error processing DRM card $cardName: $e');
        }
      }
    }

    results.addAll(uniqueGpus.values);
    return results;
  }

  /// Enhance NVIDIA GPU entries with detailed info from nvidia-smi
  Future<void> _enhanceNvidiaGpusWithSmi(List<GPU> gpus) async {
    try {
      final smi = await Process.run('nvidia-smi', [
        '--query-gpu=name,driver_version,memory.total',
        '--format=csv,noheader,nounits',
      ]);

      if (smi.exitCode == 0) {
        _logger.d('Enhancing NVIDIA GPU info with nvidia-smi data');
        final lines = (smi.stdout as String).trim().split('\n');

        for (var i = 0; i < gpus.length; i++) {
          final gpu = gpus[i];
          // Check if this is an NVIDIA GPU
          if (gpu.vendor.toLowerCase().contains('nvidia') ||
              gpu.deviceType.toLowerCase().contains('nvidia')) {
            if (i < lines.length) {
              final cols = lines[i].split(',').map((s) => s.trim()).toList();
              if (cols.length >= 3) {
                // Update with nvidia-smi data
                gpus[i] = gpu.copyWith(
                  name: cols[0],
                  driverVersion: cols[1],
                  globalMemBytes: int.tryParse(cols[2]) != null
                      ? int.parse(cols[2]) * 1024 * 1024
                      : gpu.globalMemBytes,
                );
                _logger.d('Enhanced NVIDIA GPU info: ${cols[0]}');
              }
            }
          }
        }
      }
    } catch (e) {
      _logger.d('Could not enhance NVIDIA info with nvidia-smi: $e');
    }
  }
}
