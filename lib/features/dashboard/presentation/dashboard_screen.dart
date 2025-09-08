import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/greeting_app_bar.dart';
import '../../../tabs/home_tab.dart';
import '../../auth/providers/auth_provider.dart';
import '../../faqs/presentation/faqs_tab.dart';
import '../../notes/presentation/notes_tab.dart';
import '../../shifts/presentation/shifts_tab.dart';
import '../../tasks/presentation/tasks_tab.dart';
import 'dart:ui';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;

  // Keep each tab's state alive
  final _pages = const <Widget>[
    HomeTab(key: PageStorageKey('home')),
    TasksTab(key: PageStorageKey('tasks')),
    ShiftsTab(key: PageStorageKey('shifts')),
    NotesTab(key: PageStorageKey('notes')),
    FaqsTabs(key: PageStorageKey('faqs')),
  ];

  // Optional: hook to scroll to top when re-tapping current tab
  final _scrollControllers = List.generate(5, (_) => ScrollController());

  void _onTabSelected(int i) {
    if (i == _index) {
      // re-tap → scroll to top if the tab uses the provided controller
      if (_scrollControllers[_index].hasClients) {
        _scrollControllers[_index].animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _index = i);
  }

  @override
  void dispose() {
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    final name = (user?.name?.isNotEmpty ?? false) ? user!.name : 'User';
    final role = (user?.role?.isNotEmpty ?? false) ? user!.role : 'Role';
    final profileUrl =
    (user?.profileImageUrl?.isNotEmpty ?? false) ? user!.profileImageUrl : null;

    return Scaffold(
      extendBody: true, // allows content to show behind the nav bar
      backgroundColor: Colors.grey.shade50,

      appBar: GreetingAppBar(
        greetingText: auth.greeting(),
        userName: name,
        roleName: role,
        profileUrl: profileUrl,
      ),

      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: IndexedStack(
            key: ValueKey(_index),
            index: _index,
            children: _pages,
          ),
        ),
      ),

      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // frosted glass effect
          child: Container(
            color: Colors.white.withOpacity(0.65), // semi-transparent background
            child: _GradientBottomBar(
              index: _index,
              onTap: _onTabSelected,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientBottomBar extends StatelessWidget {
  const _GradientBottomBar({
    super.key,
    required this.index,
    required this.onTap,
  });

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), // floating effect
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal.withOpacity(0.75),
                  Colors.green.withOpacity(0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: index,
              onTap: onTap,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white.withOpacity(0.7),
              selectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              items: [
                _navItem(Icons.home_outlined, Icons.home, "Home"),
                _navItem(Icons.task_outlined, Icons.task, "Tasks"),
                _navItem(Icons.work_outline, Icons.work, "Duty", highlight: true),
                _navItem(Icons.note_outlined, Icons.note, "Notes"),
                _navItem(Icons.help_outline, Icons.help, "FAQ's"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(
      IconData icon,
      IconData active,
      String label, {
        bool highlight = false,
      }) {
    return BottomNavigationBarItem(
      icon: Icon(icon),
      activeIcon: highlight
          ? Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.25), Colors.white10],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(active, color: Colors.white),
      )
          : Icon(active),
      label: label,
    );
  }
}
