import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/utils/app_snackbar.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // ── Brand palette (align with Login / Verify)
  static const Color _brand = Color(0xFFA7D222);
  static const Color _brandDark = Color(0xFF8DB71B);
  static const Color _bg = Color(0xFFFDF6E9);

  final _emailController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _emailNode = FocusNode();
  final _newPassNode = FocusNode();
  final _confirmPassNode = FocusNode();

  bool _loading = false;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _emailNode.dispose();
    _newPassNode.dispose();
    _confirmPassNode.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Enter a new password';
    if (value.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Use letters and numbers';
    }
    return null;
  }

  String? _validateConfirm(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Confirm your password';
    if (value != _newPassController.text) return 'Passwords do not match';
    return null;
  }

  void _toast(String msg, {bool success = false}) {
    if (success) {
      AppSnackBar.success(context, msg);
    } else {
      AppSnackBar.error(context, msg);
    }
  }

  Future<void> _submit() async {
    if (_loading) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final authProv = context.read<AuthProvider>();
      final ok = await authProv.resetPassword(
        email: _emailController.text.trim(),
        newPassword: _newPassController.text.trim(),
        confirmPassword: _confirmPassController.text.trim(),
      );
      if (!mounted) return;
      if (ok) {
        _toast('Password reset successfully!', success: true);
        Navigator.pop(context);
      } else {
        _toast('Failed to reset password');
      }
    } catch (e) {
      if (mounted) _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _bg,
      // appBar: AppBar(
      //   title: const Text('Forgot Password'),
      //   backgroundColor: _brand,
      //   foregroundColor: Colors.black87,
      //   elevation: 0,
      // ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 18,
                        offset: Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset your password',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter your email and a new password.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Form
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email
                            TextFormField(
                              controller: _emailController,
                              focusNode: _emailNode,
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email
                              ],
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: _validateEmail,
                              onFieldSubmitted: (_) =>
                                  _newPassNode.requestFocus(),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // New password
                            TextFormField(
                              controller: _newPassController,
                              focusNode: _newPassNode,
                              autofillHints: const [AutofillHints.newPassword],
                              obscureText: _hideNew,
                              textInputAction: TextInputAction.next,
                              validator: _validatePassword,
                              onFieldSubmitted: (_) =>
                                  _confirmPassNode.requestFocus(),
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                prefixIcon: const Icon(Icons.lock_outline),
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
                                helperText: 'Min 8 chars, letters & numbers',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Confirm password
                            TextFormField(
                              controller: _confirmPassController,
                              focusNode: _confirmPassNode,
                              autofillHints: const [AutofillHints.newPassword],
                              obscureText: _hideConfirm,
                              textInputAction: TextInputAction.done,
                              validator: _validateConfirm,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon:
                                    const Icon(Icons.lock_reset_outlined),
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

                            const SizedBox(height: 18),

                            // CTA
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _loading ? null : _submit,
                                icon: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.key,
                                        size: 20, color: Colors.white),
                                label: Text(
                                  _loading ? 'Resetting…' : 'Reset Password',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _brandDark,
                                  disabledBackgroundColor:
                                      _brandDark.withValues(alpha: 0.6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Back
                            TextButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Back to Login'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
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
          ),
        ),
      ),
    );
  }
}
