import 'dart:io';

import 'package:chaquopy/chaquopy.dart';

/// Datasource that uses Chaquopy to run yt-dlp via Python locally on Android.
class ChaquopyDatasource {
  
  /// Download audio for a YouTube video using Chaquopy embedded Python.
  Future<String> downloadAudio({
    required String videoId,
    required String outputDir,
    required String safeFilename,
    void Function(double progress, String speed)? onProgress,
  }) async {
    // The Python code to execute.
    // It imports the ytdlp_wrapper module we created in android/app/src/main/python
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
    
    final result = await Chaquopy.executeCode(code);
    final output = result['textOutputOrError']?.toString() ?? '';
    
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
        // Try listing files in the output directory to help debug
        final dir = Directory(outputDir);
        if (dir.existsSync()) {
          final files = dir.listSync();
          print('[ChaquopyDS] Files in output dir:');
          for (final f in files) {
            print('[ChaquopyDS]   ${f.path}');
          }
        }
        throw Exception("Python reported success but file not found: $path");
      }
    } else {
      throw Exception("Chaquopy execution failed: $output");
    }
  }

  /// Fetch playlist metadata using yt-dlp via Chaquopy
  Future<String> fetchPlaylistMetadata(String playlistId) async {
    final code = '''
import traceback

try:
    import ytdlp_wrapper
    result = ytdlp_wrapper.fetch_playlist_metadata("$playlistId")
    print(f"SUCCESS:{result}")
except Exception as e:
    print(f"ERROR:{traceback.format_exc()}")
''';

    final result = await Chaquopy.executeCode(code);
    final output = result['textOutputOrError']?.toString() ?? '';
    
    if (output.contains('SUCCESS:')) {
      final jsonStr = output.split('SUCCESS:').last.trim();
      return jsonStr;
    } else {
      throw Exception("Chaquopy execution failed: $output");
    }
  }
}
