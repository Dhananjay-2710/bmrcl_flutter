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
    // Only rebuild when these specific pieces change
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    final name = (user?.name.isNotEmpty ?? false) ? user!.name : 'User';
    final role = (user?.role?.isNotEmpty ?? false) ? user!.role : 'Role';
    final profileUrl =
    (user?.profileImageUrl?.isNotEmpty ?? false) ? user!.profileImageUrl : null;

    return Scaffold(
      appBar: GreetingAppBar(
        greetingText: auth.greeting(),
        userName: name,
        roleName: role,
        profileUrl: profileUrl,
      ),
      body: SafeArea(
        top: false, // app bar already provides top inset
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: _GradientBottomBar(
        index: _index,
        onTap: _onTabSelected,
      ),
    );
  }
}

class _GradientBottomBar extends StatelessWidget {
  const _GradientBottomBar({
    required this.index,
    required this.onTap,
  });

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // Wrapper with gradient & rounded top corners
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade600, Colors.teal.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              offset: const Offset(0, -1),
              blurRadius: 8,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withValues(alpha: 0.8),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.task_outlined),
              activeIcon: Icon(Icons.task),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              // Clean active/inactive without manual containers
              icon: const Icon(Icons.work_outline),
              activeIcon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
                child: const Icon(Icons.work, color: Colors.white),
              ),
              label: 'Duty',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.note_outlined),
              activeIcon: Icon(Icons.note),
              label: 'Notes',
            ),
            // const BottomNavigationBarItem(
            //   icon: Icon(Icons.help_outline),
            //   activeIcon: Icon(Icons.help),
            //   label: "FAQ's",
            // ),
          ],
        ),
      ),
    );
  }
}
