import 'package:flutter/material.dart';

import '../core/storage/image_storage_service.dart';
import '../models/user.dart';
import 'common.dart';

/// Reusable user profile circle displaying an uploaded image or initial caps
/// letters with avatar tone background, and an optional parent/child status badge.
class UserAvatarCircle extends StatelessWidget {
  const UserAvatarCircle({
    super.key,
    required this.name,
    this.photoUrl,
    this.avatarTone,
    this.role,
    this.size = 40,
    this.showRoleBadge = false,
    this.borderColor,
    this.borderWidth = 0,
  });

  final String name;
  final String? photoUrl;
  final String? avatarTone;
  final UserRole? role;
  final double size;
  final bool showRoleBadge;
  final Color? borderColor;
  final double borderWidth;

  static String getInitials(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final second = parts[1].isNotEmpty ? parts[1][0] : '';
    final initials = '$first$second'.toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = resolveProfileImageProvider(photoUrl);
    final bgColor = toneColor(avatarTone);
    final initials = getInitials(name);
    final badgeSize = (size * 0.32).clamp(10.0, 18.0);

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? Colors.white,
                width: borderWidth,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: imageProvider != null
            ? Image(
                image: imageProvider,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _InitialsFallback(
                  initials: initials,
                  size: size,
                  bgColor: bgColor,
                ),
              )
            : _InitialsFallback(
                initials: initials,
                size: size,
                bgColor: bgColor,
              ),
      ),
    );

    if (!showRoleBadge || role == null) {
      return avatar;
    }

    final isParent = role == UserRole.parent;
    final badgeBg = isParent ? const Color(0xFF4F46E5) : const Color(0xFF0284C7);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(
              isParent ? Icons.shield : Icons.face,
              color: Colors.white,
              size: badgeSize * 0.65,
            ),
          ),
        ),
      ],
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({
    required this.initials,
    required this.size,
    required this.bgColor,
  });

  final String initials;
  final double size;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: bgColor,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: (size * 0.40).clamp(10.0, 36.0),
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
