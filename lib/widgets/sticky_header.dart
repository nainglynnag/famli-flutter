import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/notifications_center_provider.dart';
import 'user_avatar.dart';

/// Reusable Sticky Top Header component pinned at the top of main screens.
class StickyTopBar extends ConsumerWidget {
  const StickyTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = false,
    this.onBack,
    this.showNotificationBell = true,
    this.trailing,
    this.enableBlur = true,
  });

  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool showNotificationBell;
  final Widget? trailing;
  final bool enableBlur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notifications = ref.watch(aggregatedNotificationsProvider);
    final centerState = ref.watch(notificationsCenterNotifierProvider);
    final unreadCount = notifications
        .where((n) => !centerState.readIds.contains(n.id))
        .length;

    final content = Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1B4B).withValues(alpha: 0.75)
            : Colors.white.withValues(alpha: 0.75),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFF475569).withValues(alpha: 0.35)
                : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
                children: [
                  if (showBackButton) ...[
                    OutlinedButton(
                      onPressed: onBack ??
                          () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/home');
                            }
                          },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF4B5563)
                              : const Color(0xFFD4D4D8),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '← Back',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFE5E7EB)
                              : const Color(0xFF4B5563),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1F2933),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                  if (showNotificationBell) ...[
                    const SizedBox(width: 8),
                    _NotificationBellButton(
                      unreadCount: unreadCount,
                      onPressed: () => _showNotificationSheet(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

    return ClipRect(
      child: enableBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: content,
            )
          : content,
    );
  }

  void _showNotificationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _NotificationCenterSheet(),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: isDark
                ? const Color(0xFF312E81).withValues(alpha: 0.6)
                : const Color(0xFFEDE9FE),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
          ),
          icon: Icon(
            Icons.notifications_outlined,
            color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4C1D95),
            size: 22,
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationCenterSheet extends ConsumerWidget {
  const _NotificationCenterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifications = ref.watch(aggregatedNotificationsProvider);
    final centerNotifier = ref.read(notificationsCenterNotifierProvider.notifier);
    final centerState = ref.watch(notificationsCenterNotifierProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFF6C63FF),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                if (notifications.isNotEmpty)
                  TextButton(
                    onPressed: () => centerNotifier.markAllAsRead(
                      notifications.map((n) => n.id),
                    ),
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: notifications.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 48,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      final isRead = centerState.readIds.contains(item.id);

                      return InkWell(
                        onTap: () {
                          centerNotifier.markAsRead(item.id);
                          if (item.route != null) {
                            Navigator.of(context).pop();
                            context.go(item.route!);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isRead
                                ? (isDark
                                    ? const Color(0xFF2E2A72).withValues(alpha: 0.3)
                                    : const Color(0xFFF9FAFB))
                                : (isDark
                                    ? const Color(0xFF312E81).withValues(alpha: 0.7)
                                    : const Color(0xFFEEF2FF)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isRead
                                  ? (isDark ? Colors.white12 : const Color(0xFFE5E7EB))
                                  : (isDark
                                      ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                                      : const Color(0xFFC7D2FE)),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLeadingIcon(item),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              fontWeight: isRead
                                                  ? FontWeight.w600
                                                  : FontWeight.w800,
                                              fontSize: 14,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1F2937),
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF6366F1),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.body,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? const Color(0xFFD1D5DB)
                                            : const Color(0xFF4B5563),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatTime(item.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white38
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingIcon(AppNotificationItem item) {
    if (item.childPhotoUrl != null || item.childAvatarTone != null) {
      return UserAvatarCircle(
        name: item.title,
        photoUrl: item.childPhotoUrl,
        avatarTone: item.childAvatarTone,
        size: 36,
      );
    }

    final (icon, color, bg) = switch (item.type) {
      NotificationType.taskCompleted => (
          Icons.check_circle_rounded,
          const Color(0xFF10B981),
          const Color(0xFFD1FAE5),
        ),
      NotificationType.childRequest => (
          Icons.vpn_key_rounded,
          const Color(0xFF8B5CF6),
          const Color(0xFFEDE9FE),
        ),
      NotificationType.pointsAdjustment => (
          Icons.card_giftcard_rounded,
          const Color(0xFFF59E0B),
          const Color(0xFFFEF3C7),
        ),
      NotificationType.privilegeDecision => (
          Icons.confirmation_number_rounded,
          const Color(0xFF06B6D4),
          const Color(0xFFCFFAFE),
        ),
      NotificationType.reward => (
          Icons.local_fire_department_rounded,
          const Color(0xFFEF4444),
          const Color(0xFFFEE2E2),
        ),
      NotificationType.assignment => (
          Icons.assignment_rounded,
          const Color(0xFF6366F1),
          const Color(0xFFE0E7FF),
        ),
      NotificationType.reminder => (
          Icons.alarm_rounded,
          const Color(0xFFEC4899),
          const Color(0xFFFCE7F3),
        ),
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}
