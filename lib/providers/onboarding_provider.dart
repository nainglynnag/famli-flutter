import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/secure_storage.dart';

final onboardingProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

class OnboardingNotifier extends AsyncNotifier<bool> {
  final SecureStorage _storage = SecureStorage();
  static const String _key = 'famli-seen-onboarding';

  @override
  Future<bool> build() async {
    final value = await _storage.read(_key);
    return value == 'true';
  }

  /// Mark onboarding as completed so future app launches go straight to login/home.
  Future<void> completeOnboarding() async {
    await _storage.write(_key, 'true');
    state = const AsyncData(true);
  }

  /// Reset onboarding state to allow replaying from profile/settings.
  Future<void> resetOnboarding() async {
    await _storage.write(_key, 'false');
    state = const AsyncData(false);
  }
}
