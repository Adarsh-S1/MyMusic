# MyMusic (YT-Groove) -- (Android Only)

A feature-rich Flutter application for downloading and playing music directly from YouTube.

## Features

* **Direct YouTube Downloads**: Download individual songs or entire playlists directly via YouTube URLs.
* **Offline Playback**: A fully functional offline music player to listen to your downloaded tracks.
* **Background Audio**: Keep the music playing in the background with lock screen controls and system notification support.
* **Intent Sharing**: Share a YouTube link directly from the YouTube app to MyMusic to instantly start downloading.
* **Local Library**: Efficiently manages your songs and custom playlists using a local database.
* **Auto-Restore**: Automatically scans your device's music directory to restore previously downloaded songs if you reinstall the app.

## Tech Stack

* **Framework**: [Flutter](https://flutter.dev/)
* **State Management**: [Riverpod](https://riverpod.dev/)
* **Database**: [Isar](https://isar.tech/) (Fast NoSQL database)
* **Audio Playback**: [just_audio](https://pub.dev/packages/just_audio) & [audio_service](https://pub.dev/packages/audio_service)
* **Downloader Engine**: [yt-dlp](https://github.com/yt-dlp/yt-dlp) running via [Chaquopy](https://chaquo.com/chaquopy/) for Python integration in Flutter.
* **Routing**: [go_router](https://pub.dev/packages/go_router)

## Getting Started

### Prerequisites
* Flutter SDK (latest stable version)
* Android Studio / VS Code

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/mymusic.git
   ```
2. Navigate to the project directory:
   ```bash
   cd mymusic
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Architecture

The app follows a structured architecture separating UI, domain, and data layers:
- `lib/presentation`: Screens, widgets, and Riverpod providers.
- `lib/domain`: Entities and abstract repository interfaces.
- `lib/data`: Local/remote datasources, DAO implementations (Isar), and Chaquopy bindings.
- `lib/core`: Utilities, constants, and helper classes.
