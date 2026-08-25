import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_handler/share_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mymusic/presentation/providers/providers.dart';
import 'package:mymusic/presentation/screens/home/home_screen.dart';
import 'package:mymusic/presentation/screens/downloader/downloader_screen.dart';
import 'package:mymusic/presentation/screens/library/library_screen.dart';
import 'package:mymusic/presentation/screens/now_playing/now_playing_screen.dart';
import 'package:mymusic/presentation/screens/settings/settings_screen.dart';
import 'package:mymusic/presentation/screens/library/playlist_detail_screen.dart';
import 'package:mymusic/presentation/widgets/mini_player.dart';
import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/data/datasources/local/song_dao.dart';
import 'package:mymusic/data/datasources/local/playlist_dao.dart';
import 'package:mymusic/data/models/song_model.dart';
import 'package:mymusic/data/models/playlist_model.dart';
import 'package:mymusic/core/utils/directory_scanner.dart';
import 'package:mymusic/core/utils/permission_helper.dart';

// ═══════════════════════════════════════════════════════════
// Audio Handler — bridges just_audio + audio_service
// Uses ConcatenatingAudioSource for native queue management.
// ═══════════════════════════════════════════════════════════

class YtGrooveAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
    children: [],
  );

  final SongDao _songDao;
  final PlaylistDao _playlistDao;

  // Android Auto media browser IDs
  static const _allSongsId = 'all_songs';
  static const _recentId = 'recent';
  static const _playlistsFolderId = 'playlists';
  static const _playlistPrefix = 'playlist_';

  // The current Song list mirroring _playlist's children.
  // Used to map currentIndex → Song entity.
  List<Song> _songQueue = [];

  YtGrooveAudioHandler({
    required SongDao songDao,
    required PlaylistDao playlistDao,
  }) : _songDao = songDao,
       _playlistDao = playlistDao {
    // Pipe just_audio events directly to audio_service playbackState.
    // This is the officially recommended pattern — no manual .listen() + .add().
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // When just_audio changes the current item (on skip, auto-advance, etc.),
    // update the mediaItem stream so Android Auto / notification shows the
    // correct track info.
    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _songQueue.length) {
        mediaItem.add(_songToMediaItem(_songQueue[index]));
      }
    });
  }

  AudioPlayer get player => _player;

  /// The current song queue (read-only for PlayerNotifier).
  List<Song> get songQueue => _songQueue;

  // ═══════════════════════════════════════════════════════════
  // Queue Management
  // ═══════════════════════════════════════════════════════════

  /// Load a queue of songs into just_audio's ConcatenatingAudioSource
  /// and start from [startIndex]. This is the ONLY place we call
  /// _player.setAudioSource(), so all track transitions after this
  /// are handled natively by just_audio (no setFilePath calls).
  Future<void> loadQueue(List<Song> songs, int startIndex) async {
    _songQueue = List.unmodifiable(songs);

    // Broadcast the queue to audio_service (Android Auto / notification).
    queue.add(songs.map(_songToMediaItem).toList());

    // Clear and rebuild the ConcatenatingAudioSource.
    await _playlist.clear();
    await _playlist.addAll(
      songs
          .map(
            (s) => AudioSource.file(s.localAudioPath, tag: _songToMediaItem(s)),
          )
          .toList(),
    );

    // Set the audio source. just_audio now owns the entire playlist.
    await _player.setAudioSource(
      _playlist,
      initialIndex: startIndex,
      initialPosition: Duration.zero,
    );

    // Immediately broadcast the current media item.
    if (startIndex >= 0 && startIndex < songs.length) {
      mediaItem.add(_songToMediaItem(songs[startIndex]));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Android Auto — Media Browsing
  // ═══════════════════════════════════════════════════════════

  /// Converts a Song entity to an audio_service MediaItem.
  MediaItem _songToMediaItem(Song song) {
    final thumbFile = File(song.localThumbnailPath);
    return MediaItem(
      id: song.videoId,
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      duration: song.duration,
      artUri: song.localThumbnailPath.isNotEmpty && thumbFile.existsSync()
          ? Uri.file(song.localThumbnailPath)
          : null,
    );
  }

  /// Called by Android Auto to browse the media library.
  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    switch (parentMediaId) {
      case AudioService.browsableRootId:
        return [
          const MediaItem(id: _allSongsId, title: 'All Songs', playable: false),
          const MediaItem(
            id: _recentId,
            title: 'Recently Added',
            playable: false,
          ),
          const MediaItem(
            id: _playlistsFolderId,
            title: 'Playlists',
            playable: false,
          ),
        ];

      case _allSongsId:
        final songs = await _songDao.getAllSongs();
        return songs.map(_songToMediaItem).toList();

      case _recentId:
        final songs = await _songDao.getAllSongs();
        return songs.take(20).map(_songToMediaItem).toList();

      case _playlistsFolderId:
        final playlists = await _playlistDao.getAllPlaylists();
        return playlists
            .map(
              (p) => MediaItem(
                id: '$_playlistPrefix${p.id}',
                title: p.name,
                playable: false,
              ),
            )
            .toList();

      default:
        if (parentMediaId.startsWith(_playlistPrefix)) {
          final playlistId = parentMediaId.substring(_playlistPrefix.length);
          final playlist = await _playlistDao.getPlaylistById(
            int.parse(playlistId),
          );
          if (playlist == null) return [];

          final songs = <Song>[];
          for (final videoId in playlist.songVideoIds) {
            final song = await _songDao.getSongByVideoId(videoId);
            if (song != null) songs.add(song);
          }
          return songs.map(_songToMediaItem).toList();
        }
        return [];
    }
  }

  /// Called by Android Auto when the user taps a song to play it.
  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final song = await _songDao.getSongByVideoId(mediaId);
    if (song == null) return;

    // Build queue context: if the current queue contains this song, use it.
    // Otherwise fall back to all songs.
    List<Song> queueSongs;
    if (_songQueue.any((s) => s.videoId == mediaId)) {
      queueSongs = List.from(_songQueue);
    } else {
      queueSongs = await _songDao.getAllSongs();
    }

    int startIndex = queueSongs.indexWhere((s) => s.videoId == mediaId);
    if (startIndex == -1) startIndex = 0;

    await loadQueue(queueSongs, startIndex);
    await _player.play();
  }

  /// Called by Android Auto when the user selects a specific queue item.
  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _songQueue.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  // ═══════════════════════════════════════════════════════════
  // Core Playback — all delegate to just_audio
  // ═══════════════════════════════════════════════════════════

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  /// Set loop mode on the underlying player.
  void setLoopMode(LoopMode mode) => _player.setLoopMode(mode);

  /// Set shuffle mode on the underlying player.
  void setShuffleModeEnabled(bool enabled) =>
      _player.setShuffleModeEnabled(enabled);

  // ═══════════════════════════════════════════════════════════
  // State Transform — maps just_audio events to audio_service
  // ═══════════════════════════════════════════════════════════

  /// Pure function: converts a just_audio PlaybackEvent into an
  /// audio_service PlaybackState. Used by .pipe(playbackState).
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
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
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}

late YtGrooveAudioHandler audioHandler;

// Global Isar instance — opened once in main(), shared with providers.
late Isar globalIsar;

// ═══════════════════════════════════════════════════════════
// Main Entry Point
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open Isar FIRST so the audio handler can access it for Android Auto browsing.
  final dir = await getApplicationDocumentsDirectory();
  globalIsar = await Isar.open([
    SongModelSchema,
    PlaylistModelSchema,
  ], directory: dir.path);

  final songDao = SongDao(globalIsar);
  final playlistDao = PlaylistDao(globalIsar);

  // Scan public storage to restore songs from previous installs
  try {
    await PermissionHelper.requestManageStorage();
    final restored = await DirectoryScanner.scanAndRestore(songDao);
    if (restored > 0) {
      debugPrint('[Startup] Restored $restored songs from public storage');
    }
  } catch (e) {
    debugPrint('[Startup] Directory scan failed: $e');
  }

  // Initialize audio service with our handler
  audioHandler = await AudioService.init(
    builder: () =>
        YtGrooveAudioHandler(songDao: songDao, playlistDao: playlistDao),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.mymusic.channel.audio',
      androidNotificationChannelName: 'MyMusic Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(const ProviderScope(child: YtGrooveApp()));
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
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/download',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DownloaderScreen()),
        ),
        GoRoute(
          path: '/library',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LibraryScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),
    // Full-screen modal route for Now Playing
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/now-playing',
      builder: (context, state) => const NowPlayingScreen(),
    ),
    // Playlist detail screen
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/playlist/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final name = state.extra as String? ?? 'Playlist';
        return PlaylistDetailScreen(playlistId: id, playlistName: name);
      },
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
    _requestPermissions();
    _initShareHandler();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
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
    _intentDataStreamSubscription = handler.sharedMediaStream.listen(
      (SharedMedia media) {
        _handleSharedText(media);
      },
      onError: (err) {
        debugPrint("ShareHandler stream error: $err");
      },
    );
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
    if (location.startsWith('/library')) return 1;
    if (location.startsWith('/download')) return 2;
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
                case 0:
                  context.go('/home');
                case 1:
                  context.go('/library');
                case 2:
                  context.go('/download');
                case 3:
                  context.go('/settings');
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.download_outlined),
                selectedIcon: Icon(Icons.download),
                label: 'Download',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
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
        title: 'My Music',
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
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C5CE7),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading My Music...'),
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
