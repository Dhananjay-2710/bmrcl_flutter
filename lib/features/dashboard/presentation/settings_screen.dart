import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../users/services/user_service.dart';
import '../../../shared/utils/app_snackbar.dart';

enum ToastType { info, success, error }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _brand = Color(0xFFA7D222);
  static const Color _brandDark = Color(0xFF8DB71B);

  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _newNode = FocusNode();
  final _confirmNode = FocusNode();

  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _savingPwd = false;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _newNode.dispose();
    _confirmNode.dispose();
    super.dispose();
  }

  void _toast(String msg, {ToastType type = ToastType.info}) {
    switch (type) {
      case ToastType.success:
        AppSnackBar.success(context, msg);
        break;
      case ToastType.error:
        AppSnackBar.error(context, msg);
        break;
      case ToastType.info:
      default:
        AppSnackBar.info(context, msg);
    }
  }

  String? _validatePassword(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Enter a new password';
    if (value.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
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
      final auth = context.read<AuthProvider>();
      final user = auth.user;
      if (user == null) {
        _toast('User not found', type: ToastType.error);
        return;
      }

      final userService = context.read<UserService>();
      final ok = await userService.resetPassword(
        user.email,
        _newPassCtrl.text.trim(),
        _confirmPassCtrl.text.trim(),
      );

      if (!mounted) return;

      if (ok) {
        _toast('Password changed successfully ✅', type: ToastType.success);
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      } else {
        _toast('Failed to change password ❌', type: ToastType.error);
      }
    } catch (e) {
      if (mounted) _toast('Error: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _savingPwd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Update Password Card
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 14,
                          offset: Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_brand, _brandDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_reset,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Update Password',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _newPassCtrl,
                                focusNode: _newNode,
                                autofillHints: const [
                                  AutofillHints.newPassword
                                ],
                                obscureText: _hideNew,
                                textInputAction: TextInputAction.next,
                                validator: _validatePassword,
                                onFieldSubmitted: (_) =>
                                    _confirmNode.requestFocus(),
                                decoration: InputDecoration(
                                  labelText: 'New Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  helperText:
                                      'Min 8 chars, include letters & numbers',
                                  suffixIcon: IconButton(
                                    tooltip: _hideNew
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () =>
                                        setState(() => _hideNew = !_hideNew),
                                    icon: Icon(_hideNew
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPassCtrl,
                                focusNode: _confirmNode,
                                autofillHints: const [
                                  AutofillHints.newPassword
                                ],
                                obscureText: _hideConfirm,
                                textInputAction: TextInputAction.done,
                                validator: _validateConfirm,
                                onFieldSubmitted: (_) => _changePassword(),
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon:
                                      const Icon(Icons.lock_person_outlined),
                                  suffixIcon: IconButton(
                                    tooltip: _hideConfirm
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () => setState(
                                        () => _hideConfirm = !_hideConfirm),
                                    icon: Icon(_hideConfirm
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 46,
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _savingPwd ? null : _changePassword,
                                  icon: _savingPwd
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save,
                                          color: Colors.white, size: 18),
                                  label: Text(
                                    _savingPwd
                                        ? 'Updating…'
                                        : 'Update Password',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _brandDark,
                                    disabledBackgroundColor:
                                        _brandDark.withValues(alpha: 0.6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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

              const SizedBox(height: 16),

              // Additional Settings (for future expansion)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 14,
                          offset: Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Settings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SettingsItem(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Manage notification preferences',
                        onTap: () {
                          _toast('Notifications settings coming soon');
                        },
                      ),
                      const Divider(height: 24),
                      _SettingsItem(
                        icon: Icons.language_outlined,
                        title: 'Language',
                        subtitle: 'Change app language',
                        onTap: () {
                          _toast('Language settings coming soon');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const Color _brandDark = Color(0xFF8DB71B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _brandDark.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _brandDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
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
