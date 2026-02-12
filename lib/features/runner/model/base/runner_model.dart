import 'dart:convert';

import '../enum/runner_type.dart';

class Runner {
  final String name;
  final String version;
  final RunnerType type;
  final String downloadUrl;
  final int sizeBytes;
  final String description;
  final DateTime releaseDate;
  final bool isDownloaded;
  final String? localPath; // Path where runner is stored locally

  Runner({
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

  Runner copyWith({
    String? name,
    String? version,
    RunnerType? type,
    String? downloadUrl,
    int? sizeBytes,
    String? description,
    DateTime? releaseDate,
    bool? isDownloaded,
    String? localPath,
  }) {
    return Runner(
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

  factory Runner.fromMap(Map<String, dynamic> map) {
    return Runner(
      name: map['name'] ?? '',
      version: map['version'] ?? '',
      type: RunnerType.fromJson(map['type'] ?? ''),
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

  factory Runner.fromJson(String source) => Runner.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Runner(name: $name, version: $version, type: $type, downloadUrl: $downloadUrl, sizeBytes: $sizeBytes, description: $description, releaseDate: $releaseDate, isDownloaded: $isDownloaded, localPath: $localPath)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Runner &&
        other.name == name &&
        other.version == version &&
        other.type == type &&
        other.downloadUrl == downloadUrl &&
        other.sizeBytes == sizeBytes &&
        other.description == description &&
        other.releaseDate == releaseDate &&
        other.isDownloaded == isDownloaded &&
        other.localPath == localPath;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        version.hashCode ^
        type.hashCode ^
        downloadUrl.hashCode ^
        sizeBytes.hashCode ^
        description.hashCode ^
        releaseDate.hashCode ^
        isDownloaded.hashCode ^
        localPath.hashCode;
  }

  /// Helper method to format size in human-readable format
  String get sizeFormatted {
    if (sizeBytes == 0) return 'Unknown';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    } else if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    } else {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Check if this runner can be used (is downloaded and has valid path)
  bool get isUsable {
    return isDownloaded && localPath != null && localPath!.isNotEmpty;
  }
}
