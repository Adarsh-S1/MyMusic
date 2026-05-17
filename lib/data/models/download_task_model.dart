import 'package:mymusic/domain/entities/download_task.dart';

/// Data transfer object for a download task.
class DownloadTaskModel {
  final String id;
  final String youtubeUrl;
  final String? videoId;
  final String? title;
  final String? thumbnailUrl;
  final DownloadStatus status;
  final double progress;
  final double speedBytesPerSec;
  final int downloadedBytes;
  final int totalBytes;
  final String? errorMessage;

  const DownloadTaskModel({
    required this.id,
    required this.youtubeUrl,
    this.videoId,
    this.title,
    this.thumbnailUrl,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.speedBytesPerSec = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  /// Convert to domain entity.
  DownloadTask toEntity() {
    return DownloadTask(
      id: id,
      youtubeUrl: youtubeUrl,
      videoId: videoId,
      title: title,
      thumbnailUrl: thumbnailUrl,
      status: status,
      progress: progress,
      speedBytesPerSec: speedBytesPerSec,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      errorMessage: errorMessage,
    );
  }

  /// Create from domain entity.
  factory DownloadTaskModel.fromEntity(DownloadTask task) {
    return DownloadTaskModel(
      id: task.id,
      youtubeUrl: task.youtubeUrl,
      videoId: task.videoId,
      title: task.title,
      thumbnailUrl: task.thumbnailUrl,
      status: task.status,
      progress: task.progress,
      speedBytesPerSec: task.speedBytesPerSec,
      downloadedBytes: task.downloadedBytes,
      totalBytes: task.totalBytes,
      errorMessage: task.errorMessage,
    );
  }
}
