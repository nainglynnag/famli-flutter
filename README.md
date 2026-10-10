# Famli

Famli is a modern cross-platform family routine, task, privilege, and rewards companion built with Flutter. It helps parents and children build healthy daily habits together through positive reinforcement, routine tracking, and seed points.

---

## 🌿 Attribution & Reference

Famli is inspired by and built upon the foundational concept of **Daily Buddies** by **Sayar Ei Maung**:

- **Reference Repository**: [https://github.com/eimg/daily-buddies.git](https://github.com/eimg/daily-buddies.git)
- **Original Stack**: React Native (Expo Router) + Express API (Prisma + SQLite)

We express our gratitude to Sayar Ei Maung for the open-source architecture, data models, and initial design ideas that made this Flutter evolution possible.

---

## 🚀 Key Evolutions & Changelog (from Reference Project)

Famli expands on the reference project with a full Flutter port, upgraded visual design, and new interactive capabilities:

- **Flutter & Riverpod Rewrite**: Re-engineered from React Native to native Flutter (Dart) using Riverpod for declarative state management and GoRouter for declarative routing.
- **Dual-Backend Support**: Integrated Firebase (Firestore real-time streams + Firebase Auth) while retaining compatibility with the reference Express REST API (`--dart-define=BACKEND=rest`).
- **Interactive Onboarding Walkthrough**: Added a 3-slide animated onboarding experience with custom vector illustrations, animated progress bars, and role highlights.
- **Frosted Glassmorphism UI**: Implemented frosted navigation bars (`FrostedNavBar`) and sticky headers (`StickyTopBar`) featuring backdrop blurs, translucent tinting, specular borders, and blur-toggle fallbacks.
- **Reorganized Profile & Dedicated Security Screen**: Organized settings into 5 compact groups (Profile, Preferences, Security, Family Settings, Account), added an icon-only theme switch (`[ ☀️ | 🌙 ]`) aligned with the language switch, and moved password changes into a dedicated screen.
- **Account-Backed Preference Sync**: Instantaneous (0 ms) local cache for theme and language choices, backed by automatic cloud synchronization with user accounts.
- **Real-World Timezone Auto-Sync**: Added device system timezone auto-detection via `flutter_timezone` and a searchable bottom-sheet picker with country flags (e.g. 🇲🇲 Myanmar Asia/Yangon GMT+6:30, 🇹🇭 Thailand Asia/Bangkok GMT+7:00) and GMT offsets.
- **Full Bilingual Localization**: Complete Myanmar and English language support across all screens, routine management, streak rewards, and notifications.
- **Custom Sprout Vector Animations**: Custom-painted organic sprout loading animations (`SproutLoadingIndicator`) replacing default progress spinners, featuring delay-aware reassuring status messages.
- **Role-Aware Notification Center**: In-app notification center notifying parents of completed tasks and child requests, and notifying children of streak rewards and point adjustments.

---

## ✨ Features Overview

### 👨‍👩‍👧‍👦 For Parents

- **Family Hub**: View all children, their active streak counts, and completed task summaries.
- **Task & Routine Management**: Create one-off assignments or recurring routine templates with customizable seed point values.
- **Privilege Approvals**: Review and approve or decline privileges requested by children using their earned seeds.
- **Family Timezone Settings**: Auto-sync timezone with the device or pick a real-world location to keep habit schedules accurate.

### 🧒 For Children

- **Today's Tasks & Routines**: Simple checklists to complete daily responsibilities and earn seeds.
- **Streak Rewards**: Earn bonus points for maintaining consecutive days of routine completion.
- **Privilege Marketplace**: Browse rewards and submit privilege requests using accumulated seed points.
- **Personalization**: Customize avatar tones, toggle dark/light theme, and switch between Myanmar and English.

---

## 🛠️ Getting Started

### 1. Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>=3.5.0`)
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

To run with Firebase, configure your Firebase project credentials:

```bash
flutterfire configure
```

This generates the necessary configuration files:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/config/firebase_options_dev.dart`

_(Alternatively, use the `.example` templates provided in those directories as references)._

### 5. Running the App

#### Local Development (Current supported workflow)

```bash
# Run with local emulator / local development backend
flutter run
```

```bash
# Or run with the original Express REST API backend
flutter run --dart-define=BACKEND=rest
```

> **Note on Cloud Deployment**: Target cloud environments (`--dart-define=FIREBASE_ENV=dev`) are currently in development and planned for future updates. Please use local development or local emulators for current testing.

### 6. Tests & Static Analysis

```bash
# Run static analysis
dart analyze lib test

# Run test suite
flutter test
```

---
