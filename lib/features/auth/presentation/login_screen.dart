import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/storage_service.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../providers/auth_provider.dart';
import '../services/auth_exceptions.dart';
import 'email_verification_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _brand = Color(0xFFA7D222);    // primary
  static const Color _brandDark = Color(0xFF8DB71B); // deeper tint
  static const Color _bg = Color(0xFFFDF6E9);        // soft background

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailNode = FocusNode();
  final _passwordNode = FocusNode();

  bool _isLoading = false;
  bool _hidePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailNode.dispose();
    _passwordNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      // Scroll any potential error into view
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();

    try {
      final ok = await authProvider.login(
        _email.text.trim(),
        _password.text.trim(),
      );

      if (!mounted) return;

      if (ok) {
        if (_rememberMe && authProvider.token != null) {
          await StorageService.saveToken(authProvider.token!);
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.code == AuthErrorCode.emailNotVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(email: _email.text.trim()),
          ),
        );
      } else if (e.code == AuthErrorCode.invalidCredentials) {
        _toast("Invalid email or password");
      } else {
        _toast(e.message);
      }
    } catch (e) {
      if (mounted) _toast("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
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
    if (value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Minimum 6 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // nice responsive max width for desktop/tablet
              final maxW = constraints.maxWidth > 520 ? 420.0 : double.infinity;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      // Logo
                      Hero(
                        tag: 'veriphy-logo',
                        child: Image.asset(
                          'assets/icons/veriphy-logo.png',
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card header with gradient
                            Container(
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_brand, _brandDark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sign In',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Sign in to your account to continue',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Form
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Email
                                    TextFormField(
                                      controller: _email,
                                      focusNode: _emailNode,
                                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator: _validateEmail,
                                      onFieldSubmitted: (_) => _passwordNode.requestFocus(),
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon: const Icon(Icons.email_outlined),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Password
                                    TextFormField(
                                      controller: _password,
                                      focusNode: _passwordNode,
                                      autofillHints: const [AutofillHints.password],
                                      obscureText: _hidePassword,
                                      textInputAction: TextInputAction.done,
                                      validator: _validatePassword,
                                      onFieldSubmitted: (_) => _handleLogin(),
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          tooltip: _hidePassword ? 'Show password' : 'Hide password',
                                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                                          icon: Icon(_hidePassword ? Icons.visibility_off : Icons.visibility),
                                        ),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    Row(
                                      children: [
                                        // Left side: checkbox + label can ellipsize
                                        Expanded(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Checkbox(
                                                value: _rememberMe,
                                                onChanged: (v) => setState(() => _rememberMe = v ?? true),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                activeColor: _brandDark,
                                              ),
                                              const Flexible(
                                                child: Text(
                                                  'Remember Me',
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Right side: shrink-wrapped TextButton that can ellipsize
                                        Flexible(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 8), // tighter
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: _isLoading
                                                  ? null
                                                  : () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                                );
                                              },
                                              child: const Text(
                                                'Forgot Password?',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    // CTA
                                    SizedBox(
                                      height: 52,
                                      child: ElevatedButton.icon(
                                        onPressed: _isLoading ? null : _handleLogin,
                                        icon: _isLoading
                                            ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                            : const Icon(Icons.login, size: 20, color: Colors.white),
                                        label: Text(
                                          _isLoading ? 'Signing In...' : 'Sign In',
                                          style: const TextStyle(
                                            fontSize: 17,
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

                      const SizedBox(height: 22),

                      // Footer
                      Opacity(
                        opacity: 0.9,
                        child: Column(
                          children: const [
                            Text('© 2025 Frog8. All rights reserved.',
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                            SizedBox(height: 4),
                            Text('Version 1.0.1', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
      ),
    );
  }
}