import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mymusic/data/datasources/local/song_dao.dart';
import 'package:mymusic/data/datasources/local/playlist_dao.dart';
import 'package:mymusic/data/datasources/remote/youtube_datasource.dart';
import 'package:mymusic/data/datasources/remote/chaquopy_datasource.dart';
import 'package:mymusic/data/models/song_model.dart';
import 'package:mymusic/data/models/playlist_model.dart';
import 'package:mymusic/data/repositories/downloader_repository_impl.dart';
import 'package:mymusic/data/repositories/library_repository_impl.dart';
import 'package:mymusic/domain/entities/download_task.dart';
import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/domain/entities/playlist.dart';
import 'package:mymusic/domain/repositories/i_downloader_repository.dart';
import 'package:mymusic/domain/repositories/i_library_repository.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mymusic/main.dart';

// ═══════════════════════════════════════════════════════════
// DATA LAYER PROVIDERS
// ═══════════════════════════════════════════════════════════

/// Isar database instance — initialized once at app start.
final isarProvider = FutureProvider<Isar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [SongModelSchema, PlaylistModelSchema],
    directory: dir.path,
  );
  ref.onDispose(() => isar.close());
  return isar;
});

/// YouTube datasource provider.
final youtubeDatasourceProvider = Provider<IYoutubeDatasource>((ref) {
  final ds = YoutubeExplodeDatasource();
  ref.onDispose(() => ds.dispose());
  return ds;
});

/// Chaquopy datasource provider.
final chaquopyDatasourceProvider = Provider<ChaquopyDatasource>((ref) {
  return ChaquopyDatasource();
});

/// Song DAO provider.
final songDaoProvider = Provider<SongDao>((ref) {
  final isar = ref.watch(isarProvider).requireValue;
  return SongDao(isar);
});

/// Playlist DAO provider.
final playlistDaoProvider = Provider<PlaylistDao>((ref) {
  final isar = ref.watch(isarProvider).requireValue;
  return PlaylistDao(isar);
});

// ═══════════════════════════════════════════════════════════
// REPOSITORY PROVIDERS
// ═══════════════════════════════════════════════════════════

/// Downloader repository provider (hybrid: youtube_explode + chaquopy).
final downloaderRepositoryProvider = Provider<IDownloaderRepository>((ref) {
  return DownloaderRepositoryImpl(
    youtubeDatasource: ref.watch(youtubeDatasourceProvider),
    chaquopyDatasource: ref.watch(chaquopyDatasourceProvider),
    songDao: ref.watch(songDaoProvider),
  );
});

/// Library repository provider.
final libraryRepositoryProvider = Provider<ILibraryRepository>((ref) {
  return LibraryRepositoryImpl(
    songDao: ref.watch(songDaoProvider),
    playlistDao: ref.watch(playlistDaoProvider),
  );
});

// ═══════════════════════════════════════════════════════════
// DOWNLOAD PROVIDERS
// ═══════════════════════════════════════════════════════════

/// State for the URL validation / metadata preview on the download screen.
class DownloadFormState {
  final String url;
  final String? videoId;
  final VideoMetadata? metadata;
  final List<AudioStreamInfo>? audioStreams;
  final bool isLoading;
  final String? error;

  const DownloadFormState({
    this.url = '',
    this.videoId,
    this.metadata,
    this.audioStreams,
    this.isLoading = false,
    this.error,
  });

  DownloadFormState copyWith({
    String? url,
    String? videoId,
    VideoMetadata? metadata,
    List<AudioStreamInfo>? audioStreams,
    bool? isLoading,
    String? error,
  }) {
    return DownloadFormState(
      url: url ?? this.url,
      videoId: videoId ?? this.videoId,
      metadata: metadata ?? this.metadata,
      audioStreams: audioStreams ?? this.audioStreams,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Download form notifier — validates URLs, fetches metadata.
class DownloadFormNotifier extends StateNotifier<DownloadFormState> {
  final IDownloaderRepository _repo;

  DownloadFormNotifier(this._repo) : super(const DownloadFormState());

  /// Validate a URL and fetch metadata if valid.
  Future<void> onUrlChanged(String url) async {
    if (url.isEmpty) {
      state = const DownloadFormState();
      return;
    }

    final videoId = _repo.validateYoutubeUrl(url);
    if (videoId == null) {
      state = DownloadFormState(
        url: url,
        error: 'Invalid YouTube URL',
      );
      return;
    }

    state = DownloadFormState(url: url, videoId: videoId, isLoading: true);

    try {
      final metadata = await _repo.fetchVideoMetadata(videoId);
      final streams = await _repo.getAudioStreams(videoId);
      state = state.copyWith(
        metadata: metadata,
        audioStreams: streams,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch video info: $e',
      );
    }
  }

  void clearForm() {
    state = const DownloadFormState();
  }
}

final downloadFormProvider =
    StateNotifierProvider<DownloadFormNotifier, DownloadFormState>((ref) {
  return DownloadFormNotifier(ref.watch(downloaderRepositoryProvider));
});

/// Download queue notifier — manages active and queued downloads.
class DownloadQueueNotifier extends StateNotifier<List<DownloadTask>> {
  final IDownloaderRepository _repo;
  final Ref _ref;
  final Map<String, StreamSubscription<DownloadTask>> _subscriptions = {};

  DownloadQueueNotifier(this._repo, this._ref) : super([]);

  /// Enqueue a download.
  Future<void> enqueue({
    required String videoId,
    required VideoMetadata metadata,
    required AudioStreamInfo stream,
  }) async {
    final downloadStream = _repo.downloadAudio(
      videoId: videoId,
      metadata: metadata,
      stream: stream,
    );

    late StreamSubscription<DownloadTask> sub;
    sub = downloadStream.listen(
      (DownloadTask task) {
        // Update or add task in state
        final idx = state.indexWhere((t) => t.id == task.id);
        if (idx >= 0) {
          final newState = List<DownloadTask>.from(state);
          newState[idx] = task;
          state = newState;
        } else {
          state = [...state, task];
        }

        if (task.status == DownloadStatus.completed) {
          // Cross-screen sync: invalidate library
          _ref.invalidate(libraryProvider);
          sub.cancel();
          _subscriptions.remove(task.id);
        } else if (task.status == DownloadStatus.failed ||
            task.status == DownloadStatus.cancelled) {
          sub.cancel();
          _subscriptions.remove(task.id);
        }
      },
      onError: (e) {
        // Handle stream error
      },
    );
  }

  /// Cancel a download.
  Future<void> cancelDownload(String taskId) async {
    await _repo.cancelDownload(taskId);
    _subscriptions[taskId]?.cancel();
    _subscriptions.remove(taskId);

    final idx = state.indexWhere((t) => t.id == taskId);
    if (idx >= 0) {
      state = [...state]
        ..[idx] = state[idx].copyWith(
          status: DownloadStatus.cancelled,
          errorMessage: 'Cancelled by user',
        );
    }
  }

  /// Remove completed/failed tasks from the list.
  void clearFinished() {
    state = state
        .where((t) =>
            t.status != DownloadStatus.completed &&
            t.status != DownloadStatus.failed &&
            t.status != DownloadStatus.cancelled)
        .toList();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}

final downloadQueueProvider =
    StateNotifierProvider<DownloadQueueNotifier, List<DownloadTask>>((ref) {
  return DownloadQueueNotifier(
    ref.watch(downloaderRepositoryProvider),
    ref,
  );
});

// ═══════════════════════════════════════════════════════════
// LIBRARY PROVIDERS
// ═══════════════════════════════════════════════════════════

/// All songs from the library. Invalidated when a download completes.
final libraryProvider = FutureProvider<List<Song>>((ref) {
  return ref.watch(libraryRepositoryProvider).getAllSongs();
});

/// Reactive song stream from Isar.
final librarySongsStreamProvider = StreamProvider<List<Song>>((ref) {
  return ref.watch(libraryRepositoryProvider).watchAllSongs();
});

/// Search query state.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered search results.
final searchResultsProvider = FutureProvider<List<Song>>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return ref.watch(libraryRepositoryProvider).getAllSongs();
  return ref.watch(libraryRepositoryProvider).searchSongs(query);
});

/// All playlists.
final playlistsProvider = FutureProvider<List<Playlist>>((ref) {
  return ref.watch(libraryRepositoryProvider).getAllPlaylists();
});

/// Songs for a specific playlist.
final playlistSongsProvider = FutureProvider.family<List<Song>, String>((ref, playlistId) {
  return ref.watch(libraryRepositoryProvider).getSongsForPlaylist(playlistId);
});

// ═══════════════════════════════════════════════════════════
// PLAYER PROVIDERS
// ═══════════════════════════════════════════════════════════

/// Player state.
enum SongRepeatMode { off, one, all }

class PlayerState {
  final Song? currentSong;
  final List<Song> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isShuffled;
  final SongRepeatMode repeatMode;
  final Duration position;
  final Duration duration;

  const PlayerState({
    this.currentSong,
    this.queue = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.isShuffled = false,
    this.repeatMode = SongRepeatMode.off,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  PlayerState copyWith({
    Song? currentSong,
    List<Song>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isShuffled,
    SongRepeatMode? repeatMode,
    Duration? position,
    Duration? duration,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isShuffled: isShuffled ?? this.isShuffled,
      repeatMode: repeatMode ?? this.repeatMode,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }

  bool get hasNext => currentIndex < queue.length - 1;
  bool get hasPrevious => currentIndex > 0;
}

/// Player notifier — wraps just_audio + audio_service.
/// This notifier now actually drives the audio handler to play/pause/seek.
class PlayerNotifier extends StateNotifier<PlayerState> {
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<void>? _completionSub;

  PlayerNotifier() : super(const PlayerState()) {
    _initAudioListeners();
    audioHandler.onNext = next;
    audioHandler.onPrevious = previous;
  }

  bool _isAdvancing = false;

  /// Subscribe to the audio player's streams so our state stays in sync.
  void _initAudioListeners() {
    final player = audioHandler.player;

    // Track playback position
    _positionSub = player.positionStream.listen((pos) {
      if (mounted) {
        state = state.copyWith(position: pos);
      }
    });

    // Track total duration
    _durationSub = player.durationStream.listen((dur) {
      if (mounted && dur != null) {
        state = state.copyWith(duration: dur);
      }
    });

    // Track playing state (sync with actual player, e.g. when audio_service controls are used)
    _playingSub = player.playingStream.listen((playing) {
      if (mounted && state.isPlaying != playing) {
        state = state.copyWith(isPlaying: playing);
      }
    });

    // Handle song completion — auto-advance to next track
    _completionSub = player.playerStateStream
        .where((ps) => ps.processingState == ProcessingState.completed)
        .listen((_) async {
      if (mounted && !_isAdvancing) {
        _isAdvancing = true;
        // Small debounce to prevent race condition when state is transitioning
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) next();
        _isAdvancing = false;
      }
    });
  }

  /// Actually load and play a song on the audio player.
  Future<void> _loadAndPlay(Song song) async {
    try {
      await audioHandler.playFromSong(song);
    } catch (e) {
      // If playback fails, log error and update state
      state = state.copyWith(isPlaying: false);
      // ignore: avoid_print
      print('PlayerNotifier: Failed to play "${song.title}": $e');
    }
  }

  /// Play a single song.
  void playSong(Song song) {
    state = state.copyWith(
      currentSong: song,
      queue: [song],
      currentIndex: 0,
      isPlaying: true,
      position: Duration.zero,
      duration: Duration.zero,
    );
    _loadAndPlay(song);
  }

  /// Play a list of songs starting at an index.
  void playQueue(List<Song> songs, int startIndex) {
    if (songs.isEmpty) return;
    final song = songs[startIndex];
    state = state.copyWith(
      currentSong: song,
      queue: songs,
      currentIndex: startIndex,
      isPlaying: true,
      position: Duration.zero,
      duration: Duration.zero,
    );
    _loadAndPlay(song);
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      audioHandler.pause();
    } else {
      audioHandler.play();
    }
    // State will be updated by the playingStream listener
  }

  void pause() {
    audioHandler.pause();
  }

  void resume() {
    audioHandler.play();
  }

  void seek(Duration position) {
    audioHandler.seek(position);
    state = state.copyWith(position: position);
  }

  void updatePosition(Duration position) {
    state = state.copyWith(position: position);
  }

  void updateDuration(Duration duration) {
    state = state.copyWith(duration: duration);
  }

  void next() {
    if (state.repeatMode == SongRepeatMode.one) {
      // Restart current song
      seek(Duration.zero);
      audioHandler.play();
      return;
    }

    if (state.currentIndex < state.queue.length - 1) {
      final newIndex = state.currentIndex + 1;
      final nextSong = state.queue[newIndex];
      state = state.copyWith(
        currentIndex: newIndex,
        currentSong: nextSong,
        position: Duration.zero,
        duration: Duration.zero,
      );
      _loadAndPlay(nextSong);
    } else if (state.repeatMode == SongRepeatMode.all && state.queue.isNotEmpty) {
      final firstSong = state.queue[0];
      state = state.copyWith(
        currentIndex: 0,
        currentSong: firstSong,
        position: Duration.zero,
        duration: Duration.zero,
      );
      _loadAndPlay(firstSong);
    } else {
      // End of queue, no repeat — stop playing
      audioHandler.stop();
      state = state.copyWith(isPlaying: false, position: Duration.zero);
    }
  }

  void previous() {
    // If more than 3 seconds in, restart current song
    if (state.position.inSeconds > 3) {
      seek(Duration.zero);
      audioHandler.play();
      return;
    }

    if (state.currentIndex > 0) {
      final newIndex = state.currentIndex - 1;
      final prevSong = state.queue[newIndex];
      state = state.copyWith(
        currentIndex: newIndex,
        currentSong: prevSong,
        position: Duration.zero,
        duration: Duration.zero,
      );
      _loadAndPlay(prevSong);
    }
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffled: !state.isShuffled);
    if (state.isShuffled && state.queue.length > 1) {
      final current = state.currentSong;
      final shuffled = [...state.queue]..shuffle();
      // Keep current song at position 0
      if (current != null) {
        shuffled.remove(current);
        shuffled.insert(0, current);
      }
      state = state.copyWith(queue: shuffled, currentIndex: 0);
    }
  }

  void cycleRepeatMode() {
    final modes = SongRepeatMode.values;
    final nextIndex = (state.repeatMode.index + 1) % modes.length;
    state = state.copyWith(repeatMode: modes[nextIndex]);
  }

  void addToQueue(Song song) {
    state = state.copyWith(queue: [...state.queue, song]);
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    final newQueue = [...state.queue]..removeAt(index);
    int newIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newIndex--;
    } else if (index == state.currentIndex) {
      // If removing current song, play next
      if (newQueue.isNotEmpty) {
        newIndex = newIndex.clamp(0, newQueue.length - 1);
        final nextSong = newQueue[newIndex];
        state = state.copyWith(
          queue: newQueue,
          currentIndex: newIndex,
          currentSong: nextSong,
        );
        _loadAndPlay(nextSong);
        return;
      }
    }
    state = state.copyWith(queue: newQueue, currentIndex: newIndex);
  }

  void stop() {
    audioHandler.stop();
    state = const PlayerState();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completionSub?.cancel();
    super.dispose();
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});
