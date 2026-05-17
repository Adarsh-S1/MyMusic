/// Status of a download task.
enum DownloadStatus {
  pending,
  downloading,
  processing,
  completed,
  failed,
  cancelled,
}

/// Immutable DownloadTask entity.
class DownloadTask {
  final String id;
  final String youtubeUrl;
  final String? videoId;
  final String? title;
  final String? thumbnailUrl;
  final DownloadStatus status;
  final double progress;        // 0.0 → 1.0
  final double speedBytesPerSec;
  final int downloadedBytes;
  final int totalBytes;
  final String? errorMessage;

  const DownloadTask({
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

  /// Factory for creating a pending task from a URL.
  factory DownloadTask.pending({required String url}) {
    return DownloadTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      youtubeUrl: url,
    );
  }

  DownloadTask copyWith({
    String? id,
    String? youtubeUrl,
    String? videoId,
    String? title,
    String? thumbnailUrl,
    DownloadStatus? status,
    double? progress,
    double? speedBytesPerSec,
    int? downloadedBytes,
    int? totalBytes,
    String? errorMessage,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Human-readable speed string.
  String get formattedSpeed {
    if (speedBytesPerSec < 1024) return '${speedBytesPerSec.toStringAsFixed(0)} B/s';
    if (speedBytesPerSec < 1024 * 1024) {
      return '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Estimated time remaining.
  Duration? get eta {
    if (speedBytesPerSec <= 0 || totalBytes <= 0) return null;
    final remaining = totalBytes - downloadedBytes;
    return Duration(seconds: (remaining / speedBytesPerSec).ceil());
  }
}
