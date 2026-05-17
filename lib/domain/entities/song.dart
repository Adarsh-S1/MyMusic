/// Immutable Song entity — the core domain object.
class Song {
  final String id;          // Isar Id as string
  final String videoId;
  final String title;
  final String? artist;
  final String localAudioPath;
  final String localThumbnailPath;
  final Duration duration;
  final DateTime dateAdded;

  const Song({
    required this.id,
    required this.videoId,
    required this.title,
    this.artist,
    required this.localAudioPath,
    required this.localThumbnailPath,
    required this.duration,
    required this.dateAdded,
  });

  Song copyWith({
    String? id,
    String? videoId,
    String? title,
    String? artist,
    String? localAudioPath,
    String? localThumbnailPath,
    Duration? duration,
    DateTime? dateAdded,
  }) {
    return Song(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      localThumbnailPath: localThumbnailPath ?? this.localThumbnailPath,
      duration: duration ?? this.duration,
      dateAdded: dateAdded ?? this.dateAdded,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId;

  @override
  int get hashCode => videoId.hashCode;
}
