/// App-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'YT-Groove';
  static const String appVersion = '1.0.0';

  // Storage paths
  static const String musicSubDir = 'yt-groove/audio';
  static const String thumbnailSubDir = 'yt-groove/thumbnails';

  // Default metadata
  static const String defaultAlbum = 'YouTube Downloads';
  static const String defaultArtist = 'Unknown Artist';

  // Download
  static const int maxConcurrentDownloads = 2;
  static const Duration searchDebounce = Duration(milliseconds: 300);

  // Audio notification
  static const String audioNotificationChannelId = 'com.example.mymusic.channel.audio';
  static const String audioNotificationChannelName = 'YT-Groove Playback';
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

  /// Matches YouTube playlist URLs: youtube.com/playlist?list=PLAYLIST_ID
  static final RegExp playlistUrl = RegExp(
    r'^https?://(www\.|m\.)?youtube\.com/playlist\?.*list=([a-zA-Z0-9_-]+)',
  );

  /// Matches playlist ID embedded in watch URLs: youtube.com/watch?v=...&list=PLAYLIST_ID
  static final RegExp watchWithPlaylist = RegExp(
    r'^https?://(www\.|m\.)?youtube\.com/watch\?.*list=([a-zA-Z0-9_-]+)',
  );

  /// Extracts playlist ID from a YouTube URL, or null if not a playlist URL.
  static String? extractPlaylistId(String url) {
    RegExpMatch? match;

    match = playlistUrl.firstMatch(url);
    if (match != null) return match.group(2);

    match = watchWithPlaylist.firstMatch(url);
    if (match != null) return match.group(2);

    return null;
  }

  /// Returns true if the URL is a playlist URL (not just a video with list param).
  static bool isPlaylistUrl(String url) {
    return playlistUrl.hasMatch(url.trim());
  }
}
