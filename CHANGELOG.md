# Changelog

## 1.1.0 (build 2) — 2026-10-22
### Added
- Photo attachments with vision (Gemini / OpenAI-compatible)
- Edit & resend, delete message, rename chat, export chat as Markdown
- Biometric / device-credential app lock
- Code blocks with language label and one-tap copy; time separators in chat
- Global error handling, diagnostics log, friendly error widget, About section
- Adaptive launcher icons and native splash; bundled Plus Jakarta Sans
- Automatic back-off when the free image tier is rate-limited
- 27 unit & widget tests on in-memory SQLite with a scripted AI client
- CI (format, analyze, test, Android & iOS builds) and Release (signed AAB, GitHub Release, Play internal, TestFlight) workflows, fastlane, dependabot
- Release builds: R8 shrinking, obfuscation, archived debug symbols
### Changed
- AI and voice backends behind interfaces, injected at the app root

## 1.0.0 (build 1) — 2026-10-21
- First release: liquid-glass UI, local auth, streaming chat, voice mode, image / web-app / motion generation
