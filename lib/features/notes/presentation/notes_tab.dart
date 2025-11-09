import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/notes_provider.dart';
import '../models/note.dart';
import 'add_edit_note_form.dart';
import '../../../shared/utils/app_snackbar.dart';

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
                    children: [
                      const SizedBox(height: 100),
                      Icon(Icons.note_add_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'No notes yet',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Tap the + button to create your first note',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ),
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
              backgroundColor: const Color(0xFFA7D222),
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  void _openAddForm({Note? note}) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditNoteForm(note: note),
      ),
    );

    if (result == true) {
      // Refresh notes after add/update
      await context.read<NotesProvider>().fetchNotes(token);
    }
  }

  Widget _noteCard(Note note, String? token) {
    return _NoteCardWidget(
      note: note,
      onEdit: () => _openAddForm(note: note),
      onDelete: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Note'),
            content: const Text('Are you sure you want to delete this note?'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          final token = context.read<AuthProvider>().token;
          if (token == null) {
            AppSnackBar.error(context, 'Not authenticated');
            return;
          }
          final prov = context.read<NotesProvider>();
          final success = await prov.delete(token, note.id);
          if (success) {
            AppSnackBar.success(context, 'Note deleted');
          } else {
            AppSnackBar.error(context, 'Failed: ${prov.error}');
          }
        }
      },
    );
  }
}

class _NoteCardWidget extends StatefulWidget {
  final Note note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteCardWidget({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_NoteCardWidget> createState() => _NoteCardWidgetState();
}

class _NoteCardWidgetState extends State<_NoteCardWidget> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Note Icon
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(Icons.note, color: Colors.grey[700], size: 20),
                ),
                const SizedBox(width: 10),
                // Center: Title, Content Preview, Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: Title
                      Text(
                        note.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Row 2: Content Preview
                      Text(
                        note.content,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Row 3: Date
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            note.formattedCreatedAt,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
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
              // Full Content
              Text(
                note.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              // Edit and Delete Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                    label: const Text('Edit',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: widget.onDelete,
                    icon:
                        const Icon(Icons.delete, size: 16, color: Colors.white),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
