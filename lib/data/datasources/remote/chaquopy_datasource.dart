import 'dart:io';

import 'package:chaquopy/chaquopy.dart';
import 'package:mymusic/domain/entities/download_task.dart';

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

    final result = await Chaquopy.executeCode(code);
    final output = result['textOutputOrError']?.toString() ?? '';
    
    if (output.contains('SUCCESS:')) {
      final path = output.split('SUCCESS:').last.trim();
      if (File(path).existsSync()) {
        return path;
      } else {
        throw Exception("Python reported success but file not found: $path");
      }
    } else {
      throw Exception("Chaquopy execution failed: $output");
    }
  }
}
