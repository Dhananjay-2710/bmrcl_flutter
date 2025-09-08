import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tasktype/models/task_type.dart';
import '../../tasktype/providers/task_type_provider.dart';
import '../../users/providers/users_provider.dart';
import '../../devices/providers/devices_provider.dart';
import '../providers/tasks_provider.dart';

class AddTaskForm extends StatefulWidget {
  final TabController tabController;
  const AddTaskForm({super.key, required this.tabController});

  @override
  State<AddTaskForm> createState() => _AddTaskFormState();
}

class _AddTaskFormState extends State<AddTaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _priority = 'High';
  DateTime? _dueDateTime;

  int? _selectedUserId;
  int? _selectedDeviceId;
  TaskType? _selectedTaskType;

  bool _loadingLists = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLists());
  }

  Future<void> _ensureLists() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    final usersProv = context.read<UsersProvider>();
    final devicesProv = context.read<DevicesProvider>();
    final taskTypeProv = context.read<TaskTypeProvider>();
    // Only fetch if empty to prevent redundant calls
    if (usersProv.items.isEmpty || devicesProv.devices.isEmpty || taskTypeProv.allTaskType.isEmpty) {
      setState(() => _loadingLists = true);
      await Future.wait([
        if (usersProv.items.isEmpty) usersProv.load(token),
        if (devicesProv.devices.isEmpty) devicesProv.load(token),
        if (taskTypeProv.allTaskType.isEmpty) taskTypeProv.loadTaskType(token),
      ]);
      setState(() => _loadingLists = false);
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _pickDueDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: 18, minute: 0));
    if (time == null) return;
    setState(() {
      _dueDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated')));
      return;
    }

    final tasksProv = context.read<TasksProvider>();

    final body = {
      'title': _selectedTaskType?.name ?? '',
      'description': _selectedTaskType?.description ?? '',
      'assign_user_id': _selectedUserId,
      'priority': _priority,
      'due_datetime': _formatDateTime(_dueDateTime!),
      'device_id': _selectedDeviceId,
    };

    try {
      final created = await tasksProv.createTask(token, body);

      if (created) {
        widget.tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create task')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersProv = context.watch<UsersProvider>();
    final devicesProv = context.watch<DevicesProvider>();
    final taskTypeProv = context.watch<TaskTypeProvider>();
    final creating = context.watch<TasksProvider>().creating;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _loadingLists
                      ? const SizedBox.shrink()
                      : DropdownButtonFormField<TaskType>(
                    value: _selectedTaskType,
                    decoration: const InputDecoration(labelText: 'Task Type'),
                    items: taskTypeProv.allTaskType.map((d) {
                      return DropdownMenuItem<TaskType>(
                        value: d,
                        child: Text(d.name),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedTaskType = v),
                    validator: (v) => v == null ? 'Please select a task type' : null,
                  ),

                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  // USERS dropdown
                  _loadingLists ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  ): DropdownButtonFormField<int>(
                    value: _selectedUserId,
                    decoration: const InputDecoration(labelText: 'Assign User'),
                    items: usersProv.items.map((u) {
                      return DropdownMenuItem<int>(
                        value: u.id,
                        child: Text(u.name),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedUserId = v),
                    validator: (v) => v == null ? 'Please select a user' : null,
                  ),

                  const SizedBox(height: 8),

                  // DEVICES dropdown
                  _loadingLists
                      ? const SizedBox.shrink()
                      : DropdownButtonFormField<int>(
                    value: _selectedDeviceId,
                    decoration: const InputDecoration(labelText: 'Device'),
                    items: devicesProv.devices.map((d) {
                      return DropdownMenuItem<int>(
                        value: d.id,
                        child: Text('${d.serialNumber} (${d.type ?? 'Device'})'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedDeviceId = v),
                    validator: (v) => v == null ? 'Please select a device' : null,
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _priority,
                          items: const [
                            DropdownMenuItem(value: 'High', child: Text('High')),
                            DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                          ],
                          onChanged: (v) => setState(() => _priority = v ?? 'High'),
                          decoration: const InputDecoration(labelText: 'Priority'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDueDateTime,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_dueDateTime == null ? 'Pick Due' : _formatDateTime(_dueDateTime!)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ... rest of your form widgets ...
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: creating ? null : _submit,
                      child: creating
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text('Assign Task'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
