import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mymusic/core/constants/app_constants.dart';
import 'package:mymusic/data/datasources/local/song_dao.dart';
import 'package:mymusic/domain/entities/song.dart';

/// Scans public directories for downloaded audio files and rebuilds
/// the Isar database. This ensures songs survive app uninstall because
/// the audio files live in public storage (/Music/YT-Groove/).
class DirectoryScanner {
  DirectoryScanner._();

  /// Scan public directories and upsert any files found into the database.
  /// Returns the number of songs restored.
  static Future<int> scanAndRestore(SongDao songDao) async {
    int restored = 0;

    try {
      final musicDir = await AppConstants.getPublicMusicDir();
      if (await musicDir.exists()) {
        await for (final entity in musicDir.list()) {
          if (entity is! File) continue;
          final path = entity.path;
          // Only process audio files
          if (!_isAudioFile(path)) continue;

          final filename = _basename(path);
          final videoId = _extractVideoId(filename);
          if (videoId == null) continue;

          // Check if already in DB
          final existing = await songDao.getSongByVideoId(videoId);
          if (existing != null) continue;

          // Derive title from filename: "<videoId>_<title>.<ext>"
          final title = _extractTitle(filename, videoId);
          final thumbPath = await _findThumbnail(videoId);

          final song = Song(
            id: '0',
            videoId: videoId,
            title: title,
            artist: null,
            localAudioPath: path,
            localThumbnailPath: thumbPath,
            duration: Duration.zero,
            dateAdded: entity.statSync().modified,
          );

          await songDao.saveSong(song);
          restored++;
        }
      }
    } catch (e) {
      debugPrint('[DirectoryScanner] Error scanning public music dir: $e');
    }

    // Also migrate from legacy app-specific storage if present
    restored += await _migrateLegacy(songDao);

    return restored;
  }

  /// Migrate files from the old app-specific external storage to public storage.
  static Future<int> _migrateLegacy(SongDao songDao) async {
    int migrated = 0;
    try {
      final extDir = await getExternalStorageDirectory();

      final legacyMusicDir = Directory('${extDir.path}/${AppConstants.musicSubDir}');
      if (!await legacyMusicDir.exists()) return 0;

      final publicMusicDir = await AppConstants.getPublicMusicDir();
      final publicThumbDir = await AppConstants.getPublicThumbnailDir();

      await for (final entity in legacyMusicDir.list()) {
        if (entity is! File) continue;
        final path = entity.path;
        if (!_isAudioFile(path)) continue;

        final filename = _basename(path);
        final videoId = _extractVideoId(filename);
        if (videoId == null) continue;

        // Move to public directory
        final newPath = '${publicMusicDir.path}/$filename';
        final newFile = File(newPath);
        if (!await newFile.exists()) {
          await entity.rename(newPath);
        }

        // Move thumbnail if it exists
        final legacyThumbDir = Directory('${extDir.path}/${AppConstants.thumbnailSubDir}');
        final legacyThumbPath = '${legacyThumbDir.path}/$videoId.jpg';
        final legacyThumb = File(legacyThumbPath);
        if (await legacyThumb.exists()) {
          final newThumbPath = '${publicThumbDir.path}/$videoId.jpg';
          final newThumbFile = File(newThumbPath);
          if (!await newThumbFile.exists()) {
            await legacyThumb.rename(newThumbPath);
          }
        }

        // Update DB record if exists, or create new
        final existing = await songDao.getSongByVideoId(videoId);
        final title = _extractTitle(filename, videoId);
        final thumbPath = '${publicThumbDir.path}/$videoId.jpg';

        if (existing != null) {
          // Update paths to point to new public location
          await songDao.saveSong(
            existing.copyWith(
              localAudioPath: newPath,
              localThumbnailPath: thumbPath,
            ),
          );
        } else {
          final song = Song(
            id: '0',
            videoId: videoId,
            title: title,
            artist: null,
            localAudioPath: newPath,
            localThumbnailPath: thumbPath,
            duration: Duration.zero,
            dateAdded: DateTime.now(),
          );
          await songDao.saveSong(song);
        }

        migrated++;
      }

      // Clean up legacy directories after migration
      if (migrated > 0) {
        try {
          await legacyMusicDir.delete(recursive: true);
          final legacyThumbDir = Directory('${extDir.path}/${AppConstants.thumbnailSubDir}');
          if (await legacyThumbDir.exists()) {
            await legacyThumbDir.delete(recursive: true);
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[DirectoryScanner] Legacy migration error: $e');
    }
    return migrated;
  }

  static Future<Directory> getExternalStorageDirectory() async {
    final dirs = await getExternalStorageDirectories();
    if (dirs != null && dirs.isNotEmpty) return dirs.first;
    throw Exception('Cannot access external storage');
  }

  static bool _isAudioFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.m4a') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.opus') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.flac');
  }

  static String _basename(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  /// Extract video ID from filename pattern: [videoId]_[title].[ext]
  static String? _extractVideoId(String filename) {
    final parts = filename.split('_');
    if (parts.isEmpty) return null;
    final candidate = parts.first;
    // YouTube video IDs are 11 chars, alphanumeric + hyphen + underscore
    if (candidate.length == 11 &&
        RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(candidate)) {
      return candidate;
    }
    return null;
  }

  /// Extract title from filename: remove videoId prefix and extension.
  static String _extractTitle(String filename, String videoId) {
    // Remove extension
    final withoutExt = filename.replaceAll(RegExp(r'\.[^.]+$'), '');
    // Remove videoId prefix
    final prefix = '${videoId}_';
    if (withoutExt.startsWith(prefix)) {
      return withoutExt.substring(prefix.length);
    }
    return withoutExt;
  }

  /// Find the thumbnail file for a video ID in the public directory.
  static Future<String> _findThumbnail(String videoId) async {
    try {
      final thumbDir = await AppConstants.getPublicThumbnailDir();
      final thumbFile = File('${thumbDir.path}/$videoId.jpg');
      if (await thumbFile.exists()) return thumbFile.path;
    } catch (_) {}
    return '';
  }
}
