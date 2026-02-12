import 'dart:convert';

class GPU {
  final String platformName;
  final String vendor;
  final String name;
  final int globalMemBytes;
  final int maxComputeUnits;
  final String driverVersion;
  final String deviceType;

  // Gaming-specific fields
  final String
  pciAddress; // e.g., "01:00.0" - for Vulkan/game engine GPU selection
  final String?
  renderNode; // e.g., "/dev/dri/renderD128" - for direct rendering
  final bool isActive; // Whether this GPU is currently active/in use
  final bool vulkanSupported; // Vulkan API support
  final String openGLVersion; // OpenGL version (e.g., "4.6")

  GPU({
    required this.platformName,
    required this.vendor,
    required this.name,
    required this.globalMemBytes,
    required this.maxComputeUnits,
    required this.driverVersion,
    required this.deviceType,
    this.pciAddress = '',
    this.renderNode,
    this.isActive = false,
    this.vulkanSupported = false,
    this.openGLVersion = '',
  });

  GPU copyWith({
    String? platformName,
    String? vendor,
    String? name,
    int? globalMemBytes,
    int? maxComputeUnits,
    String? driverVersion,
    String? deviceType,
    String? pciAddress,
    String? renderNode,
    bool? isActive,
    bool? vulkanSupported,
    String? openGLVersion,
  }) {
    return GPU(
      platformName: platformName ?? this.platformName,
      vendor: vendor ?? this.vendor,
      name: name ?? this.name,
      globalMemBytes: globalMemBytes ?? this.globalMemBytes,
      maxComputeUnits: maxComputeUnits ?? this.maxComputeUnits,
      driverVersion: driverVersion ?? this.driverVersion,
      deviceType: deviceType ?? this.deviceType,
      pciAddress: pciAddress ?? this.pciAddress,
      renderNode: renderNode ?? this.renderNode,
      isActive: isActive ?? this.isActive,
      vulkanSupported: vulkanSupported ?? this.vulkanSupported,
      openGLVersion: openGLVersion ?? this.openGLVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'platform_name': platformName,
      'vendor': vendor,
      'name': name,
      'global_mem_bytes': globalMemBytes,
      'max_compute_units': maxComputeUnits,
      'driver_version': driverVersion,
      'device_type': deviceType,
      'pci_address': pciAddress,
      'render_node': renderNode,
      'is_active': isActive,
      'vulkan_supported': vulkanSupported,
      'opengl_version': openGLVersion,
    };
  }

  factory GPU.fromMap(Map<String, dynamic> map) {
    return GPU(
      platformName: map['platform_name'] ?? '',
      vendor: map['vendor'] ?? '',
      name: map['name'] ?? '',
      globalMemBytes: map['global_mem_bytes']?.toInt() ?? 0,
      maxComputeUnits: map['max_compute_units']?.toInt() ?? 0,
      driverVersion: map['driver_version'] ?? '',
      deviceType: map['device_type'] ?? '',
      pciAddress: map['pci_address'] ?? '',
      renderNode: map['render_node'],
      isActive: map['is_active'] ?? false,
      vulkanSupported: map['vulkan_supported'] ?? false,
      openGLVersion: map['opengl_version'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory GPU.fromJson(String source) => GPU.fromMap(json.decode(source));

  @override
  String toString() {
    return 'GPU(platformName: $platformName, vendor: $vendor, name: $name, globalMemBytes: $globalMemBytes, maxComputeUnits: $maxComputeUnits, driverVersion: $driverVersion, deviceType: $deviceType, pciAddress: $pciAddress, renderNode: $renderNode, isActive: $isActive, vulkanSupported: $vulkanSupported, openGLVersion: $openGLVersion)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GPU &&
        other.platformName == platformName &&
        other.vendor == vendor &&
        other.name == name &&
        other.globalMemBytes == globalMemBytes &&
        other.maxComputeUnits == maxComputeUnits &&
        other.driverVersion == driverVersion &&
        other.deviceType == deviceType &&
        other.pciAddress == pciAddress &&
        other.renderNode == renderNode &&
        other.isActive == isActive &&
        other.vulkanSupported == vulkanSupported &&
        other.openGLVersion == openGLVersion;
  }

  @override
  int get hashCode {
    return platformName.hashCode ^
        vendor.hashCode ^
        name.hashCode ^
        globalMemBytes.hashCode ^
        maxComputeUnits.hashCode ^
        driverVersion.hashCode ^
        deviceType.hashCode ^
        pciAddress.hashCode ^
        renderNode.hashCode ^
        isActive.hashCode ^
        vulkanSupported.hashCode ^
        openGLVersion.hashCode;
  }

  /// Helper method to format memory size in human-readable format
  String get memoryFormatted {
    if (globalMemBytes == 0) return 'Unknown';
    if (globalMemBytes < 1024 * 1024) {
      return '${(globalMemBytes / (1024)).toStringAsFixed(0)} KB';
    } else if (globalMemBytes < 1024 * 1024 * 1024) {
      return '${(globalMemBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    } else {
      return '${(globalMemBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Check if this GPU is suitable for gaming
  bool get isGamingSuitable {
    // Has dedicated VRAM (> 2GB) or is a discrete GPU
    final hasEnoughMemory = globalMemBytes >= 2 * 1024 * 1024 * 1024;
    final isDiscrete = !deviceType.toLowerCase().contains('integrated');
    return (hasEnoughMemory && isDiscrete) || vulkanSupported;
  }
}
