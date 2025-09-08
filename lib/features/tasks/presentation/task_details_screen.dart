import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../providers/imagepicker_provider.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/task.dart';
import '../providers/tasks_provider.dart';

class TaskDetailsScreen extends StatelessWidget {
  final int taskId;
  const TaskDetailsScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final token = auth.token!;

    return ChangeNotifierProvider(
      create: (_) => TasksProvider()..loadTask(token, taskId),
      child: Consumer<TasksProvider>(
        builder: (context, prov, _) {
          if (prov.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (prov.error != null) return Scaffold(body: Center(child: Text(prov.error!)));

          final task = prov.task!;
          return Scaffold(
            appBar: AppBar(
              title: Text('Task Details'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              task.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Description
                            _infoRow("Description", task.description),

                            // Assigned User
                            user?.userId != task.assignUserId
                                ? _infoRow("Assigned User", task.assignUserName)
                                : _infoRow("Assigned User", 'Me'),

                            // Device
                            _infoRow("Device", task.assignDeviceSerialNumber),

                            // Priority with colored value
                            Row(
                              children: [
                                const Text(
                                  "Priority: ",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  task.priority,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _statusColor(task.priority),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Due Date
                            _infoRow("Due", task.dueDateTime.toString()),

                            const SizedBox(height: 8),

                            // Task Image
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Task Image",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    height: 200,
                                    width: double.infinity,
                                    child: task.taskImageURL != null && task.taskImageURL!.isNotEmpty
                                        ? Image.network(
                                      task.taskImageURL!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Image.asset(
                                          'assets/images/dummy_image.jpg',
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    )
                                        : Image.asset(
                                      'assets/images/dummy_image.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Custom Task Action Buttons
                            _taskActionButtons(context, task, user!, prov, token),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskActionButtons(
      BuildContext context,
      Task task,
      User user,
      TasksProvider prov,
      String token,
      ) {
    final status = task.status.toLowerCase();

    if (status == 'pending' && user.userId == task.assignUserId) {
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Start Task'),
                  content: const Text('Are you sure you want to start this task?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start')),
                  ],
                ),
              );
              if (confirm == true) {
                final success = await prov.startTask(token, task.id);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task started successfully')),
                  );
                  Navigator.pop(context, true); // refresh
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(prov.error ?? 'Failed to start task')),
                  );
                }
              }
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Task'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Colors.green),
            ),
          ),

          // 📝 Edit
          // if (user.role == 'super_admin' || user.role == 'Admin')
          // OutlinedButton.icon(
          //   onPressed: () {
              // TODO: Navigate to edit form
              // Navigator.push(
                // context,
                // MaterialPageRoute(
                  // builder: (_) => EditTaskForm(task: task),
                // ),
              // );
          //   },
          //   icon: const Icon(Icons.edit, color: Colors.blue),
          //   label: const Text('Edit'),
          // ),

          // ❌ Delete
          if (user.role == 'super_admin' || user.role == 'Admin')
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete Task'),
                  content: const Text('Are you sure you want to delete this task?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              );

              if (confirm == true) {
                final success = await prov.deleteTask(token, task.id);
                if (success) {
                  Navigator.pop(context, true); // refresh
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete task')),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      );
    }

    // 🟡 IN PROGRESS → Show "Complete Task"
    else if (status == 'in progress' && user.userId == task.assignUserId) {
      return ElevatedButton.icon(
        onPressed: () async {
          // Step 1: Pick Image
          final photo = await context
              .read<ImagePickerProvider>()
              .pickCompressedImage(source: ImageSource.camera);

          if (photo == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No photo captured')),
            );
            return;
          }

          final image = File(photo.path);

          // Step 2: Confirm Preview
          final confirm = await _showImagePreviewAndConfirm(context, image);
          if (!confirm) return;

          // Step 3: API Call
          final success = await prov.completeTask(token, task.id, taskImage: image);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Task completed successfully')),
            );
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(prov.error ?? 'Failed to complete task')),
            );
          }
        },
        icon: const Icon(Icons.check_circle),
        label: const Text('Complete Task'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Colors.green),
        ),
      );
    }

    // 🔵 COMPLETED → Just show status
    else if (status == 'completed') {
      return Text(
        'Status: ${task.status}',
        style: TextStyle(
          fontSize: 16,
          color: _statusColor(task.status),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // ⚪ DEFAULT → Empty
    else {
      return const SizedBox.shrink();
    }
  }

  Future<bool> _showImagePreviewAndConfirm(BuildContext context,File image) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Task Preview'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(image, height: 200),
            const SizedBox(height: 12),
            const Text('Are you sure you want to complete this task?'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Complete')),
        ],
      ),
    ) ??
        false;
  }
  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'in_progress':
        return Colors.blue;
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
}