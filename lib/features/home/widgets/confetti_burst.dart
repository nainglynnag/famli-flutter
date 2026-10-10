import 'dart:math';

import 'package:flutter/material.dart';

const _confettiColors = [
  Color(0xFFF97316),
  Color(0xFFFBBF24),
  Color(0xFF22C55E),
  Color(0xFF38BDF8),
  Color(0xFFC084FC),
];

class _Piece {
  _Piece(Random random)
    : left = random.nextDouble(),
      drift = random.nextDouble() * 80 - 40,
      fall = 140 + random.nextDouble() * 80,
      color = _confettiColors[random.nextInt(_confettiColors.length)],
      rotate = random.nextDouble() * 120 - 60;

  final double left;
  final double drift;
  final double fall;
  final Color color;
  final double rotate;
}

/// Mirrors the ConfettiBurst component in mobile/app/(app)/home.tsx: bump
/// [trigger] to fire a new burst (e.g. `trigger + 1` on task completion).
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.trigger});

  final int trigger;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<_Piece> _pieces = [];
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(covariant ConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger != 0) {
      final random = Random();
      setState(() {
        _pieces = List.generate(14, (_) => _Piece(random));
        _visible = true;
      });
      _controller
        ..reset()
        ..forward().whenComplete(() {
          if (mounted) setState(() => _visible = false);
        });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return IgnorePointer(
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: _pieces.map((piece) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final progress = _controller.value;
                    final opacity = progress < 0.8
                        ? 1.0
                        : (1 - (progress - 0.8) / 0.2).clamp(0.0, 1.0);
                    return Positioned(
                      left:
                          piece.left * constraints.maxWidth +
                          piece.drift * progress,
                      top: progress * piece.fall,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.rotate(
                          angle: piece.rotate * pi / 180,
                          child: Container(
                            width: 8,
                            height: 16,
                            decoration: BoxDecoration(
                              color: piece.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
