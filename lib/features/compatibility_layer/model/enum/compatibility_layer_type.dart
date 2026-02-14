/// Enum representing different types of compatibility layers for translating DirectX to Vulkan
enum CompatibilityLayerType {
  /// DXVK - Vulkan-based translation layer for Direct3D 9/10/11
  dxvk('dxvk', 'DXVK'),

  /// VKD3D-Proton - Direct3D 12 to Vulkan translation layer
  vkd3dProton('vkd3d-proton', 'VKD3D-Proton');

  const CompatibilityLayerType(this.id, this.displayName);

  /// Unique identifier used for storage and API calls
  final String id;

  /// Human-readable display name
  final String displayName;

  /// Convert enum to JSON string
  String toJson() => id;

  /// Parse string to enum
  static CompatibilityLayerType fromJson(String json) {
    return CompatibilityLayerType.values.firstWhere(
      (type) => type.id == json,
      orElse: () => CompatibilityLayerType.dxvk,
    );
  }

  /// Get compatibility layer type from string (case-insensitive)
  static CompatibilityLayerType fromString(String value) {
    final lowercase = value.toLowerCase();
    return CompatibilityLayerType.values.firstWhere(
      (type) => type.id == lowercase,
      orElse: () => CompatibilityLayerType.dxvk,
    );
  }

  @override
  String toString() => id;
}
