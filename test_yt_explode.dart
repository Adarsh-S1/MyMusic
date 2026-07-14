// Standalone test: youtube_explode_dart for metadata + yt-dlp for download
// Run with: dart run test_yt_explode.dart
//
// This tests the HYBRID approach:
//   1. youtube_explode_dart → metadata (title, author, duration, thumbnail)
//   2. yt-dlp CLI            → actual audio file download (handles 403s)

import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const testVideoUrl = 'https://youtu.be/kzpS-A3QJqE';
const ytDlpPath = '/home/adarsh/.local/bin/yt-dlp';

void main() async {
  final yt = YoutubeExplode();

  try {
    print('═══════════════════════════════════════════════════');
    print('  Hybrid Test: youtube_explode + yt-dlp');
    print('═══════════════════════════════════════════════════\n');

    // ─── Step 1: Metadata via youtube_explode_dart ────────
    print('── Step 1: Fetching metadata via youtube_explode_dart...');
    final videoId = VideoId(testVideoUrl);
    final video = await yt.videos.get(videoId);
    print('   Title    : ${video.title}');
    print('   Author   : ${video.author}');
    print('   Duration : ${video.duration}');
    print('   Thumbnail: ${video.thumbnails.highResUrl}');
    print('✅ Metadata OK\n');

    // ─── Step 2: Download audio via yt-dlp ────────────────
    print('── Step 2: Downloading audio via yt-dlp...');
    final outputPath = 'test_audio_${videoId.value}.m4a';

    final result = await Process.run(ytDlpPath, [
      '--no-playlist',
      '-f', 'bestaudio[ext=m4a]/bestaudio',
      '-o', outputPath,
      '--no-warnings',
      '--progress',
      testVideoUrl,
    ]);

    print('   stdout: ${result.stdout}');
    if (result.stderr.toString().isNotEmpty) {
      print('   stderr: ${result.stderr}');
    }
    print('   Exit code: ${result.exitCode}');

    final file = File(outputPath);
    if (file.existsSync()) {
      final sizeKB = (file.lengthSync() / 1024).toStringAsFixed(1);
      print('   File size: $sizeKB KB');
      print('✅ Download successful!\n');

      // Clean up
      await file.delete();
      print('   (temp file cleaned up)\n');

      print('═══════════════════════════════════════════════════');
      print('  ALL TESTS PASSED ✅');
      print('');
      print('  Strategy for the app:');
      print('  • youtube_explode_dart → metadata + thumbnail');
      print('  • yt-dlp (Process.run) → audio download');
      print('  • This bypasses all 403/signature issues.');
      print('═══════════════════════════════════════════════════');
    } else {
      print('❌ Download failed — file not created');
    }
  } catch (e, st) {
    print('\n❌ Error: $e\n$st');
  } finally {
    yt.close();
  }
}
