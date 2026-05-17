import 'dart:io';
import 'package:mymusic/data/datasources/local/song_dao.dart';
import 'package:mymusic/data/datasources/local/playlist_dao.dart';
import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/domain/entities/playlist.dart';
import 'package:mymusic/domain/repositories/i_library_repository.dart';

class LibraryRepositoryImpl implements ILibraryRepository {
  final SongDao _songDao;
  final PlaylistDao _playlistDao;

  LibraryRepositoryImpl({
    required SongDao songDao,
    required PlaylistDao playlistDao,
  })  : _songDao = songDao,
        _playlistDao = playlistDao;

  @override
  Future<List<Song>> getAllSongs() => _songDao.getAllSongs();

  @override
  Future<Song?> getSongByVideoId(String videoId) =>
      _songDao.getSongByVideoId(videoId);

  @override
  Future<void> saveSong(Song song) => _songDao.saveSong(song);

  @override
  Future<void> deleteSong(String videoId) async {
    // Get song first to delete file
    final song = await _songDao.getSongByVideoId(videoId);
    if (song != null) {
      // Delete audio file
      try {
        final audioFile = File(song.localAudioPath);
        if (await audioFile.exists()) await audioFile.delete();
      } catch (_) {}

      // Delete thumbnail
      try {
        final thumbFile = File(song.localThumbnailPath);
        if (await thumbFile.exists()) await thumbFile.delete();
      } catch (_) {}

      // Delete DB record
      await _songDao.deleteSongByVideoId(videoId);
    }
  }

  @override
  Future<List<Song>> searchSongs(String query) => _songDao.searchSongs(query);

  @override
  Stream<List<Song>> watchAllSongs() => _songDao.watchAllSongs();

  // ─── Playlist operations ─────────────────────────────

  @override
  Future<List<Playlist>> getAllPlaylists() => _playlistDao.getAllPlaylists();

  @override
  Future<void> createPlaylist(String name) => _playlistDao.createPlaylist(name);

  @override
  Future<void> addSongToPlaylist(String playlistId, String videoId) =>
      _playlistDao.addSongToPlaylist(int.parse(playlistId), videoId);

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String videoId) =>
      _playlistDao.removeSongFromPlaylist(int.parse(playlistId), videoId);

  @override
  Future<void> deletePlaylist(String playlistId) =>
      _playlistDao.deletePlaylist(int.parse(playlistId));

  @override
  Future<List<Song>> getSongsForPlaylist(String playlistId) async {
    final playlist =
        await _playlistDao.getPlaylistById(int.parse(playlistId));
    if (playlist == null) return [];

    final songs = <Song>[];
    for (final videoId in playlist.songVideoIds) {
      final song = await _songDao.getSongByVideoId(videoId);
      if (song != null) songs.add(song);
    }
    return songs;
  }
}
