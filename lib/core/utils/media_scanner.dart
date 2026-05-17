import 'package:flutter/services.dart';

/// Dart-side wrapper for the native MediaScanner platform channel.
/// Notifies Android's MediaStore after saving a downloaded MP3.
class MediaScanner {
  static const _channel = MethodChannel('com.ytgroove/media_scanner');

  MediaScanner._();

  /// Scan a file so it appears in other music apps via MediaStore.
  static Future<String?> scanFile(String filePath) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'scanFile',
        {'path': filePath},
      );
      return result;
    } on PlatformException catch (e) {
      // Non-critical — log but don't crash
      // ignore: avoid_print
      print('MediaScanner error: ${e.message}');
      return null;
    }
  }
}
