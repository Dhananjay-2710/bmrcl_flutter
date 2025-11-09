import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/faqs_provider.dart';
import '../models/faq.dart';


class FaqsTabs extends StatefulWidget {
  const FaqsTabs({super.key});

  @override
  State<FaqsTabs> createState() => _FaqsTabsState();
}

class _FaqsTabsState extends State<FaqsTabs> {
  Future<void> _initialLoad() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context.read<FaqsProvider>().load(token);
  }

  Future<void> _onRefresh() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context.read<FaqsProvider>().refresh(token);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_initialLoad);
  }

  @override
  Widget build(BuildContext context) {
    final faqsProvider = context.watch<FaqsProvider>();
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: Builder(
        builder: (_) {
          if (faqsProvider.loading && faqsProvider.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (faqsProvider.error != null && faqsProvider.items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 80),
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                const SizedBox(height: 12),
                Text('Failed to load FAQs',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  faqsProvider.error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _initialLoad,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            );
          }

          final items = faqsProvider.items;

          if (items.isEmpty) {
            return const Center(child: Text("No FAQs available"));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _faqQuestionCard(context, items[i]),
          );
        },
      ),
    );
  }

  Widget _faqQuestionCard(BuildContext context, Faq faq) {
    return _FaqCardWidget(faq: faq);
  }
}

class _FaqCardWidget extends StatefulWidget {
  final Faq faq;

  const _FaqCardWidget({required this.faq});

  @override
  State<_FaqCardWidget> createState() => _FaqCardWidgetState();
}

class _FaqCardWidgetState extends State<_FaqCardWidget> {
  bool _showDetails = false;

  Color _priorityColor(String? priority) {
    if (priority == null) return Colors.grey;
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final faq = widget.faq;
    final theme = Theme.of(context);
    final priorityColor = _priorityColor(faq.priority);

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
                // Left: FAQ Icon
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(Icons.help_outline, color: Colors.grey[700], size: 20),
                ),
                const SizedBox(width: 10),
                // Center: Question, Category & Priority
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: Question
                      Text(
                        faq.question.isEmpty ? '—' : faq.question,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Row 2: Category and Priority Badges
                      Row(
                        children: [
                          // Category Badge
                          if (faq.category != null && faq.category!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                faq.category!,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (faq.category != null && faq.category!.isNotEmpty && faq.priority != null && faq.priority!.isNotEmpty)
                            const SizedBox(width: 8),
                          // Priority Badge
                          if (faq.priority != null && faq.priority!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                faq.priority!,
                                style: TextStyle(
                                  color: priorityColor,
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
              // Answer
              if (faq.answer != null && faq.answer!.isNotEmpty) ...[
                _DetailRow(
                  icon: Icons.question_answer,
                  label: 'Answer',
                  value: faq.answer!,
                ),
                const SizedBox(height: 8),
              ],
              // Description
              if (faq.description != null && faq.description!.isNotEmpty) ...[
                _DetailRow(
                  icon: Icons.description,
                  label: 'Description',
                  value: faq.description!,
                ),
                const SizedBox(height: 8),
              ],
              // Remark
              if (faq.remark != null && faq.remark!.isNotEmpty) ...[
                _DetailRow(
                  icon: Icons.comment,
                  label: 'Remark',
                  value: faq.remark!,
                ),
                const SizedBox(height: 8),
              ],
              // Category and Priority with background
              Row(
                children: [
                  if (faq.category != null && faq.category!.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.category, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Category',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              faq.category!,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (faq.category != null && faq.category!.isNotEmpty && faq.priority != null && faq.priority!.isNotEmpty)
                    const SizedBox(width: 12),
                  if (faq.priority != null && faq.priority!.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.priority_high, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Priority',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              faq.priority!,
                              style: TextStyle(
                                color: priorityColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}