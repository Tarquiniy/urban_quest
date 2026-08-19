# Urban Quest

Mobile location-based quest game built with Flutter and Supabase.

## Product overview

Urban Quest is a gamified city exploration app where players:
- discover nearby quest points on a map,
- complete tasks and quiz questions,
- gain XP/points and unlock achievements,
- create teams and collaborate in team quests.

The app is cross-platform (Android/iOS/Web/Desktop support is present in the repo).

## Tech stack

- **Frontend:** Flutter (Dart)
- **State management:** Provider
- **Backend/BaaS:** Supabase (Auth + Postgres + Storage + Realtime)
- **Maps & geolocation:** flutter_map, geolocator, geocoding
- **Notifications:** flutter_local_notifications
- **Networking/media:** http, cached_network_image, image_picker, flutter_svg

## Repository structure

```text
lib/
  main.dart                 # App entrypoint and DI/providers wiring
  models/                   # Domain models
  providers/                # App state and business logic
  repositories/             # Data access layer
  screens/                  # UI screens
  services/                 # External integrations (Supabase, notifications, etc.)
  theme/                    # Design system/theme configuration
  widgets/                  # Reusable UI components
```

## Prerequisites

Install:
- Flutter SDK (stable channel)
- Dart SDK (comes with Flutter)
- Android Studio / Xcode (for mobile builds)

Verify local setup:

```bash
flutter --version
flutter doctor
```

## Environment setup (required)

Credentials are intentionally **not** stored in git.

1. Copy the template:

```bash
cp lib/constants.example.dart lib/constants.dart
```

2. Fill in real Supabase values in `lib/constants.dart`:
- `supabaseUrl`
- `supabaseAnonKey`
- storage bucket names (if different from defaults)

> `lib/constants.dart` is gitignored by design.

## Install and run

```bash
flutter pub get
flutter run
```

For a specific platform:

```bash
flutter run -d android
flutter run -d ios
flutter run -d chrome
```

## Build

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## Quality gates

Run before every release:

```bash
flutter format .
flutter analyze
flutter test
```

## Dependency updates

Check outdated packages:

```bash
flutter pub outdated
```

Upgrade:

```bash
flutter pub upgrade --major-versions
```

Then validate with:
- `flutter analyze`
- `flutter test`
- smoke run on target platforms.

## Security notes

- Never commit `lib/constants.dart` or real API keys.
- Use separate Supabase projects/keys for dev and production.
- Rotate keys immediately if leaked.

## Release readiness checklist

- [ ] Environment constants are configured for production.
- [ ] `flutter analyze` passes with no blocking issues.
- [ ] Core user flows smoke-tested (auth, map, quest completion, team flow).
- [ ] Build artifacts generated for target platforms.
- [ ] Crash/analytics monitoring configured (if used in your infra).

## License

Add your preferred license (MIT/Apache-2.0/proprietary) before public distribution.
