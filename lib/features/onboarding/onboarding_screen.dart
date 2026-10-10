import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../providers/i18n_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../auth/widgets/language_toggle.dart';
import 'widgets/onboarding_graphics.dart';

/// Interactive 5-slide Onboarding flow introducing the Famli application
/// with custom animated vector illustrations, micro-badges, and localization.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleComplete({String destination = '/login'}) async {
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go(destination);
    }
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _handleComplete();
    }
  }

  Color _getAmbientColor(List<_SlideData> slides) {
    if (!_pageController.hasClients || !_pageController.position.haveDimensions) {
      return slides[_currentPage.clamp(0, slides.length - 1)].themeColor;
    }
    final page = _pageController.page ?? _currentPage.toDouble();
    final lowerIndex = page.floor().clamp(0, slides.length - 1);
    final upperIndex = page.ceil().clamp(0, slides.length - 1);
    final progress = (page - lowerIndex).clamp(0.0, 1.0);
    return Color.lerp(
          slides[lowerIndex].themeColor,
          slides[upperIndex].themeColor,
          progress,
        ) ??
        slides[0].themeColor;
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final slides = [
      _SlideData(
        hero: const FamliBloomHero(),
        titleKey: 'onboarding.slide1Title',
        subtitleKey: 'onboarding.slide1Subtitle',
        badges: [
          t.t('onboarding.slide1Badge1'),
          t.t('onboarding.slide1Badge2'),
          t.t('onboarding.slide1Badge3'),
        ],
        themeColor: const Color(0xFF6C63FF),
      ),
      _SlideData(
        hero: const ParentDashboardHero(),
        titleKey: 'onboarding.slide2Title',
        subtitleKey: 'onboarding.slide2Subtitle',
        badges: [
          t.t('onboarding.slide2Badge1'),
          t.t('onboarding.slide2Badge2'),
          t.t('onboarding.slide2Badge3'),
        ],
        themeColor: const Color(0xFF2563EB),
      ),
      _SlideData(
        hero: const CoParentingHero(),
        titleKey: 'onboarding.slide3Title',
        subtitleKey: 'onboarding.slide3Subtitle',
        badges: [
          t.t('onboarding.slide3Badge1'),
          t.t('onboarding.slide3Badge2'),
          t.t('onboarding.slide3Badge3'),
        ],
        themeColor: const Color(0xFF8B5CF6),
      ),
      _SlideData(
        hero: const GamificationShowcaseHero(),
        titleKey: 'onboarding.slide4Title',
        subtitleKey: 'onboarding.slide4Subtitle',
        badges: [
          t.t('onboarding.slide4Badge1'),
          t.t('onboarding.slide4Badge2'),
          t.t('onboarding.slide4Badge3'),
        ],
        themeColor: const Color(0xFFF59E0B),
      ),
      _SlideData(
        hero: const PrivilegeTicketHero(),
        titleKey: 'onboarding.slide5Title',
        subtitleKey: 'onboarding.slide5Subtitle',
        badges: [
          t.t('onboarding.slide5Badge1'),
          t.t('onboarding.slide5Badge2'),
          t.t('onboarding.slide5Badge3'),
        ],
        themeColor: const Color(0xFF10B981),
      ),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF8FF),
      body: AnimatedBuilder(
        animation: _pageController,
        builder: (context, _) {
          final ambientColor = _getAmbientColor(slides);

          return Stack(
            children: [
              // Dynamic Ambient Lighting Aura
              Positioned(
                top: -80,
                left: 0,
                right: 0,
                height: 380,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.4),
                        radius: 0.95,
                        colors: [
                          ambientColor.withValues(alpha: isDark ? 0.22 : 0.12),
                          ambientColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Top Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Famli Brand Pill
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ambientColor.withValues(alpha: 0.15),
                                ),
                                child: const Text('🌱', style: TextStyle(fontSize: 16)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Famli',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                                ),
                              ),
                            ],
                          ),

                          // Actions: Language Toggle + Skip
                          Row(
                            children: [
                              const LanguageToggle(),
                              const SizedBox(width: 8),
                              if (_currentPage < 4)
                                TextButton(
                                  onPressed: () => _handleComplete(),
                                  style: TextButton.styleFrom(
                                    foregroundColor: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                  ),
                                  child: Text(
                                    t.t('onboarding.skip'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(width: 48),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Main Slides Carousel with Layered Parallax & Scaling Transitions
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: slides.length,
                        onPageChanged: (index) => setState(() => _currentPage = index),
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final slide = slides[index];

                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double pageOffset = 0.0;
                              if (_pageController.hasClients &&
                                  _pageController.position.haveDimensions) {
                                pageOffset = (index -
                                    (_pageController.page ?? _currentPage.toDouble()));
                              } else {
                                pageOffset = (index - _currentPage).toDouble();
                              }

                              final clampedOffset = pageOffset.clamp(-1.0, 1.0);
                              final absOffset = clampedOffset.abs();
                              final centerProgress = (1.0 - absOffset).clamp(0.0, 1.0);

                              // Multi-layer parallax depth
                              final heroScale = 0.88 + (0.12 * centerProgress);
                              final heroTranslation = clampedOffset * -44.0;
                              final textTranslation = clampedOffset * -22.0;
                              final badgeTranslation = clampedOffset * -12.0;
                              final opacity = (centerProgress * centerProgress).clamp(0.0, 1.0);

                              return Opacity(
                                opacity: opacity,
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Animated Hero Graphic with Parallax & Scale
                                      Transform.translate(
                                        offset: Offset(heroTranslation, 0),
                                        child: Transform.scale(
                                          scale: heroScale,
                                          child: slide.hero,
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      // Title & Subtitle with Text Parallax
                                      Transform.translate(
                                        offset: Offset(textTranslation, 0),
                                        child: Column(
                                          children: [
                                            Text(
                                              t.t(slide.titleKey),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.5,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1E1B4B),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              t.t(slide.subtitleKey),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14,
                                                height: 1.45,
                                                color: isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      // Key Value Badges with Staggered Parallax
                                      Transform.translate(
                                        offset: Offset(badgeTranslation, 0),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.center,
                                          children: slide.badges.map((badge) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF1E293B)
                                                    : const Color(0xFFF1F0FE),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isDark
                                                      ? const Color(0xFF334155)
                                                      : const Color(0xFFE0E7FF),
                                                ),
                                              ),
                                              child: Text(
                                                badge,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? const Color(0xFFCBD5E1)
                                                      : const Color(0xFF4338CA),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // Bottom Navigation Area
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Dynamic Active Page Indicator Pill
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(slides.length, (i) {
                              final isActive = i == _currentPage;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: isActive ? 28 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: isActive
                                      ? LinearGradient(
                                          colors: [
                                            ambientColor,
                                            ambientColor.withValues(alpha: 0.8),
                                          ],
                                        )
                                      : null,
                                  color: isActive
                                      ? null
                                      : (isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFCBD5E1)),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 20),

                          // Action Buttons
                          if (_currentPage < 4) ...[
                            // Next Button with Dynamic Accent Color
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: _nextPage,
                                style: FilledButton.styleFrom(
                                  backgroundColor: ambientColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 2,
                                  shadowColor: ambientColor.withValues(alpha: 0.35),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      t.t('onboarding.next'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            // Get Started Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: () => _handleComplete(destination: '/login'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: ambientColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 3,
                                  shadowColor: ambientColor.withValues(alpha: 0.4),
                                ),
                                child: Text(
                                  t.t('onboarding.getStarted'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Secondary Link: Sign In
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  t.t('onboarding.alreadyHaveAccount'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _handleComplete(destination: '/login'),
                                  child: Text(
                                    t.t('onboarding.signIn'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: ambientColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SlideData {
  _SlideData({
    required this.hero,
    required this.titleKey,
    required this.subtitleKey,
    required this.badges,
    required this.themeColor,
  });

  final Widget hero;
  final String titleKey;
  final String subtitleKey;
  final List<String> badges;
  final Color themeColor;
}
