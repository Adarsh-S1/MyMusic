import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusic/presentation/providers/providers.dart';

/// Settings screen.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// null = not checked, true = working, false = failed
  bool? _ytdlpStatus;
  bool _isChecking = false;
  String? _ytdlpError;

  Future<void> _checkYtdlp() async {
    setState(() {
      _isChecking = true;
      _ytdlpStatus = null;
      _ytdlpError = null;
    });

    try {
      // Fetch metadata for a well-known, stable YouTube video (Rick Astley)
      // This verifies the full pipeline: Chaquopy → Python → yt-dlp → YouTube
      final datasource = ref.read(chaquopyDatasourceProvider);
      final result = await datasource.fetchVideoMetadata('dQw4w9WgXcQ');
      final title = result['title'] as String? ?? '';

      if (title.isNotEmpty) {
        setState(() {
          _ytdlpStatus = true;
          _isChecking = false;
        });
      } else {
        throw Exception('Empty response from yt-dlp');
      }
    } catch (e) {
      setState(() {
        _ytdlpStatus = false;
        _isChecking = false;
        _ytdlpError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Download Quality
          // ListTile(
          //   leading: const Icon(Icons.high_quality),
          //   title: const Text('Download Quality'),
          //   subtitle: const Text('192 kbps (default)'),
          //   onTap: () => _showQualityDialog(context),
          // ),
          // const Divider(),

          // Download Location
          // ListTile(
          //   leading: const Icon(Icons.folder),
          //   title: const Text('Download Location'),
          //   subtitle: const Text('App-scoped storage'),
          //   onTap: () {},
          // ),
          // const Divider(),

          // Theme
          // ListTile(
          //   leading: const Icon(Icons.palette),
          //   title: const Text('Theme'),
          //   subtitle: const Text('Dark'),
          //   onTap: () => _showThemeDialog(context),
          // ),
          // const Divider(),

          // Metadata Auto-Fetch
          // SwitchListTile(
          //   secondary: const Icon(Icons.auto_fix_high),
          //   title: const Text('Auto-fetch Metadata'),
          //   subtitle: const Text(
          //     'Automatically fetch title & artist from YouTube',
          //   ),
          //   value: true,
          //   onChanged: (_) {},
          // ),
          const Divider(),

          // yt-dlp Checker
          ListTile(
            leading: Icon(
              _isChecking
                  ? Icons.hourglass_top
                  : _ytdlpStatus == true
                  ? Icons.check_circle
                  : _ytdlpStatus == false
                  ? Icons.error
                  : Icons.build_circle_outlined,
              color: _isChecking
                  ? theme.colorScheme.onSurfaceVariant
                  : _ytdlpStatus == true
                  ? Colors.green
                  : _ytdlpStatus == false
                  ? theme.colorScheme.error
                  : null,
            ),
            title: const Text('yt-dlp Checker'),
            subtitle: Text(
              _isChecking
                  ? 'Checking...'
                  : _ytdlpStatus == true
                  ? 'yt-dlp is working correctly'
                  : _ytdlpStatus == false
                  ? _ytdlpError ?? 'yt-dlp check failed'
                  : 'Tap to verify yt-dlp is working',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _isChecking
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            onTap: _isChecking ? null : _checkYtdlp,
          ),
          const Divider(),

          // Storage Info
          // ListTile(
          //   leading: const Icon(Icons.storage),
          //   title: const Text('Storage Used'),
          //   subtitle: const Text('Calculating...'),
          //   trailing: TextButton(
          //     onPressed: () {},
          //     child: const Text('Clear Cache'),
          //   ),
          // ),
          // const Divider(),

          // About
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About MyMusic'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showQualityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Download Quality'),
        children: ['128 kbps', '192 kbps', '320 kbps']
            .map(
              (q) => SimpleDialogOption(
                child: Text(q),
                onPressed: () => Navigator.pop(ctx),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Theme'),
        children: ['System', 'Light', 'Dark']
            .map(
              (t) => SimpleDialogOption(
                child: Text(t),
                onPressed: () => Navigator.pop(ctx),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About MyMusic'),
        content: const Text('Created by Adarsh'),
        // actions: [
        //   TextButton(
        //     onPressed: () => Navigator.pop(ctx),
        //     child: const Text('OK'),
        //   ),
        // ],
      ),
    );
  }
}
