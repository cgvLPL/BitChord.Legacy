# BitChord for iOS 15+

This is a native Swift implementation alongside the original Android/Kotlin project. The Android application and repository root are not modified by this port.

## Compatibility

- Minimum deployment target: iOS 15.0
- Optimised target device: iPhone 7 and newer, including compact 4.7-inch layouts and memory-conscious artwork handling
- UI: SwiftUI, using iOS 15-compatible APIs
- Audio playback: AVPlayer / AVFoundation
- Background audio and Lock Screen / Control Centre transport: AVAudioSession and MediaPlayer
- Build generation: XcodeGen

## Build

Requirements: macOS, Xcode, and XcodeGen.

```sh
cd ios
xcodegen generate
open BitChord.xcodeproj
```

Then select the BitChord scheme and an iOS 15.0+ simulator or device. A GitHub Actions workflow at `.github/workflows/ios.yml` generates the project and runs a simulator build/test on macOS.

## Implemented in this branch

- Native app shell with Home, Explore, Search, Library and Settings.
- iOS 15-compatible SwiftUI layouts, compact iPhone 7 player/search layouts, and cached/downsampled artwork thumbnails.
- YouTube Music public web search request/parser (best-effort; YouTube can change or restrict this unofficial endpoint).
- Local YouTube audio extraction through [YouTubeKit](https://github.com/alexeichhorn/YouTubeKit), selecting native-playable M4A audio streams. Remote extraction fallback is deliberately disabled.
- Compatible addon source search and on-demand direct-stream resolution using the upstream addon protocol's `/search?q=` and `/stream/{id}` endpoints.
- AVPlayer playback for YouTube and addon tracks when a native-playable direct stream is available.
- Audio background mode, interruption handling, Lock Screen metadata and remote play/pause/next/previous/seek commands.
- Playback queue and end-of-track advancement.
- Playback speed selection and a countdown sleep timer.
- LRCLIB synced-lyrics lookup and current-line highlighting.
- Local playlist persistence and queue actions.
- Direct-URL downloads into the app's Documents directory, including on-demand addon/YouTube URL resolution and local-file playback.
- Basic unit tests for the queue model.

## Important limitations / next integration work

This is an actively developing port, not yet a feature-complete or release-ready replacement for the iOS 17+ app.

- YouTube audio extraction is supplied by the separate YouTubeKit Swift package rather than a port of BitChord's Android InnerTubeX/NewPipe pipeline. It is an unofficial extractor, may break after YouTube changes, and can fail for region-, age-, account- or policy-restricted videos. On extraction failure, the app offers an Open in YouTube Music fallback.
- Google / YouTube account authentication and cookie/session management are not implemented. Do not enter Google passwords or paste private session cookies into arbitrary endpoints.
- Addon support currently expects a compatible server to return direct stream URLs. It does not yet implement the full manifest settings negotiation, download policy, health checks, quality tiers, or request-header handling from the Android implementation.
- Lyrics currently use LRCLIB only; multiple-provider priority, translations, word timing and source settings remain to be ported.
- Downloads currently save direct stream URLs only. Resume, cache management, metadata/tag writing and source-specific download permissions remain outstanding.
- The reference app's widget, share extension, CarPlay, listen-together, Discord, Spotify, Last.fm/ListenBrainz, Replay, audio visualisation, advanced equalizer, crossfade, gapless playback, Automix, bit-perfect USB output and local/network media library are not yet implemented.
- The app has not yet been verified on a physical iOS 15 device. The macOS CI workflow is included to perform a real Xcode compile and report compiler or deployment-target issues.

## Reference IPA

The supplied 1.0.1 build is used as a behavioral and feature reference. Its README and bundle metadata were inspected. An IPA contains compiled binaries and assets, not the original editable Swift source, so this project reimplements the app's behavior rather than extracting the original project.

## Licensing

The upstream project is GPL-3.0. Keep its license and attribution notices. Any redistributed binary must be accompanied by the corresponding source as required by the license.
