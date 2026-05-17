/// Immutable Playlist entity.
class Playlist {
  final String id;
  final String name;
  final DateTime dateCreated;
  final List<String> songVideoIds;

  const Playlist({
    required this.id,
    required this.name,
    required this.dateCreated,
    this.songVideoIds = const [],
  });

  Playlist copyWith({
    String? id,
    String? name,
    DateTime? dateCreated,
    List<String>? songVideoIds,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      dateCreated: dateCreated ?? this.dateCreated,
      songVideoIds: songVideoIds ?? this.songVideoIds,
    );
  }
}
