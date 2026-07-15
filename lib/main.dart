import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_handler/share_handler.dart';

import 'package:mymusic/presentation/providers/providers.dart';
import 'package:mymusic/presentation/screens/home/home_screen.dart';
import 'package:mymusic/presentation/screens/downloader/downloader_screen.dart';
import 'package:mymusic/presentation/screens/library/library_screen.dart';
import 'package:mymusic/presentation/screens/now_playing/now_playing_screen.dart';
import 'package:mymusic/presentation/screens/settings/settings_screen.dart';
import 'package:mymusic/presentation/widgets/mini_player.dart';
import 'package:mymusic/domain/entities/song.dart';

// ═══════════════════════════════════════════════════════════
// Audio Handler — bridges just_audio + audio_service
// ═══════════════════════════════════════════════════════════

class YtGrooveAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  YtGrooveAudioHandler() {
    // Broadcast playback state changes
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });
  }

  AudioPlayer get player => _player;

  Future<void> playFromSong(Song song) async {
    final audioFile = File(song.localAudioPath);
    final thumbFile = File(song.localThumbnailPath);
    
    print('[AudioHandler] playFromSong: "${song.title}"');
    print('[AudioHandler] Audio path: ${song.localAudioPath}');
    print('[AudioHandler] Audio file exists: ${audioFile.existsSync()}');
    if (audioFile.existsSync()) {
      print('[AudioHandler] Audio file size: ${audioFile.lengthSync()} bytes');
    }
    
    if (!audioFile.existsSync()) {
      throw Exception('Audio file not found: ${song.localAudioPath}');
    }
    
    mediaItem.add(MediaItem(
      id: song.videoId,
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      duration: song.duration,
      artUri: thumbFile.existsSync() ? Uri.file(song.localThumbnailPath) : null,
    ));
    await _player.setFilePath(song.localAudioPath);
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> skipToNext() async {
    // Handled by PlayerNotifier
  }

  @override
  Future<void> skipToPrevious() async {
    // Handled by PlayerNotifier
  }
}

late YtGrooveAudioHandler audioHandler;

// ═══════════════════════════════════════════════════════════
// Main Entry Point
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize audio service with our handler
  audioHandler = await AudioService.init(
    builder: () => YtGrooveAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.mymusic.channel.audio',
      androidNotificationChannelName: 'YT-Groove Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    const ProviderScope(
      child: YtGrooveApp(),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// Router Configuration
// ═══════════════════════════════════════════════════════════

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/download',
          pageBuilder: (context, state) => const NoTransitionPage(child: DownloaderScreen()),
        ),
        GoRoute(
          path: '/library',
          pageBuilder: (context, state) => const NoTransitionPage(child: LibraryScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),
    // Full-screen modal route for Now Playing
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/now-playing',
      builder: (context, state) => const NowPlayingScreen(),
    ),
  ],
);

// ═══════════════════════════════════════════════════════════
// App Shell — Scaffold with BottomNavBar + MiniPlayer
// ═══════════════════════════════════════════════════════════

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StreamSubscription<SharedMedia>? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initShareHandler();
  }

  Future<void> _initShareHandler() async {
    final handler = ShareHandlerPlatform.instance;

    // 1. Get media shared while the app was closed
    try {
      final initialMedia = await handler.getInitialSharedMedia();
      if (initialMedia != null) {
        _handleSharedText(initialMedia);
      }
    } catch (e) {
      debugPrint("ShareHandler initial error: $e");
    }

    // 2. Listen for media shared while the app is running
    _intentDataStreamSubscription = handler.sharedMediaStream.listen((SharedMedia media) {
      _handleSharedText(media);
    }, onError: (err) {
      debugPrint("ShareHandler stream error: $err");
    });
  }

  void _handleSharedText(SharedMedia media) {
    final text = media.content;
    if (text != null && text.isNotEmpty) {
      // Just check if it has YouTube URL pattern or just send it directly
      ref.read(downloadFormProvider.notifier).onUrlChanged(text);
      context.go('/download');
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/download')) return 1;
    if (location.startsWith('/library')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              switch (index) {
                case 0: context.go('/home');
                case 1: context.go('/download');
                case 2: context.go('/library');
                case 3: context.go('/settings');
              }
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: 'Download'),
              NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'Library'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// App Widget
// ═══════════════════════════════════════════════════════════

class YtGrooveApp extends ConsumerWidget {
  const YtGrooveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Wait for Isar to initialize
    final isarAsync = ref.watch(isarProvider);

    return isarAsync.when(
      data: (_) => MaterialApp.router(
        title: 'YT-Groove',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C5CE7),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        routerConfig: _router,
      ),
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C5CE7), brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading YT-Groove...'),
              ],
            ),
          ),
        ),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Error initializing: $e'))),
      ),
    );
  }
}
