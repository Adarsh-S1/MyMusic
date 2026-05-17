import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Download Quality
          ListTile(
            leading: const Icon(Icons.high_quality),
            title: const Text('Download Quality'),
            subtitle: const Text('192 kbps (default)'),
            onTap: () => _showQualityDialog(context),
          ),
          const Divider(),

          // Download Location
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Download Location'),
            subtitle: const Text('App-scoped storage'),
            onTap: () {},
          ),
          const Divider(),

          // Theme
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: const Text('Dark'),
            onTap: () => _showThemeDialog(context),
          ),
          const Divider(),

          // Metadata Auto-Fetch
          SwitchListTile(
            secondary: const Icon(Icons.auto_fix_high),
            title: const Text('Auto-fetch Metadata'),
            subtitle: const Text('Automatically fetch title & artist from YouTube'),
            value: true,
            onChanged: (_) {},
          ),
          const Divider(),

          // Storage Info
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Storage Used'),
            subtitle: const Text('Calculating...'),
            trailing: TextButton(
              onPressed: () {},
              child: const Text('Clear Cache'),
            ),
          ),
          const Divider(),

          // About
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About YT-Groove'),
            subtitle: const Text('Version 1.0.0'),
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
        children: ['128 kbps', '192 kbps', '320 kbps'].map((q) => SimpleDialogOption(
          child: Text(q),
          onPressed: () => Navigator.pop(ctx),
        )).toList(),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Theme'),
        children: ['System', 'Light', 'Dark'].map((t) => SimpleDialogOption(
          child: Text(t),
          onPressed: () => Navigator.pop(ctx),
        )).toList(),
      ),
    );
  }
}
