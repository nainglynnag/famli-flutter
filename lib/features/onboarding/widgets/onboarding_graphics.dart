import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Hero Graphic 1: Famli Blooming Seed & Harmony Orb
/// ---------------------------------------------------------------------------
class FamliBloomHero extends StatefulWidget {
  const FamliBloomHero({super.key});

  @override
  State<FamliBloomHero> createState() => _FamliBloomHeroState();
}

class _FamliBloomHeroState extends State<FamliBloomHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final float1 = math.sin(t * math.pi) * 8;
        final float2 = math.cos(t * math.pi) * 6;
        final scalePulse = 1.0 + (math.sin(t * math.pi * 2) * 0.04);

        return SizedBox(
          width: 320,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient Glowing Aura
              Container(
                width: 220 * scalePulse,
                height: 220 * scalePulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6C63FF).withValues(alpha: isDark ? 0.35 : 0.22),
                      const Color(0xFFC084FC).withValues(alpha: isDark ? 0.18 : 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.65, 1.0],
                  ),
                ),
              ),

              // Orbiting ambient ring
              Transform.rotate(
                angle: t * math.pi * 0.25,
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
              ),

              // Central Blooming Emblem
              Transform.scale(
                scale: scalePulse,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF818CF8),
                        Color(0xFF6366F1),
                        Color(0xFF4F46E5),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                        blurRadius: 28,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '🌱',
                      style: TextStyle(fontSize: 54),
                    ),
                  ),
                ),
              ),

              // Floating Chip 1: Healthy Habits
              Positioned(
                top: 24 + float1,
                left: 10,
                child: _FloatingBadge(
                  icon: Icons.eco_rounded,
                  iconColor: const Color(0xFF22C55E),
                  label: 'Healthy Habits',
                  isDark: isDark,
                ),
              ),

              // Floating Chip 2: Family Harmony
              Positioned(
                bottom: 28 + float2,
                left: 20,
                child: _FloatingBadge(
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFF43F5E),
                  label: 'Family Harmony',
                  isDark: isDark,
                ),
              ),

              // Floating Chip 3: Shared Growth
              Positioned(
                top: 48 - float2,
                right: 8,
                child: _FloatingBadge(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFFFBBF24),
                  label: 'Shared Growth',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// Hero Graphic 2: Parent Command Center Dashboard Preview
/// ---------------------------------------------------------------------------
class ParentDashboardHero extends StatefulWidget {
  const ParentDashboardHero({super.key});

  @override
  State<ParentDashboardHero> createState() => _ParentDashboardHeroState();
}

class _ParentDashboardHeroState extends State<ParentDashboardHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final float = math.sin(t * math.pi) * 6;

        return SizedBox(
          width: 320,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dashboard Card Preview
              Transform.translate(
                offset: Offset(0, float * 0.5),
                child: Container(
                  width: 290,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.space_dashboard_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Family Hub',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '2 Children Active',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.repeat_rounded, size: 12, color: Color(0xFF6C63FF)),
                                SizedBox(width: 4),
                                Text(
                                  'Daily',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6C63FF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Child Progress Rows
                      _ChildProgressItem(
                        name: 'Leo',
                        avatarColor: const Color(0xFF22C55E),
                        taskCount: '4/5 Tasks',
                        progress: 0.8,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _ChildProgressItem(
                        name: 'Emma',
                        avatarColor: const Color(0xFFFB923C),
                        taskCount: '3/4 Tasks',
                        progress: 0.75,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),

                      // Sample checklist item
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Morning Teeth & Bed Routine',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '+2 🌱',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating tag badge
              Positioned(
                top: 8 + float,
                right: 4,
                child: _FloatingBadge(
                  icon: Icons.person_add_alt_1_rounded,
                  iconColor: const Color(0xFF6366F1),
                  label: 'Personalized for Each',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChildProgressItem extends StatelessWidget {
  const _ChildProgressItem({
    required this.name,
    required this.avatarColor,
    required this.taskCount,
    required this.progress,
    required this.isDark,
  });

  final String name;
  final Color avatarColor;
  final String taskCount;
  final double progress;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: avatarColor.withValues(alpha: 0.2),
          child: Text(
            name[0],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: avatarColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    taskCount,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation(avatarColor),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Hero Graphic 3: Co-Parenting in Harmony (Dual Parents Synchronized)
/// ---------------------------------------------------------------------------
class CoParentingHero extends StatefulWidget {
  const CoParentingHero({super.key});

  @override
  State<CoParentingHero> createState() => _CoParentingHeroState();
}

class _CoParentingHeroState extends State<CoParentingHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final float = math.sin(t * math.pi) * 8;
        final pulse = 1.0 + (math.sin(t * math.pi * 2) * 0.05);

        return SizedBox(
          width: 320,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Connecting Pulsing Beam
              Container(
                width: 220,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.8),
                      const Color(0xFFC084FC).withValues(alpha: 0.9),
                      const Color(0xFFF472B6).withValues(alpha: 0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC084FC).withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),

              // Center Sync Badge
              Transform.scale(
                scale: pulse,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC084FC), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC084FC).withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_rounded, size: 16, color: const Color(0xFF8B5CF6)),
                      const SizedBox(width: 6),
                      Text(
                        '100% In-Sync',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Parent 1 (Mom)
              Positioned(
                left: 20,
                child: Transform.translate(
                  offset: Offset(0, -float),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF472B6), Color(0xFFE11D48)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('👩', style: TextStyle(fontSize: 34)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mom',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Parent 2 (Dad)
              Positioned(
                right: 20,
                child: Transform.translate(
                  offset: Offset(0, float),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('👨', style: TextStyle(fontSize: 34)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dad',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating activity card: Mom approved
              Positioned(
                top: 24 + float * 0.5,
                left: 14,
                child: _FloatingBadge(
                  icon: Icons.task_alt_rounded,
                  iconColor: const Color(0xFF22C55E),
                  label: 'Mom verified task',
                  isDark: isDark,
                ),
              ),

              // Floating activity card: Dad granted privilege
              Positioned(
                bottom: 24 - float * 0.5,
                right: 14,
                child: _FloatingBadge(
                  icon: Icons.confirmation_number_rounded,
                  iconColor: const Color(0xFFFB923C),
                  label: 'Dad approved reward',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// Hero Graphic 4: Endless Customizations (Streaks, Nudges & Gifts)
/// ---------------------------------------------------------------------------
class GamificationShowcaseHero extends StatefulWidget {
  const GamificationShowcaseHero({super.key});

  @override
  State<GamificationShowcaseHero> createState() =>
      _GamificationShowcaseHeroState();
}

class _GamificationShowcaseHeroState extends State<GamificationShowcaseHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final float = math.sin(t * math.pi) * 7;
        final flamePulse = 1.0 + (math.sin(t * math.pi * 3) * 0.08);

        return SizedBox(
          width: 320,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Radiant Flame Glow
              Container(
                width: 170 * flamePulse,
                height: 170 * flamePulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF97316).withValues(alpha: isDark ? 0.45 : 0.28),
                      const Color(0xFFFBBF24).withValues(alpha: isDark ? 0.20 : 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Central Streak Flame Bubble
              Transform.scale(
                scale: flamePulse,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFFBBF24)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF97316).withValues(alpha: 0.5),
                        blurRadius: 26,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🔥', style: TextStyle(fontSize: 48)),
                  ),
                ),
              ),

              // Streak Banner
              Positioned(
                bottom: 50 + float * 0.4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF97316), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '7-Day Streak! +20 Seeds',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Left: Gentle Nudge Reminder Card
              Positioned(
                top: 24 + float,
                left: 10,
                child: _FloatingBadge(
                  icon: Icons.notifications_active_rounded,
                  iconColor: const Color(0xFF6C63FF),
                  label: 'Nudge: 20:00 Bedtime ⏰',
                  isDark: isDark,
                ),
              ),

              // Right: Surprise Gift Card
              Positioned(
                top: 36 - float,
                right: 10,
                child: _FloatingBadge(
                  icon: Icons.card_giftcard_rounded,
                  iconColor: const Color(0xFFEC4899),
                  label: 'Kindness Gift +5 🌱',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// Hero Graphic 5: Children Privileges & Gold Ticket Redemption
/// ---------------------------------------------------------------------------
class PrivilegeTicketHero extends StatefulWidget {
  const PrivilegeTicketHero({super.key});

  @override
  State<PrivilegeTicketHero> createState() => _PrivilegeTicketHeroState();
}

class _PrivilegeTicketHeroState extends State<PrivilegeTicketHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final float = math.sin(t * math.pi) * 6;

        return SizedBox(
          width: 320,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ticket Container
              Transform.translate(
                offset: Offset(0, float * 0.5),
                child: Container(
                  width: 270,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                          : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFFBBF24),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Text('🎟️', style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Privilege Ticket',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF92400E),
                                        ),
                                      ),
                                      Text(
                                        'Trade Seeds for Joy',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '25 🌱',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Perforated separator
                      Row(
                        children: List.generate(
                          18,
                          (i) => Expanded(
                            child: Container(
                              height: 1.5,
                              color: i.isEven
                                  ? const Color(0xFFFBBF24).withValues(alpha: 0.7)
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Reward Title
                      Text(
                        'Weekend Movie Night & Popcorn 🍿',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF78350F),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Stamp: APPROVED
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF22C55E),
                            width: 1.5,
                          ),
                        ),
                        child: const Text(
                          'APPROVED BY PARENTS! 🎉',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating Seed Coin
              Positioned(
                top: 20 + float,
                right: 12,
                child: _FloatingBadge(
                  icon: Icons.stars_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'Balance: 120 🌱',
                  isDark: isDark,
                ),
              ),

              // Floating Confetti Tag
              Positioned(
                bottom: 24 - float,
                left: 12,
                child: _FloatingBadge(
                  icon: Icons.celebration_rounded,
                  iconColor: const Color(0xFFEC4899),
                  label: 'Kids Earn & Choose',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// Shared Glassmorphic Floating Badge Widget
/// ---------------------------------------------------------------------------
class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.90)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
