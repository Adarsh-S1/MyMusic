/// Extension on [Duration] for display formatting.
extension DurationFormatting on Duration {
  /// Returns "mm:ss" or "h:mm:ss" string.
  String toHumanString() {
    final h = inHours;
    final m = inMinutes.remainder(60);
    final s = inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Extension on [int] for human-readable file sizes.
extension FileSizeFormatting on int {
  String toHumanFileSize() {
    if (this < 1024) return '$this B';
    if (this < 1024 * 1024) return '${(this / 1024).toStringAsFixed(1)} KB';
    if (this < 1024 * 1024 * 1024) {
      return '${(this / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Extension on [String] for filename sanitisation.
extension FilenameSanitise on String {
  /// Strip invalid characters from a filename.
  String toSafeFilename() {
    return replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
