# Famli

Famli is a modern cross-platform family routine, task, privilege, and rewards companion built with Flutter. It helps parents and children build healthy daily habits together through positive reinforcement, routine tracking, and seed points.

---

## 🌿 Attribution & Reference

Famli is inspired by and built upon the foundational concept and architecture of **Daily Buddies** by **Sayar Ei Maung**:

- **Reference Repository**: [https://github.com/eimg/daily-buddies.git](https://github.com/eimg/daily-buddies.git)
- **Original Stack**: React Native (Expo Router) + Express API (Prisma + SQLite)

We express our sincere gratitude to Sayar Ei Maung for the open-source architecture, data models, and initial design ideas that made this Flutter evolution possible.

---

## 📄 License

Famli is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

```text
Copyright (c) 2025 Ei Maung <eimg@fairwayweb.com>
Copyright (c) 2026 Naing Lynn Aung <nainglynnaung.lynn@gmail.com>
```

---

## 🚀 Key Evolutions & Architecture Changelog (from Reference Project)

Famli expands upon the reference project with a comprehensive native Flutter port, enterprise-grade declarative security, upgraded visual design, and new interactive capabilities:

- **Flutter & Riverpod Rewrite**: Re-engineered from React Native to native Flutter (Dart) using Riverpod for declarative state management and GoRouter for declarative routing.
- **Dual-Backend Support**: Integrated Firebase (Firestore real-time streams + Firebase Auth) while retaining seamless compatibility with the reference Express REST API (`--dart-define=BACKEND=rest`).
- **Hardened Declarative Firestore Security Rules**: Fully declarative backend security (`firestore.rules`) enforcing role-based access control (RBAC), family isolation, tamper-proof point auditing, and Spark plan compatibility without requiring privileged server runtimes.
- **Dynamic Seed Balance & Point Aggregation Architecture**: Seed balances are calculated on-demand from verified task completion logs, streak logs, and parent point adjustments, supported by fast local caching to eliminate balance desynchronization.
- **Parent-Only Task Undo & Audit Trail**: Added an "Undo" action in Task History (`/history`) and the Parent Home dashboard ("Recent Wins"), enabling parents to revert mistakenly completed chores with confirmation dialogs, automatic seed balance rollback, and real-time child UI sync.
- **Real-World Timezone Auto-Sync**: Automatic device system timezone detection via `flutter_timezone` during parent registration and profile management, backed by a searchable bottom-sheet catalog featuring GMT offsets and country flags (e.g. 🇲🇲 Myanmar `Asia/Yangon` GMT+6:30, 🇹🇭 Thailand `Asia/Bangkok` GMT+7:00).
- **Dynamic "Seeds Left" Privilege Calculations**: Transparent privilege tracking that accurately calculates remaining seeds needed (`privilege.cost - availableSeeds`) so children know exactly how many seeds they still need to earn their rewards.
- **Interactive Onboarding Walkthrough**: A 3-slide animated onboarding experience with custom vector illustrations, smooth progress indicators, and role feature highlights.
- **Frosted Glassmorphism UI & Dark Theme Adaptability**: Implemented frosted navigation bars (`FrostedNavBar`) and sticky headers (`StickyTopBar`) featuring backdrop blurs, translucent tinting, specular borders, and blur-toggle fallbacks, fully styled for dark and light modes.
- **Reorganized Profile & Dedicated Security Screen**: Streamlined settings into 5 organized groups (Profile, Preferences, Security, Family Settings, Account), an icon-only theme switch (`[ ☀️ | 🌙 ]`) aligned with the language selector, and dedicated password update screens.
- **Account-Backed Preference Sync**: Instantaneous (0 ms) local cache for theme and language choices, backed by automatic cloud synchronization with user accounts.
- **Full Bilingual Localization**: Complete Myanmar and English language support across all screens, routine management, streak rewards, and notifications.
- **Custom Sprout Vector Animations**: Custom-painted organic sprout loading animations (`SproutLoadingIndicator`) replacing default progress spinners, featuring delay-aware reassuring status messages.
- **Role-Aware In-App Notification Center**: Notifies parents of completed tasks and child requests, and notifies children of streak rewards and point adjustments.

---

## ✨ Features Overview

### 👨‍👩‍👧‍👦 For Parents

- **Family Hub**: View all children, their active streak counts, and completed task summaries.
- **Task & Routine Management**: Create one-off assignments or recurring routine templates with customizable seed point values and active day schedules.
- **Chore Audit & Task Undo**: Review completed tasks in history or home dashboard and undo chores when necessary with automatic seed deductions.
- **Privilege Approvals**: Review, approve, or decline custom and family privileges requested by children using their earned seeds.
- **Family Timezone Settings**: Auto-sync family timezone with the device or pick a real-world location to ensure habit schedules remain accurate across timezones.

### 🧒 For Children

- **Today's Tasks & Routines**: Simple checklists to complete daily responsibilities and earn seeds.
- **Streak Rewards**: Earn bonus points for maintaining consecutive days of routine completion.
- **Privilege Marketplace**: Browse rewards with live "seeds left to earn" indicators and submit privilege requests using accumulated seed points.
- **Personalization**: Customize avatar tones, toggle dark/light theme, and switch between Myanmar and English.

---

## ⚠️ Current Limitations

While Famli offers a feature-complete family habit tracking workflow, several production considerations represent current limitations:

1. **File & Media Cloud Storage**:
   - Profile images and attachments currently utilize local application documents storage (`LocalStorageService`) on mobile/desktop and Base64 data URIs on web.
   - Remote cloud bucket storage (Firebase Cloud Storage, AWS S3, or Cloudflare R2) is architecturally abstracted via `ImageStorageService`, but requires cloud bucket provisioning and production credentials.
2. **Children's Mood & Kind Notes UI**:
   - Firestore security rules already support `/moodEntries` and `/users/{userId}/moodEntries` data schemas.
   - However, the interactive frontend user interface for children to log their daily emotional wellbeing and for parents to send encouraging "Kind Notes" is not yet implemented in the app screens.
3. **Headless Backend Scheduling & Cron Triggers**:
   - Daily routine active-day filters and streak evaluations currently run declaratively on client request rather than via automated serverless cron jobs or Cloud Functions.
4. **Push Notifications**:
   - The notification center operates within the app using reactive stream subscriptions.
   - Operating system-level background push notifications (Apple Push Notification service / Firebase Cloud Messaging) are not yet wired to production APNs/FCM developer certificates.
5. **Single Family Workspace Scope**:
   - Each user account belongs to a single family circle at a time. Multi-family switching (e.g. shared custody or co-parenting across separate households) is not yet supported.

---

## 🔮 Future Improvements & Roadmap

The following enhancements are planned for upcoming releases:

- **☁️ Cloud File & Photo Storage Integration**: Fully activate Firebase Cloud Storage / S3 / Cloudflare R2 with automatic client-side image compression, secure pre-signed uploads, and chore photo proof verification (children attaching photo proof of cleaned rooms/homework).
- **😊 Children's Mood & Emotional Wellbeing Tracker**: Build an interactive daily mood check-in (emoji mood selector, reflection notes) for children, alongside a "Kind Notes & Encouragement" board for parents to support their children's mental wellbeing.
- **⚡ Serverless Cloud Functions & Midnight Cron**: Deploy Cloud Functions for automated midnight streak rollovers, routine resets, and periodic weekly summary email digests for parents.
- **🔔 OS-Level Background Push Notifications**: Integrate background FCM and APNs push notifications with deep linking directly to pending task approvals and privilege tickets.
- **📊 Habit Analytics & Progress Charts**: Rich visual analytics showing weekly and monthly routine completion heatmaps, seed savings vs spending velocity, and category breakdowns.
- **🤝 Multi-Family Support & Shared Custody**: Allow children and parents to seamlessly belong to and switch between multiple family workspaces.
- **📶 Offline-First Synchronization Queue**: Robust local persistence with a background retry queue to log task completions and routine progress even without internet connectivity.

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
