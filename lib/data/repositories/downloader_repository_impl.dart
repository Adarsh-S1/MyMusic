import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mymusic/core/constants/app_constants.dart';
import 'package:mymusic/core/extensions/extensions.dart';
import 'package:mymusic/data/datasources/local/song_dao.dart';
import 'package:mymusic/data/datasources/remote/youtube_datasource.dart';
import 'package:mymusic/domain/entities/download_task.dart';
import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/domain/repositories/i_downloader_repository.dart';

class DownloaderRepositoryImpl implements IDownloaderRepository {
  final IYoutubeDatasource _youtubeDatasource;
  final SongDao _songDao;
  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};

  DownloaderRepositoryImpl({
    required IYoutubeDatasource youtubeDatasource,
    required SongDao songDao,
    Dio? dio,
  })  : _youtubeDatasource = youtubeDatasource,
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
    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

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
      // Get storage directory
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) throw Exception('Cannot access external storage');

      final musicDir = Directory('${extDir.path}/${AppConstants.musicSubDir}');
      final thumbDir = Directory('${extDir.path}/${AppConstants.thumbnailSubDir}');
      await musicDir.create(recursive: true);
      await thumbDir.create(recursive: true);

      final safeTitle = metadata.title.toSafeFilename();
      // Save as .m4a — just_audio plays AAC/MP4 containers natively.
      // This avoids needing FFmpeg for conversion entirely.
      final audioPath = '${musicDir.path}/${videoId}_$safeTitle.m4a';
      final thumbnailPath = '${thumbDir.path}/$videoId.jpg';

      // Handle file collision
      String outputPath = audioPath;
      int collision = 1;
      while (File(outputPath).existsSync()) {
        outputPath = '${musicDir.path}/${videoId}_${safeTitle}_$collision.m4a';
        collision++;
      }

      // ─── Step 1: Download thumbnail ──────────────────────
      try {
        await _dio.download(
          metadata.thumbnailUrl,
          thumbnailPath,
          cancelToken: cancelToken,
        );
      } catch (_) {
        // Thumbnail download failure is non-critical
      }

      // ─── Step 2: Download audio stream directly ──────────
      // youtube_explode_dart provides AAC/MP4 streams that
      // just_audio can play without any conversion.
      task = task.copyWith(status: DownloadStatus.downloading);
      yield task;

      final stopwatch = Stopwatch()..start();
      int lastBytes = 0;

      await _dio.download(
        stream.url,
        outputPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final elapsed = stopwatch.elapsedMilliseconds;
          double speed = 0;
          if (elapsed > 0) {
            speed = ((received - lastBytes) / (elapsed / 1000));
            lastBytes = received;
            stopwatch.reset();
          }

          task = task.copyWith(
            progress: total > 0 ? received / total : 0,
            downloadedBytes: received,
            totalBytes: total > 0 ? total : stream.sizeBytes,
            speedBytesPerSec: speed,
          );
        },
      );

      yield task.copyWith(progress: 1.0);

      // ─── Step 3: Save to database ───────────────────────
      task = task.copyWith(status: DownloadStatus.processing);
      yield task;

      final song = Song(
        id: '0', // Will be auto-assigned by Isar
        videoId: videoId,
        title: metadata.title,
        artist: metadata.author,
        localAudioPath: outputPath,
        localThumbnailPath: thumbnailPath,
        duration: metadata.duration,
        dateAdded: DateTime.now(),
      );

      await _songDao.saveSong(song);

      // ─── Step 4: Emit completion ─────────────────────────
      task = task.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
      );
      yield task;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        task = task.copyWith(
          status: DownloadStatus.cancelled,
          errorMessage: 'Download cancelled',
        );
      } else {
        task = task.copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'Network error: ${e.message}',
        );
      }
      yield task;
    } catch (e) {
      task = task.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );
      yield task;
    } finally {
      _cancelTokens.remove(taskId);
    }
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    _cancelTokens[taskId]?.cancel('User cancelled');
    _cancelTokens.remove(taskId);
  }
}
