import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
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

  bool _loadingLists = false;

  void _goToTasksTab() {
    widget.tabController.animateTo(0);
    Navigator.pop(context);
  }

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

    // Only fetch if empty to prevent redundant calls
    if (usersProv.items.isEmpty || devicesProv.items.isEmpty) {
      setState(() => _loadingLists = true);
      await Future.wait([
        if (usersProv.items.isEmpty) usersProv.load(token),
        if (devicesProv.items.isEmpty) devicesProv.load(token),
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
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
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
    final creating = context.watch<TasksProvider>().creating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Task'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goToTasksTab, // will switch to Tasks tab and close
        ),
      ),
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
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter title' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
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
                    items: devicesProv.items.map((d) {
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
