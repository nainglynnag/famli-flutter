import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/nudge_sync_provider.dart';
import 'providers/theme_provider.dart';
import 'routing/router.dart';

/// Mirrors mobile/app/_layout.tsx: root provider tree + navigator shell.
class FamliApp extends ConsumerWidget {
  const FamliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Mirrors <NudgeSyncProvider> wrapping the RN app root: reschedules
    // local nudge notifications whenever auth state changes.
    ref.watch(nudgeSyncProvider);

    return MaterialApp.router(
      title: 'Famli',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F5FF),
        cardColor: Colors.white,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF1E1B4B),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1E1B4B),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF4F4F4)),
          bodyMedium: TextStyle(color: Color(0xFFF4F4F4)),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: Color(0xFFF4F4F4)),
          labelLarge: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F172A),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
