import 'dart:io';
import 'package:flutter/material.dart';

/// A reusable widget that displays a song's thumbnail image,
/// falling back to a music note icon if the file doesn't exist.
class SongThumbnail extends StatelessWidget {
  final String thumbnailPath;
  final double width;
  final double height;
  final double borderRadius;
  final double iconSize;

  const SongThumbnail({
    super.key,
    required this.thumbnailPath,
    this.width = 48,
    this.height = 48,
    this.borderRadius = 8,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(thumbnailPath);
    final exists = thumbnailPath.isNotEmpty && file.existsSync();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: exists
          ? Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.music_note,
                size: iconSize,
                color: theme.colorScheme.primary,
              ),
            )
          : Icon(
              Icons.music_note,
              size: iconSize,
              color: theme.colorScheme.primary,
            ),
    );
  }
}
