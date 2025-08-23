import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../users/services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _brand = Color(0xFFA7D222);
  static const Color _brandDark = Color(0xFF8DB71B);
  static const Color _bg = Color(0xFFFDF6E9);

  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _newNode = FocusNode();
  final _confirmNode = FocusNode();

  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _savingPwd = false;
  bool _loggingOut = false;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _newNode.dispose();
    _confirmNode.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String? _validatePassword(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Enter a new password';
    if (value.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
      return 'Use letters and numbers';
    }
    return null;
  }

  String? _validateConfirm(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Confirm your password';
    if (value != _newPassCtrl.text.trim()) return 'Passwords do not match';
    return null;
  }

  Future<void> _changePassword() async {
    if (_savingPwd) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    FocusScope.of(context).unfocus();
    setState(() => _savingPwd = true);
    try {
      final ok = await UserService.resetPassword(
        widget.user.email,
        _newPassCtrl.text.trim(),
        _confirmPassCtrl.text.trim(),
      );
      if (!mounted) return;
      if (ok) {
        _toast('Password changed successfully ✅');
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      } else {
        _toast('Failed to change password ❌');
      }
    } catch (e) {
      if (mounted) _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _savingPwd = false);
    }
  }

  // Future<void> _logout() async {
  //   if (_loggingOut) return;
  //   setState(() => _loggingOut = true);
  //   try {
  //     await context.read<AuthProvider>().logout(context);
  //   } catch (_) {
  //     // ignore network errors and proceed
  //   } finally {
  //     if (!mounted) return;
  //     setState(() => _loggingOut = false);
  //     Navigator.pushAndRemoveUntil(
  //       context,
  //       MaterialPageRoute(builder: (_) => const LoginScreen()),
  //           (_) => false,
  //     );
  //   }
  // }

  // Future<void> _logout() async {
  //   if (_loggingOut) return;
  //   setState(() => _loggingOut = true);
  //
  //   try {
  //     // 1) Close transient UI tied to this context
  //     ScaffoldMessenger.of(context).clearSnackBars();
  //     Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  //
  //     // 2) Invalidate session (ignore server errors)
  //     await context.read<AuthProvider>().logout();
  //   } catch (_) {
  //     // swallow logout/network errors
  //   } finally {
  //     if (!mounted) return;
  //     setState(() => _loggingOut = false);
  //
  //     // 3) Navigate on the next frame to avoid acting during teardown
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       if (!mounted) return;
  //
  //       // If you use an AuthGate at app root, you can remove this navigation
  //       // and just let the tree rebuild to Login automatically.
  //       Navigator.of(context).pushAndRemoveUntil(
  //         MaterialPageRoute(builder: (_) => const LoginScreen()),
  //             (route) => false,
  //       );
  //     });
  //   }
  // }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    try {
      // Close transient UI tied to this context
      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);

      await context.read<AuthProvider>().logout();
    } catch (_) {
      // swallow errors; local logout is the source of truth
    } finally {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      // No navigation needed—AuthGate will show LoginScreen automatically.
    }
  }

  // Future<void> _logout() async {
  //   if (_loggingOut) return;
  //   setState(() => _loggingOut = true);
  //
  //   try {
  //     // 1) Close transient UI tied to the soon-to-be-disposed context
  //     ScaffoldMessenger.of(context).clearSnackBars();
  //     Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  //
  //     // 2) Invalidate session (ignore server errors)
  //     await context.read<AuthProvider>().logout(context);
  //   } catch (_) {
  //     // swallow logout/network errors
  //   } finally {
  //     if (!mounted) return;
  //     setState(() => _loggingOut = false);
  //
  //     // 3) Navigate on next frame to avoid acting during teardown
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       if (!mounted) return;
  //
  //       // If you use an AuthGate at app root, you can SKIP this navigation.
  //       // The UI will rebuild to Login automatically when token == null.
  //       Navigator.of(context).pushAndRemoveUntil(
  //         MaterialPageRoute(builder: (_) => const LoginScreen()),
  //             (route) => false,
  //       );
  //     });
  //   }
  // }

  ImageProvider _avatarProvider() {
    final url = widget.user.profileImageUrl;
    if (url != null && url.isNotEmpty) {
      return NetworkImage(url);
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
    final theme = Theme.of(context);

    return Scaffold(
        appBar: AppBar(
        // title: const Text("Profile"),
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
      // AppBar removed as requested
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                // Optional tiny top title row (keeps screen context without a full AppBar)
                // Padding(
                //   padding: const EdgeInsets.only(bottom: 8),
                //   child: Row(
                //     children: [
                //       const Icon(Icons.person, color: Colors.black54, size: 18),
                //       const SizedBox(width: 6),
                //       Text(
                //         'Profile',
                //         style: theme.textTheme.titleMedium?.copyWith(
                //           fontWeight: FontWeight.w700,
                //           color: Colors.black87,
                //         ),
                //       ),
                //     ],
                //   ),
                // ),

                // ── Compact Profile Card (reduced size + max width)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Slim header strip
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_brand, _brandDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Your Details',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Body (tighter paddings, smaller avatar/text)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Smaller avatar
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 36, // ↓ from 44
                                    backgroundImage: _avatarProvider(),
                                    backgroundColor: Colors.grey.withValues(alpha: 0.15),
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      ignoring: true,
                                      child: Center(
                                        child: Text(
                                          widget.user.profileImageUrl == null || widget.user.profileImageUrl!.isEmpty
                                              ? _initials(widget.user.name)
                                              : '',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.user.name,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.user.email,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _InfoChip(
                                          icon: Icons.badge_outlined,
                                          label: 'Role',
                                          value: widget.user.role ?? '—',
                                        ),
                                        _InfoChip(
                                          icon: Icons.confirmation_number_outlined,
                                          label: 'User ID',
                                          value: '${widget.user.userId}',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _toast('Edit Profile coming soon'),
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          label: const Text('Edit Profile'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            minimumSize: const Size(0, 36),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Compact Change Password Card (also constrained)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_brand, _brandDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_reset, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Change Password',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _newPassCtrl,
                                  focusNode: _newNode,
                                  autofillHints: const [AutofillHints.newPassword],
                                  obscureText: _hideNew,
                                  textInputAction: TextInputAction.next,
                                  validator: _validatePassword,
                                  onFieldSubmitted: (_) => _confirmNode.requestFocus(),
                                  decoration: InputDecoration(
                                    labelText: 'New Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    helperText: 'Min 8 chars, include letters & numbers',
                                    suffixIcon: IconButton(
                                      tooltip: _hideNew ? 'Show password' : 'Hide password',
                                      onPressed: () => setState(() => _hideNew = !_hideNew),
                                      icon: Icon(_hideNew ? Icons.visibility_off : Icons.visibility),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _confirmPassCtrl,
                                  focusNode: _confirmNode,
                                  autofillHints: const [AutofillHints.newPassword],
                                  obscureText: _hideConfirm,
                                  textInputAction: TextInputAction.done,
                                  validator: _validateConfirm,
                                  onFieldSubmitted: (_) => _changePassword(),
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    prefixIcon: const Icon(Icons.lock_person_outlined),
                                    suffixIcon: IconButton(
                                      tooltip: _hideConfirm ? 'Show password' : 'Hide password',
                                      onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                                      icon: Icon(_hideConfirm ? Icons.visibility_off : Icons.visibility),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 46, // slimmer button
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _savingPwd ? null : _changePassword,
                                    icon: _savingPwd
                                        ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                        : const Icon(Icons.save, color: Colors.white, size: 18),
                                    label: Text(
                                      _savingPwd ? 'Updating…' : 'Update Password',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _brandDark,
                                      disabledBackgroundColor: _brandDark.withValues(alpha: 0.6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
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
                ),

                const SizedBox(height: 14),

                // ── Logout (slimmer)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _loggingOut ? null : _logout,
                      icon: _loggingOut
                          ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.logout, color: Colors.white, size: 18),
                      label: Text(
                        _loggingOut ? 'Signing out…' : 'Logout',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        // If your channel doesn't support withValues:
                        disabledBackgroundColor: Colors.redAccent.withOpacity(0.7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[800]),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}
