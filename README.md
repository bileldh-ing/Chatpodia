<div align="center">

<img src="assets/branding/icon.png" width="112" alt="Chatpodia icon"/>

# Chatpodia

**A production-grade AI assistant built with Flutter** — liquid-glass UI, streaming chat, voice mode, vision, image / web-app / motion generation, local encrypted accounts and a store-ready CI/CD pipeline.

[![CI](https://github.com/bileldh-ing/Chatpodia/actions/workflows/ci.yml/badge.svg)](https://github.com/bileldh-ing/Chatpodia/actions/workflows/ci.yml)
[![Release](https://github.com/bileldh-ing/Chatpodia/actions/workflows/release.yml/badge.svg)](https://github.com/bileldh-ing/Chatpodia/actions/workflows/release.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS-3FE0B0)
![License](https://img.shields.io/badge/license-MIT-green)

</div>

---

## ✨ Features

| | |
|---|---|
| 🫧 **Liquid-glass design** | Backdrop blur, gradients, specular sheen, animated orb, shimmer, haptics, press physics |
| 🔐 **Local accounts** | Email/password on SQLite — PBKDF2-HMAC-SHA256 (120k iterations, per-user salt), lockout after 5 failures, 30-day sessions in the Keystore/Keychain. Optional Google Sign-In |
| 🫆 **App lock** | Fingerprint / Face ID / device PIN, re-locks after 30 s in background |
| 💬 **Streaming chat** | Token-by-token answers, Markdown, code blocks with language label + one-tap copy, retry / stop / copy / share / listen, quick replies, time separators |
| ✏️ **Message actions** | Long-press → copy, edit & resend, delete. Rename chats, export as Markdown |
| 🖼️ **Vision** | Attach up to 4 photos and ask about them (Gemini / OpenAI-compatible providers) |
| 🎨 **Image generation** | Prompt → image, variations, full-screen pinch-zoom viewer, save / share; automatic back-off when the free tier is rate-limited |
| 🌐 **Web-app builder** | Podia writes a complete single-file web app; live preview + code view |
| 🎬 **Motion clips** | AI storyboard → rendered shots → Ken-Burns / cross-fade clip |
| 🎙️ **Voice mode** | Live transcript, mic-reactive orb, auto-send, text-to-speech answers |
| 🗂️ **History** | Grouped by day, searchable, pinned chats, swipe to delete |
| ⚡ **Offline answers** | Instant prebuilt replies for greetings, date/time, music and more |
| 🧰 **Production plumbing** | Global error handling + in-app diagnostics log, friendly error widget, bundled fonts (no runtime fetching), adaptive icons + native splash, R8 shrinking, obfuscated release builds |

## 🚀 Getting started

```bash
git clone https://github.com/bileldh-ing/Chatpodia.git
cd Chatpodia
flutter pub get
flutter run
```

Works out of the box with the free **Pollinations** backend (no key). For better answers and vision, open **Settings → AI model** and paste a **Gemini** or **OpenAI-compatible** key — it is stored in the device keystore only.

> The free Pollinations image tier is limited to about one image every 45 s per IP. Chatpodia retries automatically with back-off; a Pollinations or Gemini key removes the limit.

## 🧪 Quality

```bash
dart format --set-exit-if-changed lib test   # 120-col formatter (analysis_options.yaml)
flutter analyze --fatal-infos
flutter test --coverage
```

27 unit & widget tests run the real app against an **in-memory SQLite** database (`sqflite_common_ffi`) and a **scripted AI client**: auth (hashing, lockout, session restore, password change, deletion), chat streaming & persistence, intent routing (image / web / motion), error bubbles, edit & resend, and the main screens.

> Linux needs the system SQLite for FFI tests: `sudo apt-get install libsqlite3-dev`.

## 🔁 CI/CD

| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` | push to `main`/`develop`, PRs | format check → analyze → tests + coverage → release APKs (split per ABI) + AAB → unsigned iOS build. Artifacts uploaded. |
| `release.yml` | tag `vX.Y.Z` or manual | signed AAB/APKs (obfuscated, symbols archived) → GitHub Release → Google Play track (default *internal*) → TestFlight via fastlane `match` |
| `dependabot.yml` | weekly | pub, Gradle and Actions updates |

### Repository secrets (Settings → Secrets → Actions, environment `production`)

| Secret | Used for |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | upload key |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play Console service account (optional — upload is skipped when absent) |
| `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_P8` | App Store Connect API key (optional — unsigned iOS build when absent) |
| `MATCH_GIT_URL`, `MATCH_PASSWORD`, `MATCH_GIT_BASIC_AUTHORIZATION` | fastlane match certificates repo |

Create the upload key once:

```bash
keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Locally, put the same values in `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) — it is git-ignored. Without it, release builds fall back to debug signing so `flutter run --release` still works.

**Ship a release:** bump `version:` in `pubspec.yaml`, add `android/fastlane/metadata/android/en-US/changelogs/<build>.txt`, then

```bash
git tag v1.1.0 && git push origin v1.1.0
```

Store listing text lives in `android/fastlane/metadata/`. Fastlane lanes: `android: internal, promote` · `ios: beta`.

## 🎬 Demo video

The demo is recorded from the **real Flutter UI**: `tool/demo/record_demo_test.dart` drives the app with scripted input (in-memory DB, scripted AI, fake microphone) and captures every frame at 30 fps.

```bash
flutter test tool/demo/record_demo_test.dart --plain-name "scene 2"   # → tool/demo/out/s2/*.png
```

## 🔑 Google Sign-In (optional)

1. Google Cloud Console → Credentials → **OAuth client ID (Android)** with package `com.chatpodia.chatpodia` and your SHA-1 (`cd android && ./gradlew signingReport`). Add the SHA-1 of the Play app-signing key too.
2. iOS: create an iOS client, add `GIDClientID` and the reversed client ID URL scheme to `ios/Runner/Info.plist`.
3. Until configured the button shows a friendly message; email sign-up works fully.

## 🏗️ Architecture

```
lib/
  main.dart                 DI root (ChatpodiaApp), AuthGate, global error handling
  core/                     theme tokens, logging, widgets (LiquidGlass, PodiaOrb, AppBackground…)
  data/                     entities · AppDatabase (versioned migrations, FK cascades) · DAOs
  services/                 AiClient (Pollinations / Gemini / OpenAI) · AuthService · VoiceRecognizer · Settings
  features/                 auth · home · chat · voice · generate · history · settings · lock
test/
  helpers/                  in-memory DB env, FakeAiClient, FakeVoiceRecognizer
  unit/ · widget/
tool/demo/                  demo-video recorder
.github/                    CI, release, dependabot, templates
android/fastlane · ios/fastlane
```

Every backend sits behind an interface and is injected at the root, so tests, the demo recorder and production run the same UI code.

## 📄 License

MIT © 2026 Bilel Dhahri — see [LICENSE](LICENSE). Privacy: [PRIVACY.md](PRIVACY.md).
