import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import 'child_home.dart';
import 'parent_home.dart';

/// Mirrors mobile/app/(app)/home.tsx: routes to the parent or child view
/// based on the signed-in profile's role.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).value?.profile;

    if (profile == null) {
      return const SizedBox.shrink();
    }

    return profile.role == UserRole.parent
        ? ParentHome(profile: profile)
        : ChildHome(profile: profile);
  }
}
