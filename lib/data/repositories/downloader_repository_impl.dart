import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:mymusic/core/constants/app_constants.dart';
import 'package:mymusic/core/extensions/extensions.dart';
import 'package:mymusic/core/utils/media_scanner.dart';
import 'package:mymusic/data/datasources/local/song_dao.dart';
import 'package:mymusic/data/datasources/remote/chaquopy_datasource.dart';
import 'package:mymusic/domain/entities/download_task.dart';
import 'package:mymusic/domain/entities/playlist_entry.dart';
import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/domain/repositories/i_downloader_repository.dart';

/// Downloader implementation powered entirely by yt-dlp (via Chaquopy).
///
/// yt-dlp handles metadata extraction, stream selection, and audio download.
/// No separate youtube_explode dependency needed.
class DownloaderRepositoryImpl implements IDownloaderRepository {
  final ChaquopyDatasource _chaquopyDatasource;
  final SongDao _songDao;
  final Dio _dio;
  final Set<String> _cancelledTasks = {};

  DownloaderRepositoryImpl({
    required ChaquopyDatasource chaquopyDatasource,
    required SongDao songDao,
    Dio? dio,
  }) : _chaquopyDatasource = chaquopyDatasource,
       _songDao = songDao,
       _dio = dio ?? Dio();

  @override
  String? validateYoutubeUrl(String url) {
    return YoutubePatterns.extractVideoId(url.trim());
  }

  @override
  String? validateYoutubePlaylistUrl(String url) {
    return YoutubePatterns.extractPlaylistId(url.trim());
  }

  @override
  Future<VideoMetadata> fetchVideoMetadata(String videoId) async {
    final data = await _chaquopyDatasource.fetchVideoMetadata(videoId);
    return VideoMetadata(
      videoId: videoId,
      title: data['title'] as String? ?? 'Unknown Title',
      author: data['author'] as String? ?? 'Unknown Artist',
      duration: Duration(seconds: (data['duration'] as num?)?.toInt() ?? 0),
      thumbnailUrl: data['thumbnail'] as String? ??
          'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
    );
  }

  @override
  Future<PlaylistMetadata> fetchPlaylistMetadata(String playlistId) async {
    final result = await _chaquopyDatasource.fetchPlaylistVideos(
      'https://youtube.com/playlist?list=$playlistId',
    );
    final title = result['title'] as String? ?? 'YouTube Playlist';
    final rawEntries = result['entries'] as List? ?? [];

    final videos = <VideoMetadata>[];
    for (final entry in rawEntries) {
      if (entry['video_id'] == null) continue;
      final durationSecs = entry['duration'] as int? ?? 0;
      videos.add(VideoMetadata(
        videoId: entry['video_id'],
        title: entry['title'] ?? 'Unknown Title',
        author: 'Unknown Artist',
        duration: Duration(seconds: durationSecs),
        thumbnailUrl: 'https://i.ytimg.com/vi/${entry['video_id']}/hqdefault.jpg',
      ));
    }

    return PlaylistMetadata(
      playlistId: playlistId,
      title: title,
      author: 'Unknown',
      videos: videos,
    );
  }

  @override
  Stream<DownloadTask> downloadAudioDirect({
    required String videoId,
    required String title,
    String? playlistName,
  }) async* {
    final taskId = DateTime.now().microsecondsSinceEpoch.toString();

    DownloadTask task = DownloadTask(
      id: taskId,
      youtubeUrl: 'https://youtube.com/watch?v=$videoId',
      videoId: videoId,
      title: title,
      thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      status: DownloadStatus.pending,
    );

    yield task;

    try {
      // Get storage directories
      String musicPath = AppConstants.baseMusicDir;
      String thumbPath = AppConstants.baseThumbnailDir;

      if (playlistName != null && playlistName.isNotEmpty) {
        final safePlaylistName = playlistName.toSafeFilename();
        musicPath = '$musicPath/$safePlaylistName';
        thumbPath = '$thumbPath/$safePlaylistName';
      }

      final musicDir = Directory(musicPath);
      final thumbDir = Directory(thumbPath);
      await musicDir.create(recursive: true);
      await thumbDir.create(recursive: true);

      final safeTitle = title.toSafeFilename();
      final thumbnailPath = '${thumbDir.path}/$videoId.jpg';

      // ─── Step 1: Download audio via yt-dlp (also returns metadata) ────
      task = task.copyWith(status: DownloadStatus.downloading, progress: 0.0);
      yield task;

      if (_cancelledTasks.contains(taskId)) throw Exception("Cancelled");

      final result = await _chaquopyDatasource.downloadAudioFull(
        videoId: videoId,
        outputDir: musicDir.path,
        safeFilename: safeTitle,
      );

      final outputPath = result['path'] as String;
      final metadata = result['metadata'] as Map<String, dynamic>? ?? {};
      final author = metadata['author'] as String? ?? 'Unknown Artist';
      final durationSecs = (metadata['duration'] as num?)?.toInt() ?? 0;
      final thumbUrl = metadata['thumbnail'] as String? ??
          'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

      yield task.copyWith(progress: 1.0);

      // ─── Step 2: Download thumbnail via Dio ─────────────
      task = task.copyWith(status: DownloadStatus.processing);
      yield task;

      try {
        await _dio.download(thumbUrl, thumbnailPath);
      } catch (_) {
        // Thumbnail failure is non-critical
      }

      // ─── Step 3: Save to database ───────────────────────
      final song = Song(
        id: '0', // Auto-assigned by Isar
        videoId: videoId,
        title: metadata['title'] as String? ?? title,
        artist: author,
        localAudioPath: outputPath,
        localThumbnailPath: thumbnailPath,
        duration: Duration(seconds: durationSecs),
        dateAdded: DateTime.now(),
      );

      await _songDao.saveSong(song);

      // Register with Android MediaStore so file appears in other music apps
      await MediaScanner.scanFile(outputPath);

      // ─── Step 4: Emit completion ─────────────────────────
      task = task.copyWith(status: DownloadStatus.completed, progress: 1.0);
      yield task;
    } catch (e) {
      task = task.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );
      yield task;
    } finally {
      _cancelledTasks.remove(taskId);
    }
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    _cancelledTasks.add(taskId);
  }

  @override
  Future<(String, List<PlaylistEntry>)> fetchPlaylistVideos(String playlistUrl) async {
    final result = await _chaquopyDatasource.fetchPlaylistVideos(playlistUrl);
    final title = result['title'] as String? ?? 'Unknown Playlist';
    final rawEntries = result['entries'] as List? ?? [];
    final entries = rawEntries.map((e) {
      return PlaylistEntry(
        videoId: e['video_id'] as String,
        title: e['title'] as String? ?? 'Unknown',
        durationSeconds: e['duration'] as int?,
      );
    }).toList();
    return (title, entries);
  }
}
