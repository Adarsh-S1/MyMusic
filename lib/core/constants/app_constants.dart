/// App-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'YT-Groove';
  static const String appVersion = '1.0.0';

  // Storage paths
  static const String baseMusicDir = '/storage/emulated/0/Music/YT-Groove';
  static const String baseThumbnailDir = '/storage/emulated/0/Pictures/YT-Groove';

  // Default metadata
  static const String defaultAlbum = 'YouTube Downloads';
  static const String defaultArtist = 'Unknown Artist';

  // Download
  static const int maxConcurrentDownloads = 2;
  static const Duration searchDebounce = Duration(milliseconds: 300);

  // Audio notification
  static const String audioNotificationChannelId = 'com.example.mymusic.channel.audio';
  static const String audioNotificationChannelName = 'YT-Groove Playback';

  // Download notification
  static const String downloadNotificationChannelId = 'com.example.mymusic.channel.download';
  static const String downloadNotificationChannelName = 'YT-Groove Downloads';
}

/// Supported YouTube URL regex patterns.
class YoutubePatterns {
  YoutubePatterns._();

  /// Matches standard YouTube watch URLs: youtube.com/watch?v=VIDEO_ID
  static final RegExp standardWatch = RegExp(
    r'^https?://(www\.)?youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})',
  );

  /// Matches short URLs: youtu.be/VIDEO_ID
  static final RegExp shortUrl = RegExp(
    r'^https?://youtu\.be/([a-zA-Z0-9_-]{11})',
  );

  /// Matches Shorts: youtube.com/shorts/VIDEO_ID
  static final RegExp shorts = RegExp(
    r'^https?://(www\.)?youtube\.com/shorts/([a-zA-Z0-9_-]{11})',
  );

  /// Matches mobile URLs: m.youtube.com/watch?v=VIDEO_ID
  static final RegExp mobile = RegExp(
    r'^https?://m\.youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})',
  );

  /// Matches the `list=PLAYLIST_ID` parameter in any YouTube URL.
  static final RegExp playlistParam = RegExp(
    r'[?&]list=([a-zA-Z0-9_-]+)',
  );

  /// Matches a pure playlist URL: youtube.com/playlist?list=PLAYLIST_ID
  static final RegExp playlistUrl = RegExp(
    r'^https?://(www\.)?youtube\.com/playlist\?list=([a-zA-Z0-9_-]+)',
  );

  /// Extracts video ID from any supported YouTube URL format.
  static String? extractVideoId(String url) {
    RegExpMatch? match;

    match = standardWatch.firstMatch(url);
    if (match != null) return match.group(2);

    match = shortUrl.firstMatch(url);
    if (match != null) return match.group(1);

    match = shorts.firstMatch(url);
    if (match != null) return match.group(2);

    match = mobile.firstMatch(url);
    if (match != null) return match.group(1);

    return null;
  }

  /// Extracts playlist ID from any YouTube URL that contains `list=` parameter.
  static String? extractPlaylistId(String url) {
    final match = playlistParam.firstMatch(url);
    return match?.group(1);
  }
}
