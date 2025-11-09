import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import 'profile_details_screen.dart';
import 'settings_screen.dart';
import '../../notes/presentation/notes_tab.dart';
import '../../faqs/presentation/faqs_tab.dart';
import '../../../shared/utils/app_snackbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _brand = Color(0xFFA7D222);
  static const Color _brandDark = Color(0xFF8DB71B);
  static const Color _bg = Color(0xFFFDF6E9);

  bool _loggingOut = false;

  void _toast(String msg) {
    AppSnackBar.info(context, msg);
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      await context.read<AuthProvider>().logout();
    } catch (_) {
      // swallow errors; local logout is the source of truth
    } finally {
      if (!mounted) return;
      setState(() => _loggingOut = false);
    }
  }

  ImageProvider _avatarProvider(String? profileUrl) {
    if (profileUrl != null && profileUrl.isNotEmpty) {
      return NetworkImage(profileUrl);
    }
    return const AssetImage('assets/images/profile.jpg');
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final theme = Theme.of(context);

    final name = (user?.name?.isNotEmpty ?? false) ? user!.name : 'User';
    final role = (user?.role?.isNotEmpty ?? false) ? user!.role : 'Role';
    final profileUrl = user?.profileImageUrl;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.person, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              'Profile',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            children: [
              // User Avatar Card
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: _avatarProvider(profileUrl),
                            backgroundColor: Colors.grey.withValues(alpha: 0.15),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: true,
                              child: Center(
                                child: profileUrl == null || profileUrl.isEmpty
                                    ? Text(
                                        _initials(name),
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? '',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _brand.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _brand.withOpacity(0.3)),
                              ),
                              child: Text(
                                role,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _brandDark,
                                  fontWeight: FontWeight.w600,
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

              const SizedBox(height: 20),

              // Menu Options
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    // Profile Option
                    _MenuOptionCard(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      subtitle: 'View and edit your profile',
                      onTap: () {
                        if (user != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileDetailsScreen(user: user),
                            ),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // Notes Option
                    _MenuOptionCard(
                      icon: Icons.note_outlined,
                      title: 'Notes',
                      subtitle: 'Add and manage your notes',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Notes'),
                                backgroundColor: _brand,
                                foregroundColor: Colors.white,
                              ),
                              body: const NotesTab(),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // FAQ's Option
                    _MenuOptionCard(
                      icon: Icons.help_outline,
                      title: 'FAQ\'s',
                      subtitle: 'Frequently asked questions',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text('FAQ\'s'),
                                backgroundColor: _brand,
                                foregroundColor: Colors.white,
                              ),
                              body: const FaqsTabs(),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Settings Option
                    _MenuOptionCard(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'App settings and preferences',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Logout Button
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _loggingOut ? null : _logout,
                    icon: _loggingOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.logout, color: Colors.white, size: 20),
                    label: Text(
                      _loggingOut ? 'Signing out…' : 'Logout',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      disabledBackgroundColor: Colors.redAccent.withOpacity(0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // App Version
              Text(
                'AppVersion 1.0.2',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const Color _brand = Color(0xFFA7D222);
  static const Color _brandDark = Color(0xFF8DB71B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _brand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _brandDark, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
