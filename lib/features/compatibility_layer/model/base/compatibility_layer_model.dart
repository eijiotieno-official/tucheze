import 'dart:convert';

import '../enum/compatibility_layer_type.dart';

class CompatibilityLayer {
  final String name;
  final String version;
  final CompatibilityLayerType type;
  final String downloadUrl;
  final int sizeBytes;
  final String description;
  final DateTime releaseDate;
  final bool isDownloaded;
  final String? localPath; // Path where compatibility layer is stored locally

  CompatibilityLayer({
    required this.name,
    required this.version,
    required this.type,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.description,
    required this.releaseDate,
    this.isDownloaded = false,
    this.localPath,
  });

  CompatibilityLayer copyWith({
    String? name,
    String? version,
    CompatibilityLayerType? type,
    String? downloadUrl,
    int? sizeBytes,
    String? description,
    DateTime? releaseDate,
    bool? isDownloaded,
    String? localPath,
  }) {
    return CompatibilityLayer(
      name: name ?? this.name,
      version: version ?? this.version,
      type: type ?? this.type,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      description: description ?? this.description,
      releaseDate: releaseDate ?? this.releaseDate,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'version': version,
      'type': type.toJson(),
      'download_url': downloadUrl,
      'size_bytes': sizeBytes,
      'description': description,
      'release_date': releaseDate.toIso8601String(),
      'is_downloaded': isDownloaded,
      'local_path': localPath,
    };
  }

  factory CompatibilityLayer.fromMap(Map<String, dynamic> map) {
    return CompatibilityLayer(
      name: map['name'] ?? '',
      version: map['version'] ?? '',
      type: CompatibilityLayerType.fromJson(map['type'] ?? ''),
      downloadUrl: map['download_url'] ?? '',
      sizeBytes: map['size_bytes']?.toInt() ?? 0,
      description: map['description'] ?? '',
      releaseDate: map['release_date'] != null
          ? DateTime.parse(map['release_date'])
          : DateTime.now(),
      isDownloaded: map['is_downloaded'] ?? false,
      localPath: map['local_path'],
    );
  }

  String toJson() => json.encode(toMap());

  factory CompatibilityLayer.fromJson(String source) =>
      CompatibilityLayer.fromMap(json.decode(source));

  /// Get human-readable size
  String get sizeFormatted {
    if (sizeBytes == 0) return 'Unknown size';

    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = sizeBytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  @override
  String toString() {
    return 'CompatibilityLayer(name: $name, version: $version, type: ${type.displayName}, isDownloaded: $isDownloaded)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CompatibilityLayer &&
        other.name == name &&
        other.version == version &&
        other.type == type;
  }

  @override
  int get hashCode => name.hashCode ^ version.hashCode ^ type.hashCode;
}
