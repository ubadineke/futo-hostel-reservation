# Roost Student App

The default Flutter entry point, `lib/main.dart`, is the FUTO student hostel
reservation app. It requires the live backend for sign-in, hostel availability,
reservations, and payment flow; there is no offline demo-data mode.

## Run the student app

```bash
flutter pub get
flutter run
# explicitly select the student entry point:
flutter run -t lib/main.dart
```

To point a local Android emulator build at another API:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

## Build a student APK

Install Android Studio and the Android SDK, then run:

```bash
flutter build apk --release
```

The APK is created at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

The current release configuration is debug-key signed for testing. Create and
configure a private Android signing key before Play Store distribution.

## Run both apps on a physical iPhone

Connect and unlock the iPhone, trust the Mac, and enable **Developer Mode** in
**Settings → Privacy & Security → Developer Mode**. Then find its device ID:

```bash
flutter devices
```

Run the student app:

```bash
flutter run -d <iphone-device-id> -t lib/main.dart
```

Run the admin app in another terminal:

```bash
flutter run -d <iphone-device-id> --flavor admin -t lib/main_admin.dart
```

The admin flavor uses a separate iOS bundle ID, so it installs as a second app
rather than replacing the student app.

## Optional admin app

The administrative mobile app has a separate entry point and is optional:

```bash
flutter run -t lib/main_admin.dart
flutter build apk --release -t lib/main_admin.dart
```

For physical iOS development, use the `--flavor admin` command above. It
requires a backend admin account. The static web dashboard is in `../admin/`.
