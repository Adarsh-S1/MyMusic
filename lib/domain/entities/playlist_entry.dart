class PlaylistEntry {
  final String videoId;
  final String title;
  final int? durationSeconds;

  PlaylistEntry({
    required this.videoId,
    required this.title,
    this.durationSeconds,
  });
}
