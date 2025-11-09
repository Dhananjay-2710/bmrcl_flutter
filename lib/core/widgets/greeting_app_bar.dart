// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
//
// import '../../features/auth/providers/auth_provider.dart';
// import '../../features/dashboard/presentation/profile_screen.dart';
// import '../../features/notifications/presentation/notifications_screen.dart';
// import '../../features/notifications/providers/notifications_provider.dart';
//
// class GreetingAppBar extends StatelessWidget implements PreferredSizeWidget {
//   final String greetingText;
//   final String userName;
//   final String roleName;
//   final String? profileUrl;
//   final String avatarAsset;
//
//   // Brand colors
//   static const Color _brand = Color(0xFFA7D222);
//   static const Color _brandDark = Color(0xFF8DB71B);
//
//   const GreetingAppBar({
//     super.key,
//     required this.greetingText,
//     required this.userName,
//     required this.roleName,
//     this.profileUrl,
//     this.avatarAsset = 'assets/images/profile.jpg',
//   });
//
//   @override
//   Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);
//
//   @override
//   Widget build(BuildContext context) {
//     final auth = context.watch<AuthProvider>();
//     final notif = context.watch<NotificationsProvider>();
//     final unread = notif.unreadCount;
//
//     final displayName = (userName.trim().isEmpty) ? 'User' : userName.trim();
//     final userRole = (roleName.trim().isEmpty) ? 'Role' : roleName.trim();
//     return AppBar(
//       automaticallyImplyLeading: false,
//       elevation: 0,
//       backgroundColor: Colors.transparent,
//       surfaceTintColor: Colors.transparent,
//       iconTheme: const IconThemeData(color: Colors.white),
//       actionsIconTheme: const IconThemeData(color: Colors.white),
//
//       // Non-const so gradient always paints correctly on theme changes
//       flexibleSpace: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [_brand, _brandDark],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//       ),
//
//       titleSpacing: 12,
//       title: Row(
//         children: [
//           // Greeting (ellipsizes nicely on small screens)
//           Expanded(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   '$greetingText, $displayName 👋',
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontWeight: FontWeight.w700,
//                     color: Colors.white,
//                     fontSize: 18,
//                     letterSpacing: 0.2,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   userRole ?? '',
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(
//                     fontWeight: FontWeight.w600,
//                     color: Colors.white.withValues(alpha: 0.9), // no deprecated withOpacity
//                     fontSize: 12,
//                     letterSpacing: 0.2,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Notifications button with badge
//           _NotificationButton(
//             unreadCount: unread,
//             onTap: () {
//               HapticFeedback.selectionClick();
//               context.read<NotificationsProvider>().refresh();
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const NotificationsScreen()),
//               );
//             },
//           ),
//
//           const SizedBox(width: 8),
//
//           // Profile avatar button
//           _AvatarButton(
//             imageUrl: (profileUrl != null && profileUrl!.isNotEmpty) ? profileUrl : null,
//             fallbackAsset: avatarAsset,
//             initials: _initials(displayName),
//             onTap: (auth.user != null)
//                 ? () {
//               HapticFeedback.lightImpact();
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => ProfileScreen(user: auth.user!),
//                 ),
//               );
//             }
//                 : null,
//           ),
//         ],
//       ),
//     );
//   }
//
//   static String _initials(String name) {
//     final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
//     if (parts.isEmpty) return 'U';
//     if (parts.length == 1) return parts.first[0].toUpperCase();
//     return (parts.first[0] + parts.last[0]).toUpperCase();
//   }
// }
//
// class _NotificationButton extends StatelessWidget {
//   final int unreadCount;
//   final VoidCallback onTap;
//
//   const _NotificationButton({
//     required this.unreadCount,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Semantics(
//       label: 'Notifications',
//       hint: unreadCount > 0 ? '$unreadCount unread' : 'No unread notifications',
//       button: true,
//       child: Stack(
//         clipBehavior: Clip.none,
//         alignment: Alignment.center,
//         children: [
//           IconButton(
//             icon: const Icon(Icons.notifications_outlined, size: 22, color: Colors.white),
//             tooltip: 'Notifications',
//             onPressed: onTap,
//             splashRadius: 22,
//           ),
//           if (unreadCount > 0)
//             Positioned(
//               right: 6,
//               top: 8,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
//                 constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.red,
//                   borderRadius: BorderRadius.circular(10),
//                   border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1),
//                 ),
//                 child: Text(
//                   unreadCount > 99 ? '99+' : '$unreadCount',
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
//
// class _AvatarButton extends StatelessWidget {
//   final String? imageUrl;
//   final String fallbackAsset;
//   final String initials;
//   final VoidCallback? onTap;
//
//   const _AvatarButton({
//     required this.imageUrl,
//     required this.fallbackAsset,
//     required this.initials,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final hasTap = onTap != null;
//     final avatar = Hero(
//       tag: 'profile-avatar',
//       child: CircleAvatar(
//         radius: 18,
//         backgroundColor: Colors.white,
//         child: CircleAvatar(
//           radius: 16,
//           backgroundColor: Colors.black.withValues(alpha: 0.06),
//           backgroundImage: (imageUrl != null)
//               ? NetworkImage(imageUrl!)
//               : AssetImage(fallbackAsset) as ImageProvider,
//           child: (imageUrl == null)
//               ? Center(
//             child: Text(
//               initials,
//               style: const TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w800,
//                 color: Colors.black87,
//                 letterSpacing: 0.2,
//               ),
//             ),
//           )
//               : null,
//         ),
//       ),
//     );
//
//     // Ripple + semantics
//     final child = Material(
//       color: Colors.transparent,
//       shape: const CircleBorder(),
//       child: InkWell(
//         customBorder: const CircleBorder(),
//         onTap: onTap,
//         child: Padding(
//           padding: const EdgeInsets.all(6),
//           child: avatar,
//         ),
//       ),
//     );
//
//     return Semantics(
//       label: 'Open profile',
//       button: hasTap,
//       child: hasTap ? child : Opacity(opacity: 0.8, child: avatar),
//     );
//   }
// }
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/presentation/profile_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/notifications/providers/notifications_provider.dart';

class GreetingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String greetingText;
  final String userName;
  final String roleName;
  final String? profileUrl;
  final String avatarAsset;

  // Brand colors
  static const Color _brand = Color(0xFFA7D222);
  static const Color _brandDark = Color(0xFF8DB71B);

  const GreetingAppBar({
    super.key,
    required this.greetingText,
    required this.userName,
    required this.roleName,
    this.profileUrl,
    this.avatarAsset = 'assets/images/profile.jpg',
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notif = context.watch<NotificationsProvider>();
    final unread = notif.unreadCount;

    final displayName = (userName.trim().isEmpty) ? 'User' : userName.trim();
    final userRole = (roleName.trim().isEmpty) ? 'Role' : roleName.trim();

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,

      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_brand, _brandDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
      ),

      titleSpacing: 16,
      title: Row(
        children: [
          // Greeting + role
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greetingText, $displayName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 18,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userRole,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Notification icon with badge
          _NotificationButton(
            unreadCount: unread,
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<NotificationsProvider>().refresh();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),

          const SizedBox(width: 8),

          // Avatar
          _AvatarButton(
            imageUrl: (profileUrl != null && profileUrl!.isNotEmpty) ? profileUrl : null,
            fallbackAsset: avatarAsset,
            initials: _initials(displayName),
            onTap: (auth.user != null)
                ? () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            }
                : null,
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _NotificationButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationButton({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, size: 24, color: Colors.white),
          tooltip: 'Notifications',
          onPressed: onTap,
          splashRadius: 24,
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final String? imageUrl;
  final String fallbackAsset;
  final String initials;
  final VoidCallback? onTap;

  const _AvatarButton({
    required this.imageUrl,
    required this.fallbackAsset,
    required this.initials,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasTap = onTap != null;
    final avatar = Hero(
      tag: 'profile-avatar',
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: 16,
          backgroundImage: (imageUrl != null)
              ? NetworkImage(imageUrl!)
              : AssetImage(fallbackAsset) as ImageProvider,
          backgroundColor: Colors.grey.shade100,
          child: (imageUrl == null)
              ? Text(
            initials,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          )
              : null,
        ),
      ),
    );

    final child = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: avatar,
        ),
      ),
    );

    return hasTap ? child : Opacity(opacity: 0.9, child: avatar);
  }
}
