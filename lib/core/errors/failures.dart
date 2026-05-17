/// Base failure class for the app.
sealed class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

/// Network-related failure.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error occurred']);
}

/// YouTube extraction failure.
class ExtractionFailure extends Failure {
  const ExtractionFailure([super.message = 'Failed to extract audio from YouTube']);
}

/// YouTube URL validation failure.
class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Invalid YouTube URL']);
}

/// Storage / file system failure.
class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Storage error occurred']);
}

/// Database failure.
class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'Database error occurred']);
}

/// Permission failure.
class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permission denied']);
}

/// FFmpeg conversion failure.
class ConversionFailure extends Failure {
  const ConversionFailure([super.message = 'Audio conversion failed']);
}

/// Video unavailable or private.
class VideoUnavailableFailure extends Failure {
  const VideoUnavailableFailure([super.message = 'Video unavailable or private']);
}
