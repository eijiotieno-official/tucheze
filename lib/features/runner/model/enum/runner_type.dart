/// Enum representing different types of Wine/Proton runners available for running Windows games on Linux
enum RunnerType {
  /// Proton-GE (GloriousEggroll's Proton build) - optimized for Steam games
  protonGE('proton-ge', 'Proton-GE'),

  /// Wine-GE (GloriousEggroll's Wine build) - Wine with gaming patches
  wineGE('wine-ge', 'Wine-GE'),

  /// Lutris Wine - Lutris-maintained Wine builds
  lutrisWine('lutris-wine', 'Lutris Wine');

  const RunnerType(this.id, this.displayName);

  /// Unique identifier used for storage and API calls
  final String id;

  /// Human-readable display name
  final String displayName;

  /// Convert enum to JSON string
  String toJson() => id;

  /// Parse string to enum
  static RunnerType fromJson(String json) {
    return RunnerType.values.firstWhere(
      (type) => type.id == json,
      orElse: () => RunnerType.wineGE,
    );
  }

  /// Get runner type from string (case-insensitive)
  static RunnerType fromString(String value) {
    final lowercase = value.toLowerCase();
    return RunnerType.values.firstWhere(
      (type) => type.id == lowercase,
      orElse: () => RunnerType.wineGE,
    );
  }

  @override
  String toString() => id;
}
