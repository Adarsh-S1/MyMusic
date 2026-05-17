import 'package:mymusic/core/constants/app_constants.dart';

/// Validates a YouTube URL and returns the video ID if valid.
class ValidateYoutubeUrlUsecase {
  /// Returns the video ID if valid, null otherwise.
  String? execute(String url) {
    if (url.trim().isEmpty) return null;

    // Check if it's a URL at all
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return null;

    // Must be a YouTube URL
    final host = uri.host.toLowerCase();
    if (!host.contains('youtube.com') && !host.contains('youtu.be')) {
      return null;
    }

    return YoutubePatterns.extractVideoId(url.trim());
  }
}
