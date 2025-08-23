// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../auth/providers/auth_provider.dart';
// import '../providers/faqs_provider.dart';
// import '../models/faq.dart';
//
// class FaqsTabs extends StatefulWidget {
//   const FaqsTabs({super.key});
//
//   @override
//   State<FaqsTabs> createState() => _FaqsTabState();
// }
//
// class _FaqsTabState extends State<FaqsTabs> {
//   Future<void> _initialLoad() async {
//     final auth = context.read<AuthProvider>();
//     final token = auth.token;
//     if (token == null) return;
//     await context.read<FaqsProvider>().load(token);
//   }
//
//   Future<void> _onRefresh() async {
//     final auth = context.read<AuthProvider>();
//     final token = auth.token;
//     if (token == null) return;
//     await context.read<FaqsProvider>().refresh(token);
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     // Defer until after build context is ready
//     Future.microtask(_initialLoad);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final faqs = context.watch<FaqsProvider>();
//
//     return RefreshIndicator(
//       onRefresh: _onRefresh,
//       child: Builder(
//         builder: (_) {
//           if (faqs.loading && faqs.items.isEmpty) {
//             return ListView(
//               children: [
//                 SizedBox(height: 160),
//                 Center(child: CircularProgressIndicator()),
//               ],
//             );
//           }
//
//           if (faqs.error != null && faqs.items.isEmpty) {
//             return ListView(
//               padding: const EdgeInsets.all(16),
//               children: [
//                 const SizedBox(height: 80),
//                 Icon(Icons.error_outline, color: Colors.red.shade400, size: 40),
//                 const SizedBox(height: 12),
//                 Text(
//                   'Failed to load FAQs',
//                   textAlign: TextAlign.center,
//                   style: Theme.of(context).textTheme.titleMedium,
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   faqs.error!,
//                   textAlign: TextAlign.center,
//                   style: Theme.of(context).textTheme.bodySmall,
//                 ),
//                 const SizedBox(height: 16),
//                 Center(
//                   child: ElevatedButton.icon(
//                     onPressed: _initialLoad,
//                     icon: const Icon(Icons.refresh),
//                     label: const Text('Retry'),
//                   ),
//                 ),
//               ],
//             );
//           }
//
//           final items = faqs.items;
//
//           return ListView.separated(
//             padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
//             itemCount: items.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 8),
//             itemBuilder: (_, i) => _faqTile(context, items[i]),
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _faqTile(BuildContext context, Faq faq) {
//     final theme = Theme.of(context);
//     final cs = theme.colorScheme;
//
//     // Chip colors
//     final Color catFg = cs.primary;
//     final Color catBg = cs.primary.withOpacity(0.12);
//
//     final String priority = (faq.priority ?? '').toLowerCase();
//     final Color priFg = switch (priority) {
//       'high' => Colors.red,
//       'medium' => Colors.orange,
//       'low' => Colors.green,
//       _ => cs.tertiary,
//     };
//     final Color priBg = priFg.withOpacity(0.12);
//
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Theme(
//         // Hide the default ExpansionTile divider
//         data: theme.copyWith(dividerColor: Colors.transparent),
//         child: ExpansionTile(
//           tilePadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
//           shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
//           // Subtle color to make it a little more colorful
//           backgroundColor: cs.primary.withOpacity(0.04),
//           collapsedBackgroundColor: cs.primary.withOpacity(0.02),
//           // leading: Icon(Icons.help_outline, color: cs.primary),
//           title: Text(
//             faq.question,
//             style: const TextStyle(fontWeight: FontWeight.w600),
//           ),
//
//           // ⬇️ One line chips (scroll horizontally if long)
//           subtitle: SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Row(
//               children: [
//                 if (faq.category != null && faq.category!.isNotEmpty)
//                   _chip(faq.category!, Icons.category_outlined, bg: catBg, fg: catFg),
//                 if (faq.priority != null && faq.priority!.isNotEmpty) ...[
//                   const SizedBox(width: 6),
//                   _chip(faq.priority!, Icons.flag_outlined, bg: priBg, fg: priFg),
//                 ],
//                 // if (faq.status != null && faq.status!.isNotEmpty) ...[
//                 //   const SizedBox(width: 6),
//                 //   _chip(faq.status!, Icons.verified_outlined, bg: staBg, fg: staFg),
//                 // ],
//               ],
//             ),
//           ),
//
//           childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
//           children: [
//             if ((faq.description ?? '').isNotEmpty) ...[
//               Text(faq.description!, style: theme.textTheme.bodyMedium),
//               const SizedBox(height: 6),
//             ],
//             _sectionTitle(context, 'Answer'),
//             SelectableText(faq.answer, style: theme.textTheme.bodyLarge),
//             if ((faq.remark ?? '').isNotEmpty) ...[
//               const SizedBox(height: 6),
//               _sectionTitle(context, 'Remark'),
//               Text(faq.remark!),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _chip(String label, IconData icon, {required Color bg, required Color fg}) {
//     return Chip(
//       avatar: Icon(icon, size: 16, color: fg),
//       label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
//       visualDensity: VisualDensity.compact,
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
//       backgroundColor: bg,
//       shape: StadiumBorder(side: BorderSide(color: fg.withOpacity(0.18))),
//       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//     );
//   }
//
//   Widget _sectionTitle(BuildContext context, String text) {
//     final cs = Theme.of(context).colorScheme;
//     return Row(
//       children: [
//         Container(width: 4, height: 16, decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2))),
//         const SizedBox(width: 8),
//         Text(
//           text,
//           style: Theme.of(context).textTheme.titleSmall?.copyWith(
//             fontWeight: FontWeight.bold,
//             color: cs.primary,
//           ),
//         ),
//       ],
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/faqs_provider.dart';
import '../models/faq.dart';

class FaqsTabs extends StatefulWidget {
  const FaqsTabs({super.key});

  @override
  State<FaqsTabs> createState() => _FaqsTabState();
}

class _FaqsTabState extends State<FaqsTabs> {
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
    final faqs = context.watch<FaqsProvider>();
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: Builder(
        builder: (_) {
          if (faqs.loading && faqs.items.isEmpty) {
            return ListView(
              // key: const PageStorageKey('faqs_loading_list'),
              children: const [
                SizedBox(height: 160),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }

          if (faqs.error != null && faqs.items.isEmpty) {
            return ListView(
              // key: const PageStorageKey('faqs_error_list'),
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(height: 80),
                Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                SizedBox(height: 12),
                Text('Failed to load FAQs',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium),
                SizedBox(height: 8),
                Text(
                  faqs.error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                SizedBox(height: 16),
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

          final items = faqs.items;

          return ListView.separated(
            // key: const PageStorageKey('faqs_list'),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _faqTile(
              context,
              items[i],
              i,
              // provide a stable identity for each row
              // key: ValueKey('faq_row_${items[i].id ?? i}'),
            ),
          );
        },
      ),
    );
  }

  /// --- Safe helpers ---
  String _asString(Object? v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  bool _notEmpty(Object? v) => _asString(v).trim().isNotEmpty;

  /// Map arbitrary priority values to a color
  (Color fg, Color bg) _priorityColors(BuildContext context, Object? priorityRaw) {
    final cs = Theme.of(context).colorScheme;
    final p = _asString(priorityRaw).toLowerCase();
    final fg = switch (p) {
      'high'   => Colors.red,
      'medium' => Colors.orange,
      'low'    => Colors.green,
      _        => cs.tertiary,
    };
    // If your Flutter is older, replace .withValues(alpha: 0.12) with .withOpacity(0.12)
    return (fg, fg.withValues(alpha: 0.12));
  }

  Widget _faqTile(BuildContext context, Faq faq, int index, {Key? key}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final question    = _asString(faq.question);
    final answer      = _asString(faq.answer);
    final description = _asString(faq.description);
    final remark      = _asString(faq.remark);
    final category    = _asString(faq.category);

    final catFg = cs.primary;
    final catBg = cs.primary.withValues(alpha: 0.12);

    final (priFg, priBg) = _priorityColors(context, faq.priority);

    // Stable per-tile storage key (prevents identity confusion across rebuilds)
    // final tileKey = PageStorageKey('faq_tile_${faq.id ?? index}');

    return Card(
      key: key,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // key: ValueKey('faq_tile_${faq.id ?? index}'),
          maintainState: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          backgroundColor: cs.primary.withValues(alpha: 0.04),
          collapsedBackgroundColor: cs.primary.withValues(alpha: 0.02),

          title: Text(
            question.isEmpty ? '—' : question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),

          subtitle: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_notEmpty(category))
                  _chip(category, Icons.category_outlined, bg: catBg, fg: catFg),
                if (_notEmpty(faq.priority)) ...[
                  const SizedBox(width: 6),
                  _chip(_asString(faq.priority), Icons.flag_outlined, bg: priBg, fg: priFg),
                ],
              ],
            ),
          ),

          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (description.isNotEmpty) ...[
              Text(description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
            ],
            _sectionTitle(context, 'Answer'),

            // ✅ Use SelectionArea + Text, not SelectableText
            SelectionArea(
              child: Text(
                answer.isEmpty ? '—' : answer,
                style: theme.textTheme.bodyLarge,
              ),
            ),

            if (remark.isNotEmpty) ...[
              const SizedBox(height: 8),
              _sectionTitle(context, 'Remark'),
              Text(remark, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, {required Color bg, required Color fg}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: fg),
      label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      backgroundColor: bg,
      shape: StadiumBorder(side: BorderSide(color: fg.withValues(alpha: 0.18))),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
      ],
    );
  }
}