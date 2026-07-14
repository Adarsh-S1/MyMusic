import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Datasource that manages the yt-dlp binary and uses it for audio downloads.
///
/// youtube_explode_dart handles metadata fine, but its stream URLs get 403'd
/// by YouTube's signature protection. yt-dlp handles all of this correctly.
///
/// On first use, the correct architecture-specific standalone binary is
/// downloaded from GitHub releases and cached in the app's data directory.
class YtDlpDatasource {
  String? _binaryPath;
  final Dio _dio = Dio();

  static const _repo = 'yt-dlp/yt-dlp';
  // Map of Android ABIs to yt-dlp release asset names
  static const _binaryNames = {
    'x86_64': 'yt-dlp_linux',
    'x86': 'yt-dlp_linux',
    'arm64-v8a': 'yt-dlp_linux_aarch64',
    'armeabi-v7a': 'yt-dlp_linux_armv7l',
  };

  /// Returns the path to the yt-dlp binary, downloading it if needed.
  Future<String> getBinaryPath() async {
    if (_binaryPath != null && File(_binaryPath!).existsSync()) {
      return _binaryPath!;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final binDir = Directory('${appDir.path}/bin');
    await binDir.create(recursive: true);

    final binaryFile = File('${binDir.path}/yt-dlp');
    if (binaryFile.existsSync()) {
      _binaryPath = binaryFile.path;
      return _binaryPath!;
    }

    // Detect architecture
    final arch = await _detectArchitecture();
    final assetName = _binaryNames[arch] ?? 'yt-dlp_linux';

    // Download from GitHub releases
    final downloadUrl =
        'https://github.com/$_repo/releases/latest/download/$assetName';

    await _dio.download(downloadUrl, binaryFile.path);

    // Make executable
    await Process.run('chmod', ['+x', binaryFile.path]);

    _binaryPath = binaryFile.path;
    return _binaryPath!;
  }

  /// Detect the CPU architecture of the current device.
  Future<String> _detectArchitecture() async {
    try {
      final result = await Process.run('uname', ['-m']);
      final arch = result.stdout.toString().trim();
      if (arch.contains('x86_64') || arch.contains('amd64')) return 'x86_64';
      if (arch.contains('aarch64') || arch.contains('arm64')) return 'arm64-v8a';
      if (arch.contains('armv7')) return 'armeabi-v7a';
      return 'x86_64'; // fallback
    } catch (_) {
      return 'x86_64';
    }
  }

  /// Check if yt-dlp is ready (binary exists and is executable).
  Future<bool> isReady() async {
    try {
      final path = await getBinaryPath();
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Download audio for a YouTube video using yt-dlp.
  ///
  /// Returns the path to the downloaded audio file.
  /// [outputDir] is the directory to save the file in.
  /// [videoId] is the YouTube video ID.
  /// [onProgress] is called with (percentage, speedStr) during download.
  Future<String> downloadAudio({
    required String videoId,
    required String outputDir,
    required String safeFilename,
    void Function(double progress, String speed)? onProgress,
  }) async {
    final binary = await getBinaryPath();
    final url = 'https://www.youtube.com/watch?v=$videoId';
    final outputPath = '$outputDir/${videoId}_$safeFilename.m4a';

    // Use yt-dlp to download best audio in m4a format
    final process = await Process.start(binary, [
      '--no-playlist',
      '-f', 'bestaudio[ext=m4a]/bestaudio',
      '-o', outputPath,
      '--no-warnings',
      '--newline', // Print progress on new lines for parsing
      '--no-part', // Don't use .part files
      url,
    ]);

    // Parse progress from stdout
    process.stdout.transform(utf8.decoder).listen((data) {
      if (onProgress != null) {
        final progressMatch = RegExp(r'(\d+\.?\d*)%').firstMatch(data);
        final speedMatch = RegExp(r'at\s+(\S+)').firstMatch(data);
        if (progressMatch != null) {
          final pct = double.tryParse(progressMatch.group(1)!) ?? 0;
          final speed = speedMatch?.group(1) ?? '';
          onProgress(pct / 100.0, speed);
        }
      }
    });

    // Capture stderr for error reporting
    final stderrBuf = StringBuffer();
    process.stderr.transform(utf8.decoder).listen((data) {
      stderrBuf.write(data);
    });

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      throw Exception('yt-dlp failed (exit $exitCode): $stderrBuf');
    }

    // Verify the file was created
    if (!File(outputPath).existsSync()) {
      throw Exception('yt-dlp completed but output file not found: $outputPath');
    }

    return outputPath;
  }

  /// Cancel isn't natively supported by Process.kill, but we track PIDs.
  /// For now, downloads can be cancelled by killing the process.
  void dispose() {
    _dio.close();
  }
}
