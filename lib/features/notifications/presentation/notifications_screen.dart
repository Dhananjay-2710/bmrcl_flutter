import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import '../models/app_notification.dart';
import '../providers/notifications_provider.dart';

String stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '');

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    final p = context.read<NotificationsProvider>();
    if (p.isAuthenticated) p.refresh(); // avoid calling with no token

    _sc.addListener(() {
      final prov = context.read<NotificationsProvider>();
      if (!prov.hasMore || prov.isLoadingMore) return;
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 200) {
        prov.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NotificationsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: p.unreadCount == 0 ? null : () => p.markAllAsRead(),
            icon: const Icon(Icons.mark_email_read_outlined),
            label: const Text('Mark all'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<NotificationsProvider>().refresh(),
        child: Builder(
          builder: (_) {
            // initial full-screen loader
            if (p.isLoading && p.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            // empty state
            if (!p.isLoading && p.items.isEmpty) {
              return const Center(child: Text('No notifications'));
            }

            return ListView.separated(
              controller: _sc,
              itemCount: p.items.length + (p.isLoadingMore ? 1 : 0), // <-- use isLoadingMore
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i >= p.items.length) {
                  // loader row only when actually loading more
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final n = p.items[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (n.data.fromUserImage?.isNotEmpty ?? false)
                        ? NetworkImage(n.data.fromUserImage!)
                        : const AssetImage('assets/images/profile.jpg') as ImageProvider,
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(n.data.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                      if (!n.isRead)
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    ],
                  ),
                  subtitle: Text(
                    n.data.message.replaceAll(RegExp(r'<[^>]*>'), ''),
                    style: const TextStyle(fontSize: 12),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(n.isRead ? Icons.done_all : Icons.markunread, size: 18),
                  isThreeLine: true,
                  onTap: () async {
                    if (!n.isRead) {
                      await context.read<NotificationsProvider>().markAsRead(n.id);
                    }
                    final url = n.data.url.trim();
                    if (url.isNotEmpty) {
                      // open deep-link / webview as per your app
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification n;
  final VoidCallback? onTap;
  const _NotificationTile({required this.n, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !n.isRead;
    final title = n.data.title;
    final msg = n.data.message;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (n.data.fromUserImage?.isNotEmpty ?? false)
            ? NetworkImage(n.data.fromUserImage!)
            : const AssetImage('assets/images/profile.jpg') as ImageProvider,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (isUnread)
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
        ],
      ),

      // If you installed flutter_html:
      subtitle: Html(data: msg, style: { "*": Style(fontSize: FontSize.small) }),
      // subtitle: Text(
      //   stripHtml(msg),
      //   style: const TextStyle(fontSize: 12),
      //   maxLines: 3,
      //   overflow: TextOverflow.ellipsis,
      // ),

      trailing: Icon(isUnread ? Icons.markunread : Icons.done_all, size: 18),
      onTap: onTap,
      isThreeLine: true,
    );
  }
}