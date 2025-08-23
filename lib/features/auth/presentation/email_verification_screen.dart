import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../../auth/presentation/login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  // ── Brand palette (match LoginScreen)
  static const Color _brand = Color(0xFFA7D222);
  static const Color _brandDark = Color(0xFF8DB71B);
  static const Color _bg = Color(0xFFFDF6E9);

  // OTP state
  static const int _otpLen = 6;
  final List<TextEditingController> _ctrs =
  List.generate(_otpLen, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(_otpLen, (_) => FocusNode());
  bool _verifying = false;
  bool _resending = false;

  // Resend cooldown
  static const int _cooldown = 60;
  int _secondsLeft = _cooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _nodes.first.requestFocus();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrs) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _code => _ctrs.map((c) => c.text).join();

  void _setFromPasted(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '').split('');
    for (int i = 0; i < _otpLen; i++) {
      _ctrs[i].text = i < digits.length ? digits[i] : '';
    }
    // Move focus to the last filled or next
    final next = digits.length.clamp(0, _otpLen - 1);
    _nodes[next].requestFocus();
  }

  Future<void> _verify() async {
    final prov = context.read<AuthProvider>();
    final code = _code;

    if (code.length != _otpLen || code.contains(RegExp(r'\D'))) {
      _toast("Please enter the 6-digit code.");
      return;
    }

    setState(() => _verifying = true);
    try {
      final ok = await prov.verifyEmailCode(email: widget.email, code: code);
      if (!mounted) return;
      if (ok) {
        _toast("Email verified! Please log in.");
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      } else {
        _toast("Verification failed. Check your code.");
      }
    } catch (e) {
      if (mounted) _toast("Error: $e");
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      final ok = await context.read<AuthProvider>().resendEmailCode(email: widget.email);
      if (!mounted) return;
      _toast(ok ? "Code resent." : "Failed to resend code.");
      if (ok) _startCooldown();
    } catch (e) {
      if (mounted) _toast("Error: $e");
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _maskedEmail(String email) {
    // simple mask: keep first & last char of local part
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    if (local.length <= 2) return email;
    final masked = '${local[0]}***${local[local.length - 1]}@${parts[1]}';
    return masked;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final masked = _maskedEmail(widget.email);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("Verify Email"),
        backgroundColor: _brand,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
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
                    BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
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
                            'Email Verification',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "We sent a 6-digit code to $masked",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // OTP boxes
                          Semantics(
                            label: 'Enter 6 digit verification code',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(_otpLen, (i) {
                                return _OtpBox(
                                  controller: _ctrs[i],
                                  focusNode: _nodes[i],
                                  onChanged: (val) {
                                    // Handle paste (multiple digits)
                                    if (val.length > 1) {
                                      _setFromPasted(val);
                                      return;
                                    }
                                    if (val.isNotEmpty) {
                                      if (i < _otpLen - 1) {
                                        _nodes[i + 1].requestFocus();
                                      } else {
                                        _nodes[i].unfocus();
                                      }
                                    }
                                  },
                                  onBackspaceOnEmpty: () {
                                    if (i > 0) _nodes[i - 1].requestFocus();
                                  },
                                );
                              }),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Verify button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _verifying ? null : _verify,
                              icon: _verifying
                                  ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Icon(Icons.verified, color: Colors.white, size: 20),
                              label: Text(
                                _verifying ? 'Verifying…' : 'Verify',
                                style: const TextStyle(
                                  fontSize: 16,
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

                          const SizedBox(height: 12),

                          // Resend row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_secondsLeft > 0)
                                Text(
                                  "You can resend in $_secondsLeft s",
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                                )
                              else
                                TextButton.icon(
                                  onPressed: _resending ? null : _resend,
                                  icon: _resending
                                      ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                      : const Icon(Icons.refresh),
                                  label: const Text("Resend Code"),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // Back to login
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                    (_) => false,
                              );
                            },
                            child: const Text('Back to Login'),
                          ),
                        ],
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

/// Single OTP box with nice UX (digits only, 1 char, backspace behavior, paste handled in parent)
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspaceOnEmpty;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspaceOnEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1),
        decoration: InputDecoration(
          counterText: '',
          hintText: '•',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _OtpBoxColors.focus),
          ),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: onChanged,
        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        onEditingComplete: () {}, // keep control
        // Handle backspace when empty
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }
}

class _OtpBoxColors {
  static const focus = Color(0xFF8DB71B);
}
