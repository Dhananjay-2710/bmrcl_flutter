import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tasktype/models/task_type.dart';
import '../../tasktype/providers/task_type_provider.dart';
import '../../users/providers/users_provider.dart';
import '../../devices/providers/devices_provider.dart';
import '../providers/tasks_provider.dart';
import '../../../shared/utils/app_snackbar.dart';

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
  bool _canSubmit = false;

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
    if (usersProv.items.isEmpty ||
        devicesProv.devices.isEmpty ||
        taskTypeProv.allTaskType.isEmpty) {
      setState(() => _loadingLists = true);
      await Future.wait([
        if (usersProv.items.isEmpty) usersProv.load(token),
        if (devicesProv.devices.isEmpty) devicesProv.load(token),
        if (taskTypeProv.allTaskType.isEmpty) taskTypeProv.loadTaskType(token),
      ]);
      setState(() => _loadingLists = false);
      _updateSubmitState();
    } else {
      _updateSubmitState();
    }
  }

  void _updateSubmitState() {
    final hasTaskType = _selectedTaskType != null;
    final hasUser = _selectedUserId != null;
    final hasDevice = _selectedDeviceId != null;
    final hasDueDate = _dueDateTime != null;

    final shouldEnable = hasTaskType && hasUser && hasDevice && hasDueDate;
    if (shouldEnable != _canSubmit) {
      setState(() => _canSubmit = shouldEnable);
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
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay(hour: 18, minute: 0));
    if (time == null) return;
    setState(() {
      _dueDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _updateSubmitState();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_canSubmit) {
      AppSnackBar.error(context, 'Please fill all required fields.');
      return;
    }
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) {
      AppSnackBar.error(context, 'Not authenticated');
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
        AppSnackBar.success(context, 'Task created');
        Navigator.of(context).pop();
      } else {
        AppSnackBar.error(context, 'Failed to create task');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Error: $e');
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
      appBar: AppBar(
        title: const Text('Assign Task'),
        backgroundColor: const Color(0xFFA7D222),
        foregroundColor: Colors.white,
      ),
      body: _loadingLists
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    // Task Type
                    DropdownButtonFormField<TaskType>(
                      value: _selectedTaskType,
                      decoration: const InputDecoration(
                        labelText: 'Task Type',
                        border: OutlineInputBorder(),
                      ),
                      items: taskTypeProv.allTaskType.map((d) {
                        return DropdownMenuItem<TaskType>(
                          value: d,
                          child: Text(d.name),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() => _selectedTaskType = v);
                        _updateSubmitState();
                      },
                      validator: (v) =>
                          v == null ? 'Please select a task type' : null,
                    ),
                    const SizedBox(height: 16),

                    // Assign User
                    DropdownButtonFormField<int>(
                      value: _selectedUserId,
                      decoration: const InputDecoration(
                        labelText: 'Assign User',
                        border: OutlineInputBorder(),
                      ),
                      items: usersProv.items.map((u) {
                        return DropdownMenuItem<int>(
                          value: u.id,
                          child: Text(u.name),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() => _selectedUserId = v);
                        _updateSubmitState();
                      },
                      validator: (v) =>
                          v == null ? 'Please select a user' : null,
                    ),
                    const SizedBox(height: 16),

                    // Device
                    DropdownButtonFormField<int>(
                      value: _selectedDeviceId,
                      decoration: const InputDecoration(
                        labelText: 'Device',
                        border: OutlineInputBorder(),
                      ),
                      items: devicesProv.devices.map((d) {
                        return DropdownMenuItem<int>(
                          value: d.id,
                          child:
                              Text('${d.serialNumber} (${d.type ?? 'Device'})'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() => _selectedDeviceId = v);
                        _updateSubmitState();
                      },
                      validator: (v) =>
                          v == null ? 'Please select a device' : null,
                    ),
                    const SizedBox(height: 16),

                    // Priority
                    DropdownButtonFormField<String>(
                      value: _priority,
                      items: const [
                        DropdownMenuItem(value: 'High', child: Text('High')),
                        DropdownMenuItem(
                            value: 'Medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'Low', child: Text('Low')),
                      ],
                      onChanged: (v) => setState(() => _priority = v ?? 'High'),
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Due Date & Time
                    InkWell(
                      onTap: _pickDueDateTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Due Date & Time',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _dueDateTime == null
                              ? 'Select due date & time'
                              : _formatDateTime(_dueDateTime!),
                          style: TextStyle(
                            color: _dueDateTime == null
                                ? Colors.grey[600]
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (creating || !_canSubmit) ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: creating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Assign Task',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
