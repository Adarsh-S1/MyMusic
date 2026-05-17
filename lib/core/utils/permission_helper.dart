import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Handles runtime permission requests across Android versions.
class PermissionHelper {
  PermissionHelper._();

  /// Requests audio/storage permission based on Android SDK version.
  static Future<bool> requestAudioPermission() async {
    if (!Platform.isAndroid) return true;

    // Android 13+ uses granular media permissions
    // Older versions use broad storage permission
    final permission = Permission.audio;
    final status = await permission.request();
    if (status.isGranted) return true;

    // Fallback to storage for older APIs
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  /// Checks if we have audio/storage permission without requesting.
  static Future<bool> hasAudioPermission() async {
    if (!Platform.isAndroid) return true;
    final audioGranted = await Permission.audio.isGranted;
    if (audioGranted) return true;
    return Permission.storage.isGranted;
  }
}
