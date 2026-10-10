import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Standard sizes for SproutLoadingIndicator.
class SproutLoadingSize {
  const SproutLoadingSize._();
  static const double mini = 18.0;
  static const double small = 24.0;
  static const double medium = 44.0;
  static const double large = 72.0;
  static const double hero = 96.0;
}

/// A vibrant, organic sprout-shaped circular loading animation.
///
/// Features:
/// - A continuous 360-degree rotating gradient halo arc.
/// - An orbiting glowing seed droplet at the leading edge.
/// - An inner central sprout with gentle breathing scale and swaying cotyledon leaves.
/// - Fluid vector-based rendering with 60/120 FPS hardware acceleration.
class SproutLoadingIndicator extends StatefulWidget {
  const SproutLoadingIndicator({
    super.key,
    this.size = SproutLoadingSize.medium,
    this.color,
    this.strokeWidth,
    this.showAura = false,
  });

  /// The width and height of the loading circle.
  final double size;

  /// Optional override color for the arc and sprout. If null, a lush multi-stop
  /// gradient (brand indigo -> emerald -> spring green -> gold) is used.
  final Color? color;

  /// Thickness of the outer circular arc. Defaults to a proportional ratio.
  final double? strokeWidth;

  /// Whether to render a soft ambient pulsing aura behind the circle.
  final bool showAura;

  @override
  State<SproutLoadingIndicator> createState() => _SproutLoadingIndicatorState();
}

class _SproutLoadingIndicatorState extends State<SproutLoadingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _swayController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _swayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stroke = widget.strokeWidth ?? math.max(2.0, widget.size * 0.08);

    return AnimatedBuilder(
      animation: Listenable.merge([_rotationController, _swayController]),
      builder: (context, child) {
        final rotationValue = _rotationController.value;
        final swayValue = _swayController.value;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Optional Ambient Pulsing Aura
              if (widget.showAura)
                Transform.scale(
                  scale: 1.0 + (math.sin(swayValue * math.pi) * 0.08),
                  child: Container(
                    width: widget.size * 1.15,
                    height: widget.size * 1.15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (widget.color ?? AppColors.brandPrimary).withValues(
                            alpha: isDark ? 0.35 : 0.20,
                          ),
                          (widget.color ?? AppColors.progressEmerald).withValues(
                            alpha: isDark ? 0.15 : 0.08,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),

              // Vector Sprout + Circular Halo
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _SproutPainter(
                  rotationProgress: rotationValue,
                  swayProgress: swayValue,
                  strokeWidth: stroke,
                  overrideColor: widget.color,
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

class _SproutPainter extends CustomPainter {
  _SproutPainter({
    required this.rotationProgress,
    required this.swayProgress,
    required this.strokeWidth,
    required this.overrideColor,
    required this.isDark,
  });

  final double rotationProgress;
  final double swayProgress;
  final double strokeWidth;
  final Color? overrideColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    if (radius <= 0) return;

    // -------------------------------------------------------------------------
    // 1. Draw Subtle Background Track
    // -------------------------------------------------------------------------
    final trackPaint = Paint()
      ..color = (overrideColor ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)))
          .withValues(alpha: isDark ? 0.25 : 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // -------------------------------------------------------------------------
    // 2. Draw Orbiting Gradient Halo Arc
    // -------------------------------------------------------------------------
    final startAngle = rotationProgress * 2 * math.pi;
    const sweepAngle = math.pi * 1.45; // ~260 degrees arc

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (overrideColor != null) {
      arcPaint.color = overrideColor!;
    } else {
      arcPaint.shader = SweepGradient(
        startAngle: 0.0,
        endAngle: 2 * math.pi,
        colors: const [
          Color(0xFF6C63FF), // Indigo
          Color(0xFF10B981), // Emerald
          Color(0xFF22C55E), // Spring Green
          Color(0xFFF59E0B), // Warm Gold
          Color(0xFF6C63FF), // Wrap Indigo
        ],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // -------------------------------------------------------------------------
    // 3. Orbiting Seed Droplet at the Leading Tip
    // -------------------------------------------------------------------------
    final leadingAngle = startAngle + sweepAngle;
    final tipCenter = Offset(
      center.dx + radius * math.cos(leadingAngle),
      center.dy + radius * math.sin(leadingAngle),
    );

    final dropletPaint = Paint()
      ..color = overrideColor ?? const Color(0xFF22C55E)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(tipCenter, strokeWidth * 0.9, dropletPaint);

    // -------------------------------------------------------------------------
    // 4. Center Sprout (Stem & Unfurling Cotyledon Leaves)
    // -------------------------------------------------------------------------
    _paintCenterSprout(canvas, center, size);
  }

  void _paintCenterSprout(Canvas canvas, Offset center, Size size) {
    // Sprout dimensions relative to widget size
    final sproutScale = size.width / 44.0;
    final swayAngle = (swayProgress - 0.5) * 0.25; // Gentle sway (-0.12 to +0.12 rad)
    final breathScale = 0.95 + (math.sin(swayProgress * math.pi) * 0.08);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(sproutScale * breathScale);
    canvas.rotate(swayAngle);

    final stemColor = overrideColor ?? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A));
    final leafLeftColor = overrideColor ?? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF22C55E));
    final leafRightColor = overrideColor ?? (isDark ? const Color(0xFFBBF7D0) : const Color(0xFF10B981));
    final seedColor = overrideColor ?? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));

    // A. Tiny Root / Seed Base
    final seedPaint = Paint()
      ..color = seedColor
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 9.0), width: 5.5, height: 3.5),
      seedPaint,
    );

    // B. Stem Curve
    final stemPaint = Paint()
      ..color = stemColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, 2.2 * (strokeWidth / 3.5))
      ..strokeCap = StrokeCap.round;

    final stemPath = Path()
      ..moveTo(0, 8.5)
      ..quadraticBezierTo(-1.5, 2.0, 0, -3.5);
    canvas.drawPath(stemPath, stemPaint);

    // C. Left Cotyledon Leaf
    final leftLeafPath = Path()
      ..moveTo(0, -2.0)
      ..cubicTo(-6.0, -4.5, -9.5, -1.0, -8.0, 3.0)
      ..cubicTo(-5.5, 4.0, -1.5, 1.5, 0, -2.0);

    final leftLeafPaint = Paint()
      ..color = leafLeftColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(leftLeafPath, leftLeafPaint);

    // D. Right Cotyledon Leaf (Slightly higher, unfurling right)
    final rightLeafPath = Path()
      ..moveTo(0, -3.5)
      ..cubicTo(6.5, -7.0, 10.5, -3.0, 8.5, 1.5)
      ..cubicTo(6.0, 2.5, 1.8, 0.0, 0, -3.5);

    final rightLeafPaint = Paint()
      ..color = leafRightColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(rightLeafPath, rightLeafPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SproutPainter oldDelegate) {
    return oldDelegate.rotationProgress != rotationProgress ||
        oldDelegate.swayProgress != swayProgress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.overrideColor != overrideColor ||
        oldDelegate.isDark != isDark;
  }
}

/// A complete, centered screen/container loading view that presents
/// the [SproutLoadingIndicator], an optional title message, and automatically
/// provides friendly, reassuring feedback if network delays occur.
class SproutLoadingView extends StatefulWidget {
  const SproutLoadingView({
    super.key,
    this.message,
    this.subtitle,
    this.size = SproutLoadingSize.large,
    this.showNetworkDelayHint = true,
    this.delayThreshold = const Duration(milliseconds: 2000),
    this.padding = const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
  });

  /// Primary loading label, e.g. "Preparing Famli...", "Loading tasks...".
  final String? message;

  /// Optional secondary subtitle.
  final String? subtitle;

  /// Size of the sprout loading circle.
  final double size;

  /// Whether to automatically show a gentle note if data fetching is delayed.
  final bool showNetworkDelayHint;

  /// Duration after which the network delay hint appears.
  final Duration delayThreshold;

  /// Outer padding for the view.
  final EdgeInsets padding;

  @override
  State<SproutLoadingView> createState() => _SproutLoadingViewState();
}

class _SproutLoadingViewState extends State<SproutLoadingView> {
  bool _isDelayed = false;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.showNetworkDelayHint) {
      _delayTimer = Timer(widget.delayThreshold, () {
        if (mounted) setState(() => _isDelayed = true);
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: widget.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SproutLoadingIndicator(
              size: widget.size,
              showAura: widget.size >= SproutLoadingSize.medium,
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: widget.size >= SproutLoadingSize.large ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
            if (widget.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
            // Gentle network delay reassurance
            if (_isDelayed)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🌿', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Still connected and growing... thanks for your patience!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A modal or fullscreen loading barrier for blocking mutations
/// (e.g., photo upload or account deletion).
class SproutLoadingOverlay extends StatelessWidget {
  const SproutLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: SproutLoadingView(
                message: message,
                size: SproutLoadingSize.large,
              ),
            ),
          ),
      ],
    );
  }
}
