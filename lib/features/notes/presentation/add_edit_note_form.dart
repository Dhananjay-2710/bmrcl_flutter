import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/notes_provider.dart';
import '../models/note.dart';
import '../../../shared/utils/app_snackbar.dart';

class AddEditNoteForm extends StatefulWidget {
  final Note? note;
  const AddEditNoteForm({super.key, this.note});

  @override
  State<AddEditNoteForm> createState() => _AddEditNoteFormState();
}

class _AddEditNoteFormState extends State<AddEditNoteForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  bool _submitting = false;
  bool _canSubmit = false;
  late final String _initialTitle;
  late final String _initialContent;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
    _initialTitle = _titleCtrl.text.trim();
    _initialContent = _contentCtrl.text.trim();
    _titleCtrl.addListener(_updateSubmitState);
    _contentCtrl.addListener(_updateSubmitState);
    _updateSubmitState();
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_updateSubmitState);
    _contentCtrl.removeListener(_updateSubmitState);
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _updateSubmitState() {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final isValid = title.length >= 3 && content.length >= 5;
    final changed = widget.note == null
        ? isValid
        : (title != _initialTitle || content != _initialContent);
    final shouldEnable = isValid && changed;

    if (shouldEnable != _canSubmit || changed != _hasChanges) {
      setState(() {
        _canSubmit = shouldEnable;
        _hasChanges = changed;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.note != null && !_hasChanges) {
      AppSnackBar.error(context, 'No changes to update');
      return;
    }
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      AppSnackBar.error(context, 'Not authenticated');
      return;
    }

    setState(() => _submitting = true);
    final prov = context.read<NotesProvider>();

    try {
      if (widget.note == null) {
        final ok = await prov.create(
            token, _titleCtrl.text.trim(), _contentCtrl.text.trim());
        if (ok) {
          Navigator.pop(context, true);
          AppSnackBar.success(context, 'Note created');
        } else {
          Navigator.pop(context, true);
          AppSnackBar.error(context, 'Failed: ${prov.error}');
        }
      } else {
        final ok = await prov.update(token, widget.note!.id,
            _titleCtrl.text.trim(), _contentCtrl.text.trim());
        if (ok) {
          Navigator.pop(context, true);
          AppSnackBar.success(context, 'Note updated');
        } else {
          Navigator.pop(context, true);
          AppSnackBar.error(context, 'Failed: ${prov.error}');
        }
      }
    } catch (e) {
      AppSnackBar.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.note != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Note' : 'Add Note'),
        backgroundColor: const Color(0xFFA7D222),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Title is required';
                  if (value.length < 3) {
                    return 'Title must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
                maxLines: 6,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Content is required';
                  if (value.length < 5) {
                    return 'Content must be at least 5 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: (_submitting || !_canSubmit) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEdit ? 'Update Note' : 'Create Note',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
