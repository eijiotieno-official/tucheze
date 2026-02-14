/// Enum representing different types of performance tools for gaming
enum PerformanceToolType {
  /// MangoHud - Performance overlay showing FPS, CPU, GPU, temps
  mangoHud('mangohud', 'MangoHud'),

  /// GameMode - CPU governor optimization from Feral Interactive
  gameMode('gamemode', 'GameMode'),

  /// vkBasalt - Post-processing layer for Vulkan (ReShade-like effects)
  vkBasalt('vkbasalt', 'vkBasalt'),

  /// CPU Governor - Control CPU performance/power mode
  cpuGovernor('cpugovernor', 'CPU Governor');

  const PerformanceToolType(this.id, this.displayName);

  /// Unique identifier used for storage and preferences
  final String id;

  /// Human-readable display name
  final String displayName;

  /// Convert enum to JSON string
  String toJson() => id;

  /// Parse string to enum
  static PerformanceToolType fromJson(String json) {
    return PerformanceToolType.values.firstWhere(
      (type) => type.id == json,
      orElse: () => PerformanceToolType.mangoHud,
    );
  }

  /// Get tool type from string (case-insensitive)
  static PerformanceToolType fromString(String value) {
    final lowercase = value.toLowerCase();
    return PerformanceToolType.values.firstWhere(
      (type) => type.id == lowercase,
      orElse: () => PerformanceToolType.mangoHud,
    );
  }

  @override
  String toString() => id;
}
