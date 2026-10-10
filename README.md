# Famli (Flutter)

A cross-platform Flutter application for family task management, routines, privilege requests, streak rewards, and reminders.

---

## 🛠️ Getting Started

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>=3.5.0)
- [Firebase CLI](https://firebase.google.com/docs/cli) & [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/)

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Environment Setup
Copy the template `.env.example` to `.env`:
```bash
cp .env.example .env
```
Configure your desired settings (e.g., `STORAGE_PROVIDER=local`).

### 4. Firebase Configuration
Because this repository does not include real Firebase credentials, configure Firebase for your own project:

```bash
flutterfire configure
```
This command generates your platform-specific configuration:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/config/firebase_options_dev.dart`

*(Alternatively, you can copy the `.example` templates in those directories and replace with your own project credentials.)*

### 5. Run the App
```bash
# Run with local emulator (default)
flutter run

# Or target cloud development environment
flutter run --dart-define=FIREBASE_ENV=dev
```

### 6. Tests & Analysis
```bash
dart analyze lib
flutter test
```
