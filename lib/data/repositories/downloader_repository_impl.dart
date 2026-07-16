import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:mymusic/core/constants/app_constants.dart';
import 'package:mymusic/core/extensions/extensions.dart';
import 'package:mymusic/core/utils/media_scanner.dart';
import 'package:mymusic/data/datasources/local/song_dao.dart';
import 'package:mymusic/data/datasources/remote/youtube_datasource.dart';
import 'package:mymusic/data/datasources/remote/chaquopy_datasource.dart';
import 'package:mymusic/domain/entities/download_task.dart';
import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/domain/repositories/i_downloader_repository.dart';

/// Hybrid downloader implementation:
///   • youtube_explode_dart → metadata, thumbnail URL, video validation
///   • yt-dlp CLI            → actual audio file download (bypasses 403s)
class DownloaderRepositoryImpl implements IDownloaderRepository {
  final IYoutubeDatasource _youtubeDatasource;
  final ChaquopyDatasource _chaquopyDatasource;
  final SongDao _songDao;
  final Dio _dio;
  // Note: Chaquopy runs inside the process, so it cannot be cancelled easily via Process.kill.
  final Set<String> _cancelledTasks = {};

  DownloaderRepositoryImpl({
    required IYoutubeDatasource youtubeDatasource,
    required ChaquopyDatasource chaquopyDatasource,
    required SongDao songDao,
    Dio? dio,
  }) : _youtubeDatasource = youtubeDatasource,
       _chaquopyDatasource = chaquopyDatasource,
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
  Future<VideoMetadata> fetchVideoMetadata(String videoId) {
    return _youtubeDatasource.fetchMetadata(videoId);
  }

  @override
  Future<PlaylistMetadata> fetchPlaylistMetadata(String playlistId) async {
    final jsonStr = await _chaquopyDatasource.fetchPlaylistMetadata(playlistId);
    final data = jsonDecode(jsonStr);
    
    final videos = <VideoMetadata>[];
    final entries = data['entries'] as List<dynamic>? ?? [];
    
    for (final entry in entries) {
      if (entry['id'] == null) continue;
      
      final durationSecs = entry['duration'] as num? ?? 0;
      
      videos.add(VideoMetadata(
        videoId: entry['id'],
        title: entry['title'] ?? 'Unknown Title',
        author: entry['uploader'] ?? data['uploader'] ?? 'Unknown Artist',
        duration: Duration(seconds: durationSecs.toInt()),
        thumbnailUrl: 'https://i.ytimg.com/vi/${entry['id']}/hqdefault.jpg',
      ));
    }
    
    return PlaylistMetadata(
      playlistId: playlistId,
      title: data['title'] ?? 'YouTube Playlist',
      author: data['uploader'] ?? 'Unknown',
      videos: videos,
    );
  }

  @override
  Future<List<AudioStreamInfo>> getAudioStreams(String videoId) {
    return _youtubeDatasource.getAudioStreams(videoId);
  }

  @override
  Stream<DownloadTask> downloadAudio({
    required String videoId,
    required VideoMetadata metadata,
    required AudioStreamInfo stream,
  }) async* {
    final taskId = DateTime.now().microsecondsSinceEpoch.toString();

    DownloadTask task = DownloadTask(
      id: taskId,
      youtubeUrl: 'https://youtube.com/watch?v=$videoId',
      videoId: videoId,
      title: metadata.title,
      thumbnailUrl: metadata.thumbnailUrl,
      status: DownloadStatus.pending,
    );

    yield task;

    try {
      // Use public shared directories so files survive app uninstall
      final musicDir = await AppConstants.getPublicMusicDir();
      final thumbDir = await AppConstants.getPublicThumbnailDir();

      final safeTitle = metadata.title.toSafeFilename();
      final thumbnailPath = '${thumbDir.path}/$videoId.jpg';

      // ─── Step 1: Download thumbnail via Dio ─────────────
      try {
        await _dio.download(metadata.thumbnailUrl, thumbnailPath);
      } catch (_) {
        // Thumbnail failure is non-critical
      }

      // ─── Step 2: Download audio via Chaquopy yt-dlp ──────────
      task = task.copyWith(status: DownloadStatus.downloading, progress: 0.0);
      yield task;

      if (_cancelledTasks.contains(taskId)) throw Exception("Cancelled");

      // This handles YouTube's signature challenges internally via Python.
      final outputPath = await _chaquopyDatasource.downloadAudio(
        videoId: videoId,
        outputDir: musicDir.path,
        safeFilename: safeTitle,
        onProgress: (progress, speed) {
          // Chaquopy executeCode is blocking/async but doesn't easily stream progress back yet.
          // The wrapper currently prints success at the end.
        },
      );

      yield task.copyWith(progress: 1.0);

      // ─── Step 3: Save to database ───────────────────────
      task = task.copyWith(status: DownloadStatus.processing);
      yield task;

      final song = Song(
        id: '0', // Auto-assigned by Isar
        videoId: videoId,
        title: metadata.title,
        artist: metadata.author,
        localAudioPath: outputPath,
        localThumbnailPath: thumbnailPath,
        duration: metadata.duration,
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

  /// Parse yt-dlp speed string like "10.73MiB/s" to bytes/sec.
  // ignore: unused_element
  double _parseSpeed(String speed) {
    if (speed.isEmpty) return 0;
    try {
      final match = RegExp(r'([\d.]+)\s*(KiB|MiB|GiB|B)').firstMatch(speed);
      if (match == null) return 0;
      final value = double.parse(match.group(1)!);
      final unit = match.group(2)!;
      switch (unit) {
        case 'GiB':
          return value * 1024 * 1024 * 1024;
        case 'MiB':
          return value * 1024 * 1024;
        case 'KiB':
          return value * 1024;
        default:
          return value;
      }
    } catch (_) {
      return 0;
    }
  }
}
