import 'package:flutter/material.dart';

/// Shared bits reused across the app/(app) screens: the tone-colored avatar
/// dot, the pending/completed status pill, and the rounded card container.
const Map<String, Color> toneColors = {
  'sunrise': Color(0xFFFB923C),
  'forest': Color(0xFF22C55E),
  'ocean': Color(0xFF38BDF8),
  'lavender': Color(0xFFC084FC),
  'sunset': Color(0xFFF87171),
  'default': Color(0xFF94A3B8),
};

Color toneColor(String? tone) =>
    toneColors[tone ?? ''] ?? toneColors['default']!;

class AvatarDot extends StatelessWidget {
  const AvatarDot({super.key, this.tone, this.size = 10});

  final String? tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(color: toneColor(tone), shape: BoxShape.circle),
    );
  }
}

enum PillTone { pending, completed }

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = PillTone.pending,
  });

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = tone == PillTone.completed
        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
        : (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF));
    final textColor = tone == PillTone.completed
        ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534))
        : (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF312E81));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.color,
    this.border,
  });

  final Widget child;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = color ?? (isDark ? const Color(0xFF1E293B) : Colors.white);
    final cardBorder = border ?? (isDark ? const Color(0xFF334155) : null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: cardBorder != null ? Border.all(color: cardBorder) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionCardHeader extends StatelessWidget {
  const SectionCardHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class LightText extends StatelessWidget {
  const LightText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
    );
  }
}

String formatDueDateTime(DateTime dt) {
  final now = DateTime.now();
  final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
  final isTomorrow = dt.year == now.year && dt.month == now.month && dt.day == now.day + 1;
  final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final timeStr = '$hour:$minute $ampm';

  if (isToday) return 'Today, $timeStr';
  if (isTomorrow) return 'Tomorrow, $timeStr';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[dt.month - 1]} ${dt.day}, $timeStr';
}
