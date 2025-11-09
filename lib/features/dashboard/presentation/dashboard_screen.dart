import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/greeting_app_bar.dart';
import '../../../tabs/home_tab.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shifts/presentation/shifts_tab.dart';
import '../../tasks/presentation/tasks_tab.dart';
import '../../leave/presentation/leave_tab.dart';
import '../../issues/presentation/issues_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  final PageStorageBucket _bucket = PageStorageBucket();

  // Keep each tab's state alive
  final _pages = const <Widget>[
    HomeTab(key: PageStorageKey('home')),
    TasksTab(key: PageStorageKey('tasks')),
    IssuesTab(key: PageStorageKey('issues')),
    ShiftsTab(key: PageStorageKey('shifts')),
    LeaveTab(key: PageStorageKey('leave')),
  ];

  void _onTabSelected(int i) {
    HapticFeedback.lightImpact();
    setState(() => _index = i);
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
      backgroundColor: Colors.grey.shade50,

      appBar: GreetingAppBar(
        greetingText: auth.greeting(),
        userName: name,
        roleName: role,
        profileUrl: profileUrl,
      ),

      body: SafeArea(
        top: false,
        bottom: false,
        child: PageStorage(
          bucket: _bucket,
          child: IndexedStack(
            index: _index,
            children: _pages,
          ),
        ),
      ),

      bottomNavigationBar: _StandardBottomNavBar(
        currentIndex: _index,
        onTap: _onTabSelected,
      ),
    );
  }
}

/// Standard Material Design Bottom Navigation Bar
/// Matches brand/app theme colors for consistency
class _StandardBottomNavBar extends StatelessWidget {
  const _StandardBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  // Brand colors - matching splash screen exactly
  static const Color _brandPrimary = Color(0xFFA7D222);
  static const Color _brandDark = Color(0xFF8DB71B);
  static const Color _brandTeal = Color(0xFF20B2AA);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _brandPrimary,
            _brandDark,
            _brandTeal,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _brandPrimary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.7),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_outlined),
            activeIcon: Icon(Icons.task),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem_outlined),
            activeIcon: Icon(Icons.report_problem),
            label: 'Issues',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Duty',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_busy_outlined),
            activeIcon: Icon(Icons.event_busy),
            label: 'Leave',
          ),
        ],
      ),
    );
  }
}
