# 🎵 YT-Groove — Flutter YouTube-to-MP3 App
## `objectives.md` — Production Architecture & Feature Blueprint

> **Version**: 1.0.0 | **Platform**: Android | **Framework**: Flutter 3.x | **State**: Riverpod 2.x

---

## Table of Contents

1. [Project Overview & Objectives](#1-project-overview--objectives)
2. [Architecture & State Management Strategy](#2-architecture--state-management-strategy)
3. [Core Feature Requirements](#3-core-feature-requirements)
4. [App Workflow & Screen Architecture (UI/UX)](#4-app-workflow--screen-architecture-uiux)
5. [Recommended Package Ecosystem](#5-recommended-package-ecosystem)
6. [Critical Technical Considerations & Android Edge Cases](#6-critical-technical-considerations--android-edge-cases)

---

## 1. Project Overview & Objectives

### 1.1 App Summary

**YT-Groove** is a native Android application built with Flutter that enables users to download audio tracks from YouTube videos as high-quality MP3 files, manage those files in a local music library, and play them fully offline — including from the lock screen — without any streaming dependency after download.

The app addresses a core user need: building a personal, offline-first music collection from YouTube content without relying on third-party subscription services.

### 1.2 Target Platform

| Attribute        | Value                                         |
|------------------|-----------------------------------------------|
| **Framework**    | Flutter 3.x (Dart 3.x)                        |
| **Platform**     | Android (API 26 / Android 8.0 minimum target) |
| **Architecture** | Clean Architecture + Riverpod                 |
| **Build**        | Release APK / AAB via `flutter build apk`     |

> **Minimum SDK**: API 26 (Android 8.0) to support `WorkManager` background tasks and modern audio focus APIs.
> **Target SDK**: API 35 (Android 15) to comply with current Play Store policies and scoped storage.

### 1.3 High-Level Goals

- **Goal 1 — Frictionless Downloading**: A user must be able to paste a YouTube URL and receive a downloaded MP3 with minimal taps, with full download progress visibility.
- **Goal 2 — Offline-First Library**: All downloaded audio is stored locally and accessible without any internet connection.
- **Goal 3 — Professional Playback Experience**: Background playback, lock-screen media controls, and a Now Playing UI that rivals native music apps.
- **Goal 4 — Data Integrity & Persistence**: Song metadata (title, artist, thumbnail, file path, duration) persists across sessions using a local database.
- **Goal 5 — Resilience**: The app gracefully handles YouTube extraction failures, storage permission edge cases, and Android background execution restrictions.

---

## 2. Architecture & State Management Strategy

### 2.1 Clean Architecture Layers

The project follows a strict **3-layer Clean Architecture** to decouple concerns, maximize testability, and isolate the volatile YouTube extraction logic from the stable core domain.

```
lib/
├── core/                          # Cross-cutting utilities
│   ├── constants/
│   ├── errors/                    # Failure sealed classes
│   ├── extensions/
│   └── utils/
│
├── data/                          # Data Layer
│   ├── datasources/
│   │   ├── remote/                # YouTube extraction API calls
│   │   │   └── youtube_datasource.dart
│   │   └── local/                 # Isar DB + file system access
│   │       ├── song_dao.dart
│   │       └── playlist_dao.dart
│   ├── models/                    # Raw data transfer objects (DTOs)
│   │   ├── song_model.dart
│   │   └── download_task_model.dart
│   └── repositories/              # Concrete implementations
│       ├── downloader_repository_impl.dart
│       └── library_repository_impl.dart
│
├── domain/                        # Domain Layer (pure Dart, zero Flutter deps)
│   ├── entities/
│   │   ├── song.dart              # Immutable Song entity
│   │   ├── playlist.dart
│   │   └── download_task.dart
│   ├── repositories/              # Abstract contracts (interfaces)
│   │   ├── i_downloader_repository.dart
│   │   └── i_library_repository.dart
│   └── usecases/
│       ├── download/
│       │   ├── validate_youtube_url_usecase.dart
│       │   ├── extract_audio_stream_usecase.dart
│       │   └── start_download_usecase.dart
│       ├── library/
│       │   ├── get_all_songs_usecase.dart
│       │   ├── delete_song_usecase.dart
│       │   └── search_songs_usecase.dart
│       └── player/
│           ├── play_song_usecase.dart
│           └── manage_queue_usecase.dart
│
└── presentation/                  # Presentation Layer
    ├── providers/                 # All Riverpod providers live here
    │   ├── download_provider.dart
    │   ├── library_provider.dart
    │   └── player_provider.dart
    ├── screens/
    │   ├── home/
    │   ├── downloader/
    │   ├── library/
    │   └── now_playing/
    └── widgets/                   # Shared/reusable widgets
```

---

### 2.2 Riverpod State Management Strategy

Riverpod 2.x with **code generation** (`@riverpod`) is the chosen state solution. It provides compile-safe providers, automatic dependency injection, and first-class support for async state — critical for download pipelines.

#### 2.2.1 Provider Hierarchy & Dependency Graph

```
┌─────────────────────────────────────────────────────────┐
│                   PRESENTATION LAYER                    │
│                                                         │
│  downloadQueueProvider        libraryProvider           │
│  (StateNotifier<List<Task>>) (AsyncNotifier<List<Song>>)│
│          │                          ▲                   │
│          │ watches                  │ invalidates on    │
│          ▼                          │ download complete │
│  activeDownloadProvider      playerProvider             │
│  (StreamProvider<Progress>)  (StateNotifier<PlayerState>)│
└──────────────────┬──────────────────┬───────────────────┘
                   │                  │
┌──────────────────▼──────────────────▼───────────────────┐
│                    DOMAIN LAYER                         │
│                                                         │
│  downloaderRepositoryProvider    libraryRepositoryProv. │
│  (Provider<IDownloaderRepo>)     (Provider<ILibraryRepo>)│
└──────────────────┬──────────────────┬───────────────────┘
                   │                  │
┌──────────────────▼──────────────────▼───────────────────┐
│                     DATA LAYER                          │
│                                                         │
│  youtubeDatasourceProvider       isarDatabaseProvider   │
│  (Provider<YoutubeDatasource>)   (Provider<Isar>)       │
└─────────────────────────────────────────────────────────┘
```

#### 2.2.2 Key Provider Implementations

**Download Queue Provider** — Manages active and queued downloads:

```dart
// presentation/providers/download_provider.dart

@riverpod
class DownloadQueue extends _$DownloadQueue {
  @override
  List<DownloadTask> build() => [];

  Future<void> enqueue(String youtubeUrl) async {
    final task = DownloadTask.pending(url: youtubeUrl);
    state = [...state, task];

    final result = await ref
        .read(startDownloadUsecaseProvider)
        .execute(task);

    result.fold(
      (failure) => _updateTaskState(task.id, DownloadStatus.failed),
      (completedSong) {
        _updateTaskState(task.id, DownloadStatus.completed);
        // Cross-screen state sync: invalidate library so UI refreshes instantly
        ref.invalidate(libraryProvider);
      },
    );
  }

  Stream<DownloadProgress> watchProgress(String taskId) {
    return ref.read(downloaderRepositoryProvider)
        .watchDownloadProgress(taskId);
  }
}
```

**Library Provider** — Reactive song list that rebuilds on download completion:

```dart
@riverpod
class Library extends _$Library {
  @override
  Future<List<Song>> build() async {
    return ref.watch(getAllSongsUsecaseProvider).execute();
  }

  Future<void> deleteSong(String songId) async {
    await ref.read(deleteSongUsecaseProvider).execute(songId);
    ref.invalidateSelf(); // Triggers UI rebuild
  }
}
```

**Player Provider** — Wraps `just_audio` + `audio_service` state:

```dart
@riverpod
class Player extends _$Player {
  @override
  PlayerState build() => PlayerState.idle();

  Future<void> playSong(Song song) async { ... }
  void togglePlayPause() { ... }
  void seek(Duration position) { ... }
  void setShuffleMode(bool enabled) { ... }
  void cycleRepeatMode() { ... }
}
```

#### 2.2.3 Cross-Screen Synchronisation Pattern

The critical UX requirement — *"library updates instantly when a background download completes"* — is solved by the `ref.invalidate()` cascade:

```
Download completes in DownloadQueueNotifier
        │
        ▼
ref.invalidate(libraryProvider)          ← triggers library re-fetch
        │
        ▼
libraryProvider rebuilds (AsyncValue)    ← fetches fresh songs from Isar DB
        │
        ▼
LibraryScreen widget rebuilds            ← new song appears in list
        │
        ▼
MiniPlayer badge updates if needed       ← via shared playerProvider
```

No manual event buses or streams between screens are required — Riverpod's dependency graph handles propagation automatically.

---

## 3. Core Feature Requirements

### 3.1 Downloader Module

#### 3.1.1 URL Validation

| Rule                          | Behavior                                             |
|-------------------------------|------------------------------------------------------|
| Empty string                  | Show inline validation error, disable download button|
| Non-URL string                | `"Invalid URL format"` error message                 |
| Valid URL but not YouTube     | `"Only YouTube URLs are supported"` error            |
| YouTube Shorts URL            | Normalise to standard watch URL and proceed          |
| YouTube Playlist URL          | Parse individual video IDs; batch-enqueue all        |
| Private/Unavailable video     | Show `"Video unavailable or private"` error          |

**Supported URL Formats to Accept:**
```
https://www.youtube.com/watch?v=VIDEO_ID
https://youtu.be/VIDEO_ID
https://youtube.com/shorts/VIDEO_ID
https://m.youtube.com/watch?v=VIDEO_ID
```

#### 3.1.2 Audio Stream Extraction Flow

```
User pastes URL
      │
      ▼
[1] URL Validation (regex + format check)
      │
      ▼
[2] Fetch video metadata (title, thumbnail, duration, uploader)
      │
      ▼
[3] Extract available audio streams from video manifest
      │
      ▼
[4] Select highest-quality audio-only stream
    Priority: Opus/WebM 160kbps → AAC/MP4 128kbps → Any available
      │
      ▼
[5] Begin chunked download with progress events
      │
      ▼
[6] Post-download: convert/remux to MP3 using ffmpeg_kit_flutter
      │
      ▼
[7] Embed ID3 tags (title, artist/uploader, thumbnail as album art)
      │
      ▼
[8] Save to app-scoped directory or user's Music folder
      │
      ▼
[9] Write song metadata record to Isar database
      │
      ▼
[10] Invalidate libraryProvider → song appears in library
```

#### 3.1.3 Download Progress Tracking

Expose a `Stream<DownloadProgress>` from the repository:

```dart
class DownloadProgress {
  final String taskId;
  final double percentage;        // 0.0 → 1.0
  final double speedBytesPerSec;  // Bytes/sec for display
  final int downloadedBytes;
  final int totalBytes;
  final DownloadStatus status;    // pending | downloading | processing | completed | failed
  final String? errorMessage;
}
```

UI should display:
- Linear progress bar with percentage label
- Human-readable speed (`1.2 MB/s`)
- Estimated time remaining (ETA)
- Cancel button (with partial file cleanup on cancel)
- Retry button on failure (with exponential back-off for network errors)

#### 3.1.4 File Storage Strategy

```
/storage/emulated/0/Android/data/<package_name>/files/Music/
    └── yt-groove/
        ├── audio/
        │   ├── {videoId}_title_sanitized.mp3
        │   └── ...
        └── thumbnails/
            ├── {videoId}.jpg
            └── ...
```

- Use `getExternalFilesDir(Environment.DIRECTORY_MUSIC)` via `path_provider` — **no broad storage permission required** on Android 10+.
- File name sanitisation: strip invalid characters (`/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|`) from video titles.
- Collision handling: append `_{index}` suffix if file already exists.

---

### 3.2 Music Player Module

#### 3.2.1 Playback Architecture

The player is built on `just_audio` for audio decoding and `audio_service` to integrate with the Android MediaSession API. These two packages are designed to work together and handle all background/foreground service lifecycle automatically.

```
┌──────────────────────────────────────────────┐
│              audio_service                    │
│  (Android Foreground Service + MediaSession) │
│                    │                          │
│            ┌───────▼───────┐                  │
│            │   just_audio  │                  │
│            │  AudioPlayer  │                  │
│            └───────────────┘                  │
└──────────────────────────────────────────────┘
          ▲                    ▲
          │ commands           │ state stream
          │                    │
┌─────────┴────────────────────┴──────────────┐
│             playerProvider (Riverpod)        │
│          (Bridges audio_service ↔ UI)        │
└─────────────────────────────────────────────┘
          ▲
          │
┌─────────┴─────────────────────────────────────┐
│   NowPlayingScreen / MiniPlayer / LibraryTile  │
└────────────────────────────────────────────────┘
```

#### 3.2.2 Playback Feature Checklist

| Feature                    | Implementation Detail                                                      |
|----------------------------|----------------------------------------------------------------------------|
| Play / Pause               | `AudioPlayer.play()` / `.pause()` via `audio_service` handler             |
| Next / Previous            | `ConcatenatingAudioSource` queue management in `just_audio`               |
| Seek                       | `AudioPlayer.seek(Duration)` with slider in UI                            |
| Shuffle                    | `just_audio` built-in shuffle order                                       |
| Repeat (Off / One / All)   | `LoopMode.off` / `LoopMode.one` / `LoopMode.all`                          |
| Background Playback        | `audio_service` foreground service keeps playback alive                   |
| Lock Screen Controls       | `MediaSession` via `audio_service` metadata + control callbacks           |
| Notification Controls      | Android media notification with Play/Pause/Next/Prev buttons              |
| Volume / Speed             | `AudioPlayer.setVolume()` / `.setSpeed()` — exposed in settings           |
| Equaliser (stretch goal)   | Android system equaliser intent via `platform_channel`                    |
| Queue / Up Next            | `ReorderableListView` driven by `ConcatenatingAudioSource`                |
| Playlist creation          | User-named playlists stored in Isar `PlaylistCollection`                  |

#### 3.2.3 Lock Screen & Notification Metadata

When a song plays, update `MediaItem` in `audio_service`:

```dart
MediaItem _songToMediaItem(Song song) => MediaItem(
  id: song.id,
  title: song.title,
  artist: song.artist ?? 'Unknown Artist',
  duration: song.duration,
  artUri: Uri.file(song.localThumbnailPath),  // Album art from local file
);
```

---

## 4. App Workflow & Screen Architecture (UI/UX)

### 4.1 Navigation Structure

The app uses **GoRouter** for declarative, deep-link-aware navigation with a persistent `BottomNavigationBar` and a global `MiniPlayer` bar above it.

```
AppShell (Scaffold with BottomNavBar + MiniPlayer overlay)
├── /home           → HomeScreen (Dashboard)
├── /download       → DownloaderScreen
├── /library        → LibraryScreen
│   ├── /library/song/:id   → SongDetailScreen
│   └── /library/playlist/:id → PlaylistDetailScreen
└── /settings       → SettingsScreen

Modal Routes (pushed over AppShell):
└── /now-playing    → NowPlayingScreen (full-screen, DraggableScrollableSheet)
```

### 4.2 Screen Definitions

#### Screen 1 — Dashboard / Home (`/home`)

**Purpose**: Welcome screen with a summary of the library and quick actions.

**UI Components**:
- Recently downloaded songs (horizontal scroll)
- Active downloads badge (tapping navigates to Downloader tab)
- "Paste & Download" quick-action button (reads clipboard automatically)
- Statistics: total songs, total duration, storage used
- Continue listening card (last played song)

**State Dependencies**:
- `libraryProvider` (for recent songs)
- `downloadQueueProvider` (for active download badge)
- `playerProvider` (for continue listening card)

---

#### Screen 2 — Downloader (`/download`)

**Purpose**: Primary screen for initiating downloads.

**UI Components**:
- `TextField` for URL input with paste-from-clipboard icon
- Video metadata preview card (loads after URL validation): thumbnail, title, duration, uploader
- Audio quality selector (if multiple streams available)
- "Download" CTA button
- Active downloads list (`ListView` of `DownloadTaskTile` widgets)
  - Each tile: thumbnail, title, `LinearProgressIndicator`, speed, ETA, cancel button

**State Flow**:
```
User pastes URL → URL validated → metadata card appears → 
User taps Download → DownloadQueue.enqueue() → task added to list → 
Progress stream drives tile UI → On completion → libraryProvider invalidated
```

---

#### Screen 3 — Media Library (`/library`)

**Purpose**: Browse, search, and manage all downloaded songs and playlists.

**UI Tabs** (within this screen):
- **Songs** — `ListView` of all songs, sortable by Title / Date Added / Artist / Duration
- **Playlists** — `GridView` of user-created playlists
- **Artists** — Grouped by extracted artist tag

**UI Components**:
- Search bar with real-time filtering (debounced, 300ms)
- Sort/filter action chips
- `SongTile` with swipe-to-delete (with undo `SnackBar`)
- Long-press context menu: Add to Playlist, Share, Delete, View Info
- Multi-select mode with batch operations

**State Dependencies**:
- `libraryProvider` (watches Isar DB stream — auto-updates on new downloads)

---

#### Screen 4 — Now Playing (`/now-playing`)

**Purpose**: Full-screen immersive player experience.

**UI Components**:
- Full-bleed blurred album art background
- Large album art thumbnail (animated subtle pulse on beat — stretch goal)
- Song title, artist, like button
- Seek slider with current time / total duration
- Transport controls: Previous, Play/Pause, Next (with ripple feedback)
- Secondary controls: Shuffle toggle, Repeat mode cycle, Add to Playlist
- Up Next queue (draggable bottom sheet)

**Mini-Player** (persistent overlay above `BottomNavigationBar`):
- Album art thumbnail, song title (marquee scrolling if too long)
- Play/Pause button, Next button
- Tap → expands to full NowPlayingScreen

---

#### Screen 5 — Settings (`/settings`)

- Default download quality (128 kbps / 192 kbps / 320 kbps)
- Download location (app-scoped vs public Music folder)
- Metadata auto-fetch toggle (title from YouTube vs manual)
- Theme (Dark / Light / System)
- Clear cache, storage usage display

### 4.3 State Transition Diagram

```
[ Downloader Screen ]
  User pastes URL
        │
        ▼
  DownloadTask → status: PENDING
        │
        ▼ (WorkManager / background isolate kicks off)
  DownloadTask → status: DOWNLOADING (progress: 0% → 100%)
        │
        ▼ (ffmpeg_kit remuxing)
  DownloadTask → status: PROCESSING
        │
        ▼ (Isar write + file saved)
  DownloadTask → status: COMPLETED
        │
        ├──→ ref.invalidate(libraryProvider)
        │           │
        │           ▼
        │   [ Library Screen rebuilds ]
        │     New song tile appears
        │
        └──→ Show success SnackBar with "Play Now" action
                    │
                    ▼
            [ Now Playing Screen ]
              Song begins playing
```

---

## 5. Recommended Package Ecosystem

### 5.1 Complete Package Table

| Category              | Package                            | Version  | Justification                                                                                                                              |
|-----------------------|------------------------------------|----------|--------------------------------------------------------------------------------------------------------------------------------------------|
| **YouTube Parsing**   | `youtube_explode_dart`             | `^2.x`   | Pure Dart, no native dependencies. Reliably extracts audio streams, video metadata, and thumbnails. Actively maintained with frequent fixes for YouTube API changes. |
| **Audio Playback**    | `just_audio`                       | `^0.9.x` | The de-facto standard for Flutter audio. Supports gapless playback, `ConcatenatingAudioSource`, variable speed, local file URIs, and streams for all playback state. |
| **Background Audio**  | `audio_service`                    | `^0.18.x`| Manages Android foreground service and `MediaSession` integration. Designed to pair with `just_audio`. Provides lock-screen controls and media notification out of the box. |
| **Local Database**    | `isar`                             | `^3.x`   | Extremely fast embedded NoSQL database. Native Dart with code generation, full-text search, reactive streams (`watchLazy`), and zero-overhead reads — ideal for a reactive library view. |
| **State Management**  | `flutter_riverpod` + `riverpod_annotation` | `^2.x` | Type-safe, compile-time provider generation via `@riverpod`. Superior to Provider for async flows, avoids `BuildContext` dependency for state logic. |
| **Navigation**        | `go_router`                        | `^14.x`  | Official Flutter navigation package. Declarative, supports deep links, shell routes (for persistent nav bar + mini player), and redirect guards. |
| **FFmpeg (remux)**    | `ffmpeg_kit_flutter_audio`         | `^6.x`   | The **audio-only** build of the official FFmpeg Flutter binding. Used to remux WebM/Opus streams to MP3 and embed ID3 tags. The `_audio` variant reduces APK size significantly. |
| **Permissions**       | `permission_handler`               | `^11.x`  | Unified API for requesting Android permissions at runtime. Handles the split between `READ_EXTERNAL_STORAGE` (≤API 32) and `READ_MEDIA_AUDIO` (API 33+). |
| **File Paths**        | `path_provider`                    | `^2.x`   | Cross-platform access to `getExternalFilesDir`, `getApplicationDocumentsDirectory`. Official Flutter plugin maintained by the Flutter team. |
| **HTTP / Downloading**| `dio`                              | `^5.x`   | Robust HTTP client with built-in download progress callbacks, cancelToken support, and interceptor chain for retry logic. Preferred over `http` for file downloading. |
| **Code Generation**   | `build_runner` + `isar_generator` + `riverpod_generator` | latest | Required for Isar schema generation and `@riverpod` annotation processing. Pin to compatible versions. |
| **ID3 Tag Writing**   | `id3tag` or FFmpeg `-metadata` flag | —       | Use `ffmpeg_kit` with `-metadata title="..." -metadata artist="..."` during remux to embed ID3 tags natively — no separate package needed. |
| **Image Caching**     | `cached_network_image`             | `^3.x`   | Caches YouTube thumbnails during download; falls back to locally saved thumbnail thereafter. |
| **Connectivity**      | `connectivity_plus`                | `^6.x`   | Detect network state changes to pause/resume downloads gracefully and warn user before queueing large downloads on mobile data. |

### 5.2 `pubspec.yaml` Dependencies Block

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Core Architecture
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  go_router: ^14.2.0

  # YouTube
  youtube_explode_dart: ^2.2.0

  # Audio Playback & Service
  just_audio: ^0.9.39
  audio_service: ^0.18.15

  # FFmpeg (audio-only build for smaller APK)
  ffmpeg_kit_flutter_audio: ^6.0.3

  # Database
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1
  path_provider: ^2.1.3

  # Networking
  dio: ^5.7.0
  connectivity_plus: ^6.0.3

  # Permissions & Files
  permission_handler: ^11.3.1

  # UI Utilities
  cached_network_image: ^3.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.11
  isar_generator: ^3.1.0+1
  riverpod_generator: ^2.4.3
  custom_lint: ^0.6.4
  riverpod_lint: ^2.3.10
```

---

## 6. Critical Technical Considerations & Android Edge Cases

### 6.1 Storage Permissions — Scoped Storage & Android 13+

This is the single most fragile area of Android development. The strategy differs by API level:

| Android Version     | API Level | Storage Approach                                                                  | Permissions Required                  |
|---------------------|-----------|-----------------------------------------------------------------------------------|---------------------------------------|
| Android 8–9         | 26–28     | Broad external storage via `getExternalStorageDirectory()`                        | `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` |
| Android 10          | 29        | Scoped storage preferred; legacy mode via `requestLegacyExternalStorage` in manifest | `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` |
| Android 11–12       | 30–32     | Must use app-scoped directory or `MediaStore` API for shared storage             | `READ_EXTERNAL_STORAGE` (for reading others' files only) |
| Android 13+         | 33+       | Granular media permissions; `READ_MEDIA_AUDIO` replaces `READ_EXTERNAL_STORAGE`  | `READ_MEDIA_AUDIO`                    |

**Recommended Strategy**: Use **app-scoped external storage** via `path_provider`'s `getExternalStorageDirectory()`. This eliminates the need for any read/write permissions on Android 10+ while keeping files in external storage (accessible via USB, visible in file managers within the app's folder). Only request `READ_MEDIA_AUDIO` if implementing a feature to scan the user's existing music library.

**`AndroidManifest.xml` entries**:
```xml
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"
    android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

**Runtime permission request flow** (using `permission_handler`):
```dart
Future<bool> requestAudioPermission() async {
  if (Platform.isAndroid) {
    final sdkVersion = await DeviceInfoPlugin().androidInfo
        .then((i) => i.version.sdkInt);
    
    final permission = sdkVersion >= 33
        ? Permission.audio          // READ_MEDIA_AUDIO
        : Permission.storage;       // READ_EXTERNAL_STORAGE

    final status = await permission.request();
    return status.isGranted;
  }
  return true;
}
```

---

### 6.2 Background Execution — Downloads & Media Playback

Android aggressively kills background processes. Two separate strategies are required:

#### 6.2.1 Background Downloads — WorkManager

Use **`WorkManager`** (via a platform channel or the `workmanager` Flutter package) for resilient background downloads. WorkManager survives app minimization, device restarts, and low-memory kills.

```
Download enqueued in UI
        │
        ▼
WorkManager OneTimeWorkRequest created
        │
        ▼
Android schedules Worker on background thread
(survives app kill, device restart, Doze mode with constraints)
        │
        ▼
Worker performs: HTTP download → FFmpeg remux → Isar write
        │
        ▼
Worker posts progress via setProgressAsync() → observed in app via LiveData
        │
        ▼
WorkManager sends completion broadcast → app invalidates libraryProvider
```

**WorkManager `AndroidManifest.xml` declaration**:
```xml
<service
    android:name="androidx.work.impl.foreground.SystemForegroundService"
    android:foregroundServiceType="dataSync"
    tools:node="merge" />
```

#### 6.2.2 Background Music Playback — Foreground Service

`audio_service` automatically manages the Android Foreground Service lifecycle. No manual service code is required in the app. Ensure:

1. The `foregroundServiceType="mediaPlayback"` is declared in the manifest (handled by `audio_service`'s AAR).
2. A `MediaSession` token is published so the system can route hardware media keys.
3. The `WAKE_LOCK` permission is declared to prevent the CPU from sleeping during playback.
4. `AudioFocusRequest` is managed to pause on calls and duck for notifications (built into `just_audio`).

**Doze Mode Strategy**: `audio_service` keeps a partial `WakeLock` during active playback. Downloads should use `WorkManager` with a `setExpedited()` flag for download tasks to ensure they are treated as user-initiated work and not deferred by Doze.

---

### 6.3 YouTube Extraction Risk & Mitigation Strategy

YouTube periodically changes its internal video manifest format (the `player.js` cipher, `nsig` parameter, and `innertube` API) to prevent scraping. This is the highest ongoing maintenance risk for the app.

#### 6.3.1 Risk Matrix

| Risk Event                         | Impact    | Frequency       |
|------------------------------------|-----------|-----------------|
| YouTube cipher algorithm update    | High      | Every 2–4 weeks |
| `innertube` API version bump       | Medium    | Monthly         |
| Age-restricted video changes       | Low       | Rare            |
| Regional restriction enforcement   | Low       | Rare            |

#### 6.3.2 Mitigation Strategies

**Strategy 1 — Rely on `youtube_explode_dart` community maintenance**
The package maintainer actively tracks YouTube changes and pushes patches within days. Pin to a version range (`^2.x`) and update `pubspec.lock` regularly via CI.

**Strategy 2 — Abstract the extraction layer**
The `YoutubeDatasource` interface must be the only code that knows about `youtube_explode_dart`. If the package breaks and has not yet been patched, the interface can be swapped to an alternative backend (e.g., a self-hosted `yt-dlp` API server) without touching any other code.

```dart
abstract class IYoutubeDatasource {
  Future<VideoMetadata> fetchMetadata(String videoId);
  Future<List<AudioStream>> getAudioStreams(String videoId);
}

// Implementation A: youtube_explode_dart (default)
class YoutubeExplodeDatasource implements IYoutubeDatasource { ... }

// Implementation B: Self-hosted yt-dlp REST API (fallback)
class YtDlpRemoteDatasource implements IYoutubeDatasource { ... }
```

**Strategy 3 — Graceful degradation UI**
When extraction fails with a recognisable error (cipher error, `403 Forbidden`), show a user-facing message:

> *"YouTube has updated its format. We're working on a fix. Please check for an app update."*

Never crash silently. Log the failure with the video ID and error code for debugging.

**Strategy 4 — Remote configuration flag**
Integrate a lightweight remote config (e.g., Firebase Remote Config) to flip the extraction backend or disable downloads entirely without an app release during an outage.

---

### 6.4 Audio Tagging — Metadata & Album Art

Downloaded files should have proper ID3 tags to integrate with Android's `MediaStore` and any third-party music apps.

#### 6.4.1 Metadata Sources (Priority Order)

| Tag Field  | Source 1 (Preferred)          | Source 2 (Fallback)                 |
|------------|-------------------------------|-------------------------------------|
| `Title`    | YouTube video title (cleaned) | Filename without extension          |
| `Artist`   | YouTube channel name          | `"Unknown Artist"`                  |
| `Album`    | `"YouTube Downloads"`         | `"YT-Groove"`                       |
| `Year`     | YouTube video upload date     | Current year                        |
| `Album Art`| YouTube `maxresdefault` thumbnail | `hqdefault` thumbnail           |
| `Duration` | From audio stream metadata    | Computed after download             |

#### 6.4.2 Embedding Tags via FFmpeg

During the remux step, embed all tags in a single FFmpeg command to avoid two-pass processing:

```bash
ffmpeg \
  -i "input_audio.webm" \
  -i "thumbnail.jpg" \
  -map 0:a \
  -map 1:v \
  -c:a libmp3lame \
  -q:a 2 \
  -id3v2_version 3 \
  -metadata title="Song Title" \
  -metadata artist="Channel Name" \
  -metadata album="YouTube Downloads" \
  -metadata date="2024" \
  -metadata_block_picture:0 \
  -disposition:v:0 attached_pic \
  "output.mp3"
```

This embeds the thumbnail as the MP3 album art (APIC frame) in a single pass — no separate tool required.

#### 6.4.3 Post-Download MediaStore Indexing

After saving the file, notify Android's `MediaStore` so the file appears in other music apps:

```dart
// Via a MethodChannel call to native Android
const channel = MethodChannel('com.ytgroove/media_scanner');

Future<void> scanFile(String filePath) async {
  await channel.invokeMethod('scanFile', {'path': filePath});
}

// Native Kotlin side:
MediaScannerConnection.scanFile(context, arrayOf(filePath), null, null)
```

---

## Appendix A — Project Setup Checklist

Before writing any feature code, complete this setup:

- [ ] Create Flutter project: `flutter create --org com.yourname yt_groove --platforms android`
- [ ] Configure `android/app/build.gradle` — `minSdkVersion 26`, `targetSdkVersion 35`
- [ ] Add all packages to `pubspec.yaml` and run `flutter pub get`
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` for code gen
- [ ] Add all permissions to `AndroidManifest.xml`
- [ ] Set up `audio_service` background handler in `main.dart` with `AudioServiceBackground.run()`
- [ ] Create Isar schema collections and run generator
- [ ] Set up GoRouter configuration with shell route for persistent navbar
- [ ] Configure ProGuard rules for FFmpeg and Isar in `proguard-rules.pro`

## Appendix B — Performance Guidelines

- **Isar reads** are synchronous and can safely be called from the UI thread for small datasets (< 10,000 songs). Use `watchLazy()` for reactive updates.
- **FFmpeg remux** runs in a background isolate via `ffmpeg_kit`. Never block the main isolate.
- **Thumbnail images** are cached locally after first download. Use `Image.file()` for local paths — never re-fetch from network after download is complete.
- **`ConcatenatingAudioSource`** pre-buffers the next track in the queue. Set `preload: false` for large queues to avoid excessive memory usage.
- **Search debouncing**: Apply a 300ms debounce on the library search input to avoid triggering Isar queries on every keystroke.

---

*Document maintained by the project architecture team. Update this file when adding new modules, changing dependencies, or revising architectural decisions. All major decisions should reference this document's constraints.*
