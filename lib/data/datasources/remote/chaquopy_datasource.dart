import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:chaquopy/chaquopy.dart';

/// Message sent to the background isolate.
class _IsolateRequest {
  final String code;
  final SendPort replyPort;
  _IsolateRequest(this.code, this.replyPort);
}

/// Datasource that uses Chaquopy to run yt-dlp via Python locally on Android.
///
/// All Chaquopy calls are routed through a single persistent background isolate
/// to avoid the overhead of spawning/destroying isolates per download.
class ChaquopyDatasource {
  Isolate? _isolate;
  SendPort? _sendPort;
  final Completer<void> _ready = Completer<void>();

  ChaquopyDatasource() {
    _spawnIsolate();
  }

  /// Spawn the persistent background isolate once.
  Future<void> _spawnIsolate() async {
    final token = RootIsolateToken.instance!;
    final receivePort = ReceivePort();

    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _IsolateInitPayload(receivePort.sendPort, token),
    );

    // First message from the isolate is its SendPort.
    _sendPort = await receivePort.first as SendPort;
    _ready.complete();
  }

  /// The isolate's long-running event loop.
  static Future<void> _isolateEntryPoint(_IsolateInitPayload payload) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(payload.token);

    final commandPort = ReceivePort();
    // Send our SendPort back to the main isolate.
    payload.mainSendPort.send(commandPort.sendPort);

    // Process requests sequentially.
    await for (final message in commandPort) {
      if (message is _IsolateRequest) {
        try {
          final result = await Chaquopy.executeCode(message.code);
          final output = result['textOutputOrError']?.toString() ?? '';
          message.replyPort.send(output);
        } catch (e) {
          message.replyPort.send('ERROR:$e');
        }
      }
    }
  }

  /// Execute Python code on the persistent background isolate.
  Future<String> _executeOnIsolate(String code) async {
    await _ready.future;
    final replyPort = ReceivePort();
    _sendPort!.send(_IsolateRequest(code, replyPort.sendPort));
    final result = await replyPort.first as String;
    return result;
  }

  /// Download audio for a YouTube video using Chaquopy embedded Python.
  Future<String> downloadAudio({
    required String videoId,
    required String outputDir,
    required String safeFilename,
    void Function(double progress, String speed)? onProgress,
  }) async {
    final code = '''
import sys
import traceback

try:
    import ytdlp_wrapper
    result = ytdlp_wrapper.download_audio("$videoId", "$outputDir", "$safeFilename")
    print(f"SUCCESS:{result}")
except Exception as e:
    print(f"ERROR:{traceback.format_exc()}")
''';

    print('[ChaquopyDS] Starting download for videoId=$videoId');
    print('[ChaquopyDS] Output dir: $outputDir, filename: $safeFilename');
    
    final output = await _executeOnIsolate(code);
    
    print('[ChaquopyDS] Raw Chaquopy output: $output');
    
    if (output.contains('SUCCESS:')) {
      final path = output.split('SUCCESS:').last.trim();
      print('[ChaquopyDS] Reported path: $path');
      
      final file = File(path);
      if (file.existsSync()) {
        final fileSize = file.lengthSync();
        print('[ChaquopyDS] File exists! Size: $fileSize bytes');
        
        if (fileSize == 0) {
          throw Exception("Downloaded file is empty (0 bytes): $path");
        }
        
        return path;
      } else {
        throw Exception("Python reported success but file not found: $path");
      }
    } else {
      throw Exception("Chaquopy execution failed: $output");
    }
  }

  /// Download audio AND return metadata in one shot.
  /// Uses the `download_audio_full` Python function which returns JSON
  /// containing both the file path and extracted metadata.
  Future<Map<String, dynamic>> downloadAudioFull({
    required String videoId,
    required String outputDir,
    required String safeFilename,
  }) async {
    final code = '''
import sys
import traceback

try:
    import ytdlp_wrapper
    result = ytdlp_wrapper.download_audio_full("$videoId", "$outputDir", "$safeFilename")
    print(f"SUCCESS:{result}")
except Exception as e:
    print(f"ERROR:{traceback.format_exc()}")
''';

    print('[ChaquopyDS] Starting full download for videoId=$videoId');

    final output = await _executeOnIsolate(code);

    print('[ChaquopyDS] Raw full output: $output');

    if (output.contains('SUCCESS:')) {
      final jsonStr = output.split('SUCCESS:').last.trim();
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
    } else {
      throw Exception("Chaquopy full download failed: $output");
    }
  }

  /// Fetch metadata for a single video without downloading.
  Future<Map<String, dynamic>> fetchVideoMetadata(String videoId) async {
    final code = '''
import sys
import traceback

try:
    import ytdlp_wrapper
    result = ytdlp_wrapper.fetch_video_metadata("$videoId")
    print(f"SUCCESS:{result}")
except Exception as e:
    print(f"ERROR:{traceback.format_exc()}")
''';

    final output = await _executeOnIsolate(code);

    if (output.contains('SUCCESS:')) {
      final jsonStr = output.split('SUCCESS:').last.trim();
      return Map<String, dynamic>.from(json.decode(jsonStr));
    } else {
      throw Exception("Chaquopy metadata fetch failed: $output");
    }
  }

  /// Fetch the list of videos in a YouTube playlist without downloading.
  /// Returns a map with 'title' (playlist name) and 'entries' (list of video maps).
  Future<Map<String, dynamic>> fetchPlaylistVideos(String playlistUrl) async {
    final safeUrl = playlistUrl.replaceAll('"', '\\"');
    final code = '''
import sys
import traceback

try:
    import ytdlp_wrapper
    result = ytdlp_wrapper.fetch_playlist_videos("$safeUrl")
    print(f"SUCCESS:{result}")
except Exception as e:
    print(f"ERROR:{traceback.format_exc()}")
''';

    final output = await _executeOnIsolate(code);

    if (output.contains('SUCCESS:')) {
      final jsonStr = output.split('SUCCESS:').last.trim();
      return Map<String, dynamic>.from(json.decode(jsonStr));
    } else {
      throw Exception("Chaquopy playlist extraction failed: $output");
    }
  }

  /// Clean up the persistent isolate.
  void dispose() {
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _sendPort = null;
  }
}

/// Payload sent to the isolate during initialization.
class _IsolateInitPayload {
  final SendPort mainSendPort;
  final RootIsolateToken token;
  _IsolateInitPayload(this.mainSendPort, this.token);
}
