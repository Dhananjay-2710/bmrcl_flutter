import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'splash_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Veriphy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFA7D222),
          primary: const Color(0xFFA7D222),
        ),
        useMaterial3: true,
      ),
      // No initialRoute / routes; use an AuthGate instead
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _initialized = false;

  // Minimum splash screen duration (1-2 seconds for branding)
  static const Duration _minSplashDuration = Duration(milliseconds: 1500); // 1.5 seconds

  @override
  void initState() {
    super.initState();
    // Initialize auth state from storage with minimum splash duration
    _initializeAuth();
  }

  /// Standard approach: Show splash for minimum duration AND wait for auth initialization
  /// This ensures users see branding for at least 2 seconds, but don't wait unnecessarily
  Future<void> _initializeAuth() async {
    final authProvider = context.read<AuthProvider>();
    
    // Start both tasks in parallel:
    // 1. Minimum splash duration (2 seconds)
    // 2. Auth initialization (variable time)
    final splashFuture = Future.delayed(_minSplashDuration);
    final authFuture = authProvider.initializeAuth();
    
    // Wait for BOTH to complete (whichever takes longer)
    await Future.wait([splashFuture, authFuture]);
    
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    // Show beautiful splash screen while initializing
    if (!_initialized || authProvider.initializing) {
      return const SplashScreen();
    }

    // After initialization, check token
    final token = authProvider.token;

    if (token == null) {
      return const LoginScreen();
    }
    return const DashboardScreen();
  }
}
