# Download Video App

A Flutter download manager with two independent engines:

1. **Direct transfer engine** for HTTP/HTTPS files using `background_downloader`.
2. **Media engine** for public video/audio pages using Android `yt-dlp` through `youtubedl-android`.

The two engines are intentionally separate. A site extractor failure does not break direct file downloads.

## Implemented

### Public media links
- Inspect public video/audio pages with yt-dlp metadata extraction.
- Detect title, uploader, thumbnail, duration, extractor, formats, and playlists.
- Recommended quality selector plus 2160p, 1440p, 1080p, 720p, 480p, and 360p limits.
- Show source-provided combined formats when available.
- Best video + audio merging with FFmpeg.
- MP3 and M4A audio extraction.
- Playlist queueing.
- Background Android WorkManager jobs with progress and ETA.
- Optional Aria2 acceleration.
- Retry, cancel, open, share, and persistent Flutter-side history.
- Receive links from Android's Share sheet.
- Update yt-dlp extractors from Settings.
- Media outputs are stored under `Downloads/Download Video App`.

### Direct files
- Real HTTP `HEAD` metadata inspection.
- Persistent background downloads.
- Live progress, expected size, transfer speed, and ETA when available.
- Pause, resume, cancel, and retry.
- Wi-Fi-only mode and simultaneous-download limit.
- Native notifications and completed-file library.

### App
- Unified Transfers screen for direct and yt-dlp jobs.
- Unified Library for completed files and media.
- Light, dark, and system themes.
- Persistent settings.
- CI runs dependency resolution, `flutter analyze`, and `flutter test` only. It intentionally does **not** build or upload APK artifacts.

## Responsible-use boundary

Use the app only for media you are authorized to download. The project intentionally does **not** implement DRM circumvention, paywall bypassing, premium-format unlocking, or private-account cookie extraction.

## Android media architecture

```text
Flutter UI
  ├─ Direct HTTP/HTTPS -> background_downloader
  └─ Media page/playlist -> MethodChannel -> yt-dlp metadata
                                      -> WorkManager YtDlpWorker
                                      -> yt-dlp + FFmpeg + optional Aria2
                                      -> public Downloads folder
```

The native media bridge lives in:

- `android/app/src/main/kotlin/com/ahmedqaid/downloadvideoapp/MainActivity.kt`
- `android/app/src/main/kotlin/com/ahmedqaid/downloadvideoapp/YtDlpWorker.kt`
- `lib/services/media_extractor.dart`

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Third-party components

The Android media engine depends on `youtubedl-android` 0.18.1, which wraps yt-dlp and provides FFmpeg/Aria2 integration. `youtubedl-android` is GPLv3-licensed. Anyone distributing this application must review and comply with the licenses of youtubedl-android, yt-dlp, FFmpeg, Aria2, and the rest of the dependency graph. See `THIRD_PARTY_NOTICES.md`.
