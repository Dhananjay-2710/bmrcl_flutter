import 'package:bmrcl/features/tasks/presentation/task_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/tasks_provider.dart';
import '../models/task.dart';
import 'add_task_form.dart';
import '../../../shared/utils/app_snackbar.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab>
    with SingleTickerProviderStateMixin {
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
    if (token == null) {
      AppSnackBar.error(context, 'Not authenticated');
      return;
    }
    await context.read<TasksProvider>().loadAll(token);
  }

  Future<void> _refreshMy() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) {
      AppSnackBar.error(context, 'Not authenticated');
      return;
    }
    await context.read<TasksProvider>().loadMy(token);
  }

  void _openAssignTaskForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskForm(tabController: _tabController),
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
              backgroundColor: const Color(0xFFA7D222),
              child: const Icon(Icons.add, color: Colors.white),
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
    return _TaskCardWidget(
      task: t,
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
          AppSnackBar.error(context, 'Not authenticated');
        }
      },
      statusColor: _statusColor,
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

class _TaskCardWidget extends StatefulWidget {
  final Task task;
  final VoidCallback onTap;
  final Color Function(String) statusColor;

  const _TaskCardWidget({
    required this.task,
    required this.onTap,
    required this.statusColor,
  });

  @override
  State<_TaskCardWidget> createState() => _TaskCardWidgetState();
}

class _TaskCardWidgetState extends State<_TaskCardWidget> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final task = widget.task;

    final dueText = task.formattedDueDate ?? 'No due date';

    final statusColor = widget.statusColor(task.status);
    final priorityColor = widget.statusColor(task.priority);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Task Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: task.taskImageURL != null &&
                              task.taskImageURL!.isNotEmpty
                          ? Image.network(
                              task.taskImageURL!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: Icon(Icons.task,
                                    color: statusColor, size: 24),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.task,
                                  color: statusColor, size: 24),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Center: Task Title, Assigned User, Priority & Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row 1: Task Title
                        Text(
                          task.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Row 2: Assigned User
                        Text(
                          user?.userId != task.assignUserId
                              ? 'Assigned to: ${task.assignUserName}'
                              : 'Assigned to: Me',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Row 3: Priority and Status
                        Row(
                          children: [
                            // Priority Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                task.priority,
                                style: TextStyle(
                                  color: priorityColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                task.status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Right: Arrow (expand/collapse)
                  IconButton(
                    icon: Icon(
                      _showDetails ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        _showDetails = !_showDetails;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: _showDetails ? 'Hide Details' : 'View Details',
                  ),
                ],
              ),
              // Expandable Details Section
              if (_showDetails) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.devices_other,
                  label: 'Device',
                  value: task.assignDeviceSerialNumber,
                ),
                const SizedBox(height: 6),
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: 'Due Date',
                  value: dueText,
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _DetailRow(
                    icon: Icons.description,
                    label: 'Description',
                    value: task.description,
                    maxLines: 2,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black87,
              fontSize: 12,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
