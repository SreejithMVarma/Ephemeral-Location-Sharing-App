# Ephemeral Radar Mobile

Flutter app for production location sharing flows.

## Local Development

```bash
flutter pub get
flutter test
flutter run
```

### Android phone over USB

Use the phone-specific config when you want a physical device to hit the local backend on your machine:

```bash
adb reverse tcp:8000 tcp:8000
flutter run --dart-define-from-file=env/dev.phone.json
```

Or from the repo root:

```bash
npm run mobile:dev:phone
```

If you want the backend started for you as well on Windows, use:

```bash
npm run dev:phone
```

## Production Build

```bash
flutter build apk --release
flutter build ipa --release
```
