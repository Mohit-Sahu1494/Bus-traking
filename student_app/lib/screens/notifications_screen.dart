import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/live_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await context.read<LiveProvider>().loadNotifications();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveProvider>();
    final list = live.notifications;
    final unreadCount = live.unreadNotificationsCount;

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                for (final n in list) {
                  final id = (n['_id'] ?? n['id'])?.toString();
                  if (id != null && n['readAt'] == null) {
                    await live.markNotificationRead(id);
                  }
                }
              },
              child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 46,
                            color: AppTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Live alerts for bus arrivals, route skips, and schedule updates will appear here in real time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, s) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final n = list[i];
                    final id = (n['_id'] ?? n['id'])?.toString() ?? '';
                    final title = n['title']?.toString() ?? 'Notification';
                    final body = n['body']?.toString() ?? '';
                    final type = n['type']?.toString() ?? '';
                    final isRead = n['readAt'] != null;
                    final createdAt = DateTime.tryParse(n['createdAt']?.toString() ?? '');

                    // Select icon & color based on event type
                    IconData iconData = Icons.notifications_rounded;
                    Color iconColor = AppTheme.accent;
                    Color bgColor = const Color(0xFFEFF6FF);

                    if (type.contains('SKIPPED')) {
                      iconData = Icons.warning_amber_rounded;
                      iconColor = AppTheme.coral;
                      bgColor = const Color(0xFFFEF2F2);
                    } else if (type.contains('ARRIVED')) {
                      iconData = Icons.check_circle_rounded;
                      iconColor = AppTheme.emerald;
                      bgColor = const Color(0xFFECFDF5);
                    } else if (type.contains('PAUSED')) {
                      iconData = Icons.pause_circle_rounded;
                      iconColor = AppTheme.amber;
                      bgColor = const Color(0xFFFEF3C7);
                    } else if (type.contains('START') || type.contains('BUS')) {
                      iconData = Icons.directions_bus_rounded;
                      iconColor = AppTheme.accent;
                      bgColor = const Color(0xFFEFF6FF);
                    }

                    String timeAgo = '';
                    if (createdAt != null) {
                      final diff = DateTime.now().difference(createdAt);
                      if (diff.inMinutes < 1) {
                        timeAgo = 'Just now';
                      } else if (diff.inMinutes < 60) {
                        timeAgo = '${diff.inMinutes}m ago';
                      } else if (diff.inHours < 24) {
                        timeAgo = '${diff.inHours}h ago';
                      } else {
                        timeAgo = '${diff.inDays}d ago';
                      }
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: isRead ? Colors.white : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(
                          color: isRead ? AppTheme.border : const Color(0xFFBFDBFE),
                          width: isRead ? 1.0 : 1.5,
                        ),
                        boxShadow: isRead ? null : AppTheme.cardShadow,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                          onTap: () {
                            if (!isRead && id.isNotEmpty) {
                              live.markNotificationRead(id);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(iconData, color: iconColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                                color: AppTheme.navy,
                                              ),
                                            ),
                                          ),
                                          if (timeAgo.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              timeAgo,
                                              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        body,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isRead ? AppTheme.muted : const Color(0xFF334155),
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(left: 8, top: 4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
