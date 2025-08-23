import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../providers/imagepicker_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/task.dart';
import '../providers/tasks_provider.dart';

class TaskDetailsScreen extends StatelessWidget {
  final int taskId;
  const TaskDetailsScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    // margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Title: ${task.title}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Description: ${task.description}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Assigned User : ${task.assignUserName}',
                            style: const TextStyle(fontSize: 16),
                          ),

                          const SizedBox(height: 8),
                          Text(
                            'Device: ${task.assignDeviceSerialNumber}',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Priority: ${task.priority}',
                            style: TextStyle(
                              fontSize: 16,
                              color: _statusColor(task.priority),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Due: ${task.dueDateTime}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Task Image: ',
                            style: const TextStyle(fontSize: 16),
                          ),
                          SizedBox(
                            height: 200,
                            width: 200,
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
                          const SizedBox(height: 8),
                          _taskActionButtons(context, task, prov, token),
                          const SizedBox(height: 8),
                          Row(
                            children: task.status.toLowerCase() != 'completed'
                                ? [
                              // ElevatedButton.icon(
                              //   onPressed: () {
                              //     // TODO: Open edit form
                              //   },
                              //   icon: const Icon(Icons.edit, color: Colors.blue),
                              //   label: const Text('Edit'),
                              // ),
                              // const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Delete Task'),
                                      content: const Text('Are you sure you want to delete this task?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    final success = await prov.deleteTask(token, task.id);
                                    if (success) {
                                      // Pop and send true to indicate deletion
                                      Navigator.pop(context, true);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to delete task')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.delete, color: Colors.red),
                                label: const Text('Delete'),
                              ),
                            ]
                                : [], // Empty list if status is Completed, buttons hidden
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _taskActionButtons(BuildContext context, Task task, TasksProvider prov, String token) {
    if (task.status.toLowerCase() == 'pending') {
      return Row(
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
                  Navigator.pop(context, true); // optionally pop and refresh
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(prov.error ?? 'Failed to start task')),
                  );
                }
              }
            },
            // icon: const Icon(Icons.play_arrow),
            label: const Text('Start Task'),
          ),
        ],
      );
    } else if (task.status.toLowerCase() == 'in progress') {
      return Row(
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              // Step 1: Take photo
              // final image = await _takePhoto();
              // if (image == null) return; // User canceled camera

              final photo = await context
                  .read<ImagePickerProvider>()
                  .pickCompressedImage(source: ImageSource.camera); // or ImageSource.gallery

              if (photo == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No photo captured')),
                );
                return;
              }

              // final File? photo = await pickCompressedImage();
              // if (photo == null) {
              //   ScaffoldMessenger.of(context).showSnackBar(
              //     const SnackBar(content: Text('No photo captured')),
              //   );
              //   return;
              // }

              final image = File(photo.path);

              // Step 2: Show preview and confirm
              final confirm = await _showImagePreviewAndConfirm(context, image);
              if (!confirm) return;

              // Step 3: Call API with image
              final success = await prov.completeTask(token, task.id, taskImage: image);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task completed successfully')));
                Navigator.pop(context, true); // Go back and refresh task list
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(prov.error ?? 'Failed to complete task')));
              }
            },
            label: const Text('Complete Task'),
          ),
        ],
      );
    } else if (task.status.toLowerCase() == 'completed') {
      return  Text(
        'Status: ${task.status}',
        style: TextStyle(
          fontSize: 16,
          color: _statusColor(task.status),
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      return const SizedBox.shrink(); // No buttons for unknown status
    }
  }

  Future<File?> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked != null) {
      return File(picked.path);
    }
    return null;
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