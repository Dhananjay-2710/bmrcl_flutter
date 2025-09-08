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
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question (highlighted)
            Text(
              faq.question.isEmpty ? '—' : faq.question,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(height: 10, thickness: 1),

            // Answer
            _sectionText(context, "Answer", faq.answer),
            const SizedBox(height: 6),

            // Description
            _sectionText(context, "Description", faq.description),
            const SizedBox(height: 6),

            // Remark
            _sectionText(context, "Remark", faq.remark),
            const SizedBox(height: 6),

            // Category
            Row(
              children: [
                Expanded(
                  child: _sectionText(context, "Category", faq.category),
                ),
                const SizedBox(width: 8), // spacing between category & priority
                Expanded(
                  child: _sectionText(context, "Priority", faq.priority),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionText(BuildContext context, String label, String? value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          (value == null || value.isEmpty) ? "—" : value,
          style: theme.textTheme.bodyMedium,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}