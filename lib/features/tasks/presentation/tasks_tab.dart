import 'package:bmrcl/features/tasks/presentation/task_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/tasks_provider.dart';
import '../models/task.dart';
import 'add_task_form.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // to refresh FAB visibility when tab changes
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  Future<void> _initialLoad() async {
    if (_initialLoaded) return;
    _initialLoaded = true;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final token = auth.token;
    if (token == null) return;

    final tasksProv = context.read<TasksProvider>();
    await tasksProv.refreshBoth(token);
  }

  Future<void> _refreshAll() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;
    await context.read<TasksProvider>().loadAll(token);
  }

  Future<void> _refreshMy() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;
    await context.read<TasksProvider>().loadMy(token);
  }

  void _openAssignTaskForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // full height when keyboard opens
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9, // take 90% of screen height
        child: AddTaskForm(tabController: _tabController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksProv = context.watch<TasksProvider>();

    return Scaffold(
      body: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'All Tasks'),
                Tab(text: 'My Tasks'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: _buildTaskList(
                    items: tasksProv.allTasks,
                    loading: tasksProv.loadingAll,
                    error: tasksProv.error,
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _refreshMy,
                  child: _buildTaskList(
                    items: tasksProv.myTasks,
                    loading: tasksProv.loadingMy,
                    error: tasksProv.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
        heroTag: 'Task Tab',
        onPressed: _openAssignTaskForm,
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  Widget _buildTaskList({
    required List<Task> items,
    required bool loading,
    String? error,
  }) {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 40),
          const SizedBox(height: 12),
          Text('Failed to load tasks', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center),
        ],
      );
    }

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        children: const [
          SizedBox(height: 80),
          Center(child: Text('No tasks found')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _taskTile(items[i]),
    );
  }

  Widget _taskTile(Task t) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final due = t.dueDateTime;
    final dueText = due != null
        ? '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')} ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}'
        : 'No due date';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(Icons.task, color: _statusColor(t.status)),
        ),
        title: Text(t.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('Device: ${t.assignDeviceSerialNumber}'),
            const SizedBox(height: 2),
            user?.userId != t.assignUserId
                ?  Text('Assigned to: ${t.assignUserName}')
                :  Text('Assigned to: Me'),
            // Text('Assigned to: ${t.assignUserName}'),
            const SizedBox(height: 2),
            Text('Due: $dueText'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.status,
                style: TextStyle(
                    color: _statusColor(t.status),
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(t.priority,
                  style: TextStyle(
                      fontSize: 12, color: _statusColor(t.priority))),
            ),
          ],
        ),
        onTap: () {
          final auth = context.read<AuthProvider>();
          final token = auth.token;
          if (token != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TaskDetailsScreen(taskId: t.id),
              ),
            ).then((deleted) {
              if (deleted == true) {
                _refreshAll();
                _refreshMy();
              }
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Not authenticated')),
            );
          }
        },
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'in progress':
      case 'in_progress':
      case 'inprogress':
        return Colors.blue;
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.grey;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// Dummy screen for assigning task (replace with your actual form)
class AssignTaskFormScreen extends StatelessWidget {
  const AssignTaskFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Assign Task")),
      body: const Center(child: Text("Task Assignment Form")),
    );
  }
}
