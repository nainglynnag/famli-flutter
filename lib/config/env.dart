import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options_dev.dart' as dev;

/// Which Firebase project (or emulator) this build talks to.
/// See daily-buddies/FIREBASE_ENVIRONMENTS.md.
enum FirebaseEnv { local, dev, staging, prod }

/// Mirrors mobile/src/config/env.ts: resolves the API base URL per platform,
/// rewriting localhost to the Android emulator's host alias.
class Env {
  Env._();

  static const String _defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    if (_defaultApiBaseUrl.isNotEmpty) {
      return _normalizeBaseUrl(_defaultApiBaseUrl);
    }
    return 'http://$_fallbackHost:4000/api';
  }

  static String get _fallbackHost {
    if (!kIsWeb && Platform.isAndroid) {
      return '10.0.2.2';
    }
    return 'localhost';
  }

  static String _normalizeBaseUrl(String value) {
    if (!kIsWeb && Platform.isAndroid) {
      if (value.contains('localhost')) {
        return value.replaceAll('localhost', '10.0.2.2');
      }
      if (value.contains('127.0.0.1')) {
        return value.replaceAll('127.0.0.1', '10.0.2.2');
      }
    }
    return value;
  }

  static const String authStorageKey = 'famli-auth-token';
  static const String legacyAuthStorageKey = 'daily-buddies-auth-token';
  static const String languageStorageKey = 'famli-language';
  static const String legacyLanguageStorageKey = 'daily-buddies-language';
  static const String themeModeStorageKey = 'famli-theme-mode';
  static const String readNotificationsStorageKey = 'famli-read-notifications';
  static const String parentReminderStorageKey = 'famli-parent-missing-task-reminder';

  // ---- Storage Provider ----
  static const String _storageProvider = String.fromEnvironment(
    'STORAGE_PROVIDER',
    defaultValue: 'local',
  );

  /// Which image storage provider to use: 'local', 's3', or 'firebase'.
  static String get storageProvider => _storageProvider.toLowerCase();
  static bool get useLocalStorage => storageProvider == 'local';
  static bool get useS3Storage => storageProvider == 's3';
  static bool get useFirebaseStorage => storageProvider == 'firebase';

  // S3 safe configuration slots (can be populated via .env or --dart-define)
  static const String s3Bucket = String.fromEnvironment('S3_BUCKET', defaultValue: '');
  static const String s3Region = String.fromEnvironment('S3_REGION', defaultValue: '');
  static const String s3Endpoint = String.fromEnvironment('S3_ENDPOINT', defaultValue: '');

  // ---- Firebase ----

  static const String _firebaseEnv = String.fromEnvironment(
    'FIREBASE_ENV',
    defaultValue: 'local',
  );

  /// Defaults to `local` so a build with no flag hits the emulators rather
  /// than a real project. Pass --dart-define=FIREBASE_ENV=dev to target the
  /// cloud project.
  static FirebaseEnv get firebaseEnv => switch (_firebaseEnv) {
    'prod' => FirebaseEnv.prod,
    'staging' => FirebaseEnv.staging,
    'dev' => FirebaseEnv.dev,
    _ => FirebaseEnv.local,
  };

  /// `local` still needs a valid options object to initialize the SDK, so it
  /// reuses the dev project's config and then redirects to the emulators.
  static FirebaseOptions get firebaseOptions =>
      dev.DefaultFirebaseOptions.currentPlatform;

  static bool get useEmulators => firebaseEnv == FirebaseEnv.local;

  /// Same rewrite as [_fallbackHost]: the Android emulator reaches the host
  /// machine at 10.0.2.2, not localhost.
  static String get emulatorHost => _fallbackHost;

  // ---- Backend selection ----

  static const String _backend = String.fromEnvironment(
    'BACKEND',
    defaultValue: 'firebase',
  );

  /// Which backend the app talks to, so both can run side by side during
  /// cutover (FIREBASE_MIGRATION_PLAN.md Phase 5). Build with
  /// --dart-define=BACKEND=rest to fall back to the Express API in
  /// daily-buddies/api without editing code.
  static bool get useFirebaseBackend => _backend != 'rest';
}
