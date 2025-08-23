import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/notes_provider.dart';
import '../models/note.dart';
import 'add_edit_note_form.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final token = context.read<AuthProvider>().token;
      if (token != null) {
        context.read<NotesProvider>().fetchNotes(token);
      }
    });
  }

  Future<void> _refresh() async {
    final token = context.read<AuthProvider>().token;
    if (token != null) await context.read<NotesProvider>().fetchNotes(token);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NotesProvider>();
    final auth = context.read<AuthProvider>();
    final token = auth.token;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: prov.loading && prov.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : prov.items.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No notes found')),
          ],
        )
            : ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: prov.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final note = prov.items[i];
            return _noteCard(note, token);
          },
        ),
      ),
      floatingActionButton: token == null
          ? null
          : FloatingActionButton(
        onPressed: () => _openAddForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openAddForm({Note? note}) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddEditNoteForm(note: note),
    );

    if (result == true) {
      // Refresh notes after add/update
      await context.read<NotesProvider>().fetchNotes(token);
    }
  }

  Widget _noteCard(Note note, String? token) {
    final prov = context.read<NotesProvider>();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.note)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                    note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note.formattedCreatedAt,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  // _openAddForm(note: note);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AddEditNoteForm(note: note),
                  );
                } else if (v == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete Note'),
                      content: const Text('Are you sure you want to delete this note?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final token = context.read<AuthProvider>().token;
                    if (token == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated')));
                      return;
                    }
                    final success = await prov.delete(token, note.id);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note deleted')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${prov.error}')));
                    }
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
