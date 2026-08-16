import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Datasource that uses Chaquopy to run yt-dlp via Python locally on Android.
///
/// All Python calls are dispatched via a custom MethodChannel that runs
/// the embedded Python interpreter on a native Kotlin background thread,
/// keeping both the Dart UI thread and Android Main thread completely free.
class ChaquopyDatasource {
  static const MethodChannel _channel =
      MethodChannel('com.example.mymusic/python');

  /// Call a function in ytdlp_wrapper.py on a native background thread.
  Future<String> _callPython(String function, List<dynamic> args) async {
    try {
      final result = await _channel.invokeMethod<String>('execute', {
        'function': function,
        'args': args,
      });
      return result ?? '';
    } on PlatformException catch (e) {
      throw Exception('Python call failed ($function): ${e.message}');
    }
  }

  /// Download audio AND return metadata in one shot.
  Future<Map<String, dynamic>> downloadAudioFull({
    required String videoId,
    required String outputDir,
    required String safeFilename,
  }) async {
    final jsonStr = await _callPython(
        'download_audio_full', [videoId, outputDir, safeFilename]);
    final data = Map<String, dynamic>.from(json.decode(jsonStr));

    // Verify file exists
    final path = data['path'] as String;
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception("Python reported success but file not found: $path");
    }
    if (file.lengthSync() == 0) {
      throw Exception("Downloaded file is empty (0 bytes): $path");
    }

    return data;
  }

  /// Fetch metadata for a single video without downloading.
  Future<Map<String, dynamic>> fetchVideoMetadata(String videoId) async {
    final jsonStr = await _callPython('fetch_video_metadata', [videoId]);
    return Map<String, dynamic>.from(json.decode(jsonStr));
  }

  /// Fetch the list of videos in a YouTube playlist without downloading.
  Future<Map<String, dynamic>> fetchPlaylistVideos(String playlistUrl) async {
    final jsonStr = await _callPython('fetch_playlist_videos', [playlistUrl]);
    return Map<String, dynamic>.from(json.decode(jsonStr));
  }

  void dispose() {}
}
