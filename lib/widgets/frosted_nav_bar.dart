import 'dart:ui';
import 'package:flutter/material.dart';

class FrostedNavItem {
  const FrostedNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// iOS 27 liquid frosted glass floating bottom navigation bar.
class FrostedNavBar extends StatelessWidget {
  const FrostedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.enableBlur = true,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FrostedNavItem> items;
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final innerContent = Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF64748B).withValues(alpha: 0.40)
                      : Colors.white.withValues(alpha: 0.70),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == currentIndex;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSelected) ...[
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF6366F1)
                                          .withValues(alpha: 0.28)
                                      : const Color(0xFF6C63FF)
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFFA5B4FC)
                                            .withValues(alpha: 0.35)
                                        : const Color(0xFF6C63FF)
                                            .withValues(alpha: 0.22),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  item.activeIcon,
                                  size: 20,
                                  color: isDark
                                      ? const Color(0xFFA5B4FC)
                                      : const Color(0xFF5B4DFF),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFA5B4FC)
                                      : const Color(0xFF4338CA),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ] else
                              Icon(
                                item.icon,
                                size: 24,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF6B7280),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : const Color(0xFF312E81).withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: enableBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: innerContent,
                )
              : innerContent,
        ),
      ),
    );
  }
}
