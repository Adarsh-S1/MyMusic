import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mymusic/core/constants/app_constants.dart';
import 'package:mymusic/core/extensions/extensions.dart';
import 'package:mymusic/data/datasources/local/song_dao.dart';
import 'package:mymusic/data/datasources/remote/youtube_datasource.dart';
import 'package:mymusic/data/datasources/remote/ytdlp_datasource.dart';
import 'package:mymusic/domain/entities/download_task.dart';
import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/domain/repositories/i_downloader_repository.dart';

/// Hybrid downloader implementation:
///   • youtube_explode_dart → metadata, thumbnail URL, video validation
///   • yt-dlp CLI            → actual audio file download (bypasses 403s)
class DownloaderRepositoryImpl implements IDownloaderRepository {
  final IYoutubeDatasource _youtubeDatasource;
  final YtDlpDatasource _ytDlpDatasource;
  final SongDao _songDao;
  final Dio _dio;
  final Map<String, Process> _activeProcesses = {};

  DownloaderRepositoryImpl({
    required IYoutubeDatasource youtubeDatasource,
    required YtDlpDatasource ytDlpDatasource,
    required SongDao songDao,
    Dio? dio,
  })  : _youtubeDatasource = youtubeDatasource,
        _ytDlpDatasource = ytDlpDatasource,
        _songDao = songDao,
        _dio = dio ?? Dio();

  @override
  String? validateYoutubeUrl(String url) {
    return YoutubePatterns.extractVideoId(url.trim());
  }

  @override
  Future<VideoMetadata> fetchVideoMetadata(String videoId) {
    return _youtubeDatasource.fetchMetadata(videoId);
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
      // Get storage directories
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) throw Exception('Cannot access external storage');

      final musicDir = Directory('${extDir.path}/${AppConstants.musicSubDir}');
      final thumbDir = Directory('${extDir.path}/${AppConstants.thumbnailSubDir}');
      await musicDir.create(recursive: true);
      await thumbDir.create(recursive: true);

      final safeTitle = metadata.title.toSafeFilename();
      final thumbnailPath = '${thumbDir.path}/$videoId.jpg';

      // ─── Step 1: Download thumbnail via Dio ─────────────
      try {
        await _dio.download(metadata.thumbnailUrl, thumbnailPath);
      } catch (_) {
        // Thumbnail failure is non-critical
      }

      // ─── Step 2: Ensure yt-dlp binary is ready ──────────
      task = task.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.0,
      );
      yield task;

      // ─── Step 3: Download audio via yt-dlp ──────────────
      // This handles YouTube's signature challenges internally,
      // completely bypassing the 403 errors from youtube_explode.
      final outputPath = await _ytDlpDatasource.downloadAudio(
        videoId: videoId,
        outputDir: musicDir.path,
        safeFilename: safeTitle,
        onProgress: (progress, speed) {
          task = task.copyWith(
            progress: progress,
            speedBytesPerSec: _parseSpeed(speed),
          );
        },
      );

      yield task.copyWith(progress: 1.0);

      // ─── Step 4: Save to database ───────────────────────
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

      // ─── Step 5: Emit completion ─────────────────────────
      task = task.copyWith(status: DownloadStatus.completed, progress: 1.0);
      yield task;
    } catch (e) {
      task = task.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );
      yield task;
    } finally {
      _activeProcesses.remove(taskId);
    }
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    _activeProcesses[taskId]?.kill();
    _activeProcesses.remove(taskId);
  }

  /// Parse yt-dlp speed string like "10.73MiB/s" to bytes/sec.
  double _parseSpeed(String speed) {
    if (speed.isEmpty) return 0;
    try {
      final match = RegExp(r'([\d.]+)\s*(KiB|MiB|GiB|B)').firstMatch(speed);
      if (match == null) return 0;
      final value = double.parse(match.group(1)!);
      final unit = match.group(2)!;
      switch (unit) {
        case 'GiB': return value * 1024 * 1024 * 1024;
        case 'MiB': return value * 1024 * 1024;
        case 'KiB': return value * 1024;
        default: return value;
      }
    } catch (_) {
      return 0;
    }
  }
}
