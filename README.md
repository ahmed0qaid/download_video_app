# Download Video App

A Flutter download manager for direct **HTTP/HTTPS file URLs**. The app keeps the original Stitch-inspired visual design while replacing demo data with a real persistent background download engine.

## Implemented

- Direct link inspection using a real HTTP `HEAD` request
- Background downloads with persistent task history
- Live progress, expected file size, transfer speed, and estimated time remaining when the server provides them
- Pause, resume, cancel, and retry
- Native Android download notifications
- Wi-Fi-only enforcement for new tasks
- Configurable simultaneous download limit
- Configurable relative download folder
- Automatic retries for new tasks
- Real completed-file library with search/category filters
- Open completed files with an installed compatible app
- Light, dark, and system themes persisted locally
- Android project files with package `com.ahmedqaid.downloadvideoapp`
- GitHub Actions checks: `flutter analyze`, `flutter test`, and Android debug APK build

## Supported links

The app intentionally supports direct HTTP/HTTPS file URLs only. It does not bypass DRM, authentication, paywalls, or website restrictions and it does not include site-specific video extraction.

## Run

```bash
git clone https://github.com/ahmed0qaid/download_video_app.git
cd download_video_app
flutter pub get
flutter run
```

For an APK:

```bash
flutter build apk --debug
```

The generated debug APK is also uploaded as a GitHub Actions artifact after successful CI builds.

## Main packages

- `background_downloader` for native background transfer execution, persistence, notifications, pause/resume, and queue controls
- `http` for link metadata inspection
- `shared_preferences` for app preferences
