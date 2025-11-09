import 'package:flutter/material.dart';

/// Centralized helper for showing branded snack bars across the app.
class AppSnackBar {
  const AppSnackBar._();

  static void success(BuildContext context, String message,
      {Duration? duration}) {
    _show(
      context,
      message,
      background: const Color(0xFF1B5E20),
      icon: Icons.check_circle_outline,
      duration: duration,
    );
  }

  static void error(BuildContext context, String message,
      {Duration? duration}) {
    _show(
      context,
      message,
      background: const Color(0xFFB71C1C),
      icon: Icons.error_outline,
      duration: duration,
    );
  }

  static void info(BuildContext context, String message, {Duration? duration}) {
    _show(
      context,
      message,
      background: const Color(0xFF263238),
      icon: Icons.info_outline,
      duration: duration,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color background,
    required IconData icon,
    Duration? duration,
  }) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.clearSnackBars();

    scaffold.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
}
