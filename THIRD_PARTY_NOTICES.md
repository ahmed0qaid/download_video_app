# Third-party notices

This project uses open-source components. This file is a practical inventory, not a substitute for reviewing each dependency's license before distribution.

## youtubedl-android

- Project: `yausername/youtubedl-android` / Maven Central packages published under `io.github.junkfood02.youtubedl-android`
- Version used: `0.18.1`
- Purpose: Android wrapper/runtime for yt-dlp plus optional FFmpeg and Aria2 integration.
- License: GNU GPL v3.0.

## yt-dlp

- Project: `yt-dlp/yt-dlp`
- Purpose: public media metadata extraction and download orchestration.
- The runtime is supplied through youtubedl-android and may be updated in-app.

## FFmpeg

- Purpose: merge separate video/audio streams and convert extracted audio.
- The exact licensing obligations depend on the bundled FFmpeg build and enabled components. Review the package distribution before publishing binaries.

## Aria2

- Purpose: optional external transfer acceleration for yt-dlp downloads.
- The runtime is supplied through youtubedl-android's Aria2 package.

## Flutter dependencies

The Dart/Flutter dependency graph is declared in `pubspec.yaml`. Android dependencies are declared in `android/app/build.gradle.kts`.

## Product-name note

No YTDLnis source code, branding, application name, package name, or UI assets are copied into this project. YTDLnis was used only as an architectural reference. The media integration is implemented against the upstream youtubedl-android API.
