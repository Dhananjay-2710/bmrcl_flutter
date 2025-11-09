import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/leave_provider.dart';
import '../models/leave.dart';
import '../../../shared/utils/app_snackbar.dart';
import 'add_leave_form.dart';
import 'edit_leave_form.dart';

enum _SnackTone { info, success, error }

class LeaveTab extends StatefulWidget {
  const LeaveTab({super.key});

  @override
  State<LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends State<LeaveTab> {
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  Future<void> _initialLoad() async {
    if (_initialLoaded) return;
    _initialLoaded = true;

    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    final leaveProv = context.read<LeaveProvider>();

    // Check permissions to determine what to load
    final perms = auth.user?.permissions ?? const <String>[];
    final hasPermission = perms.contains('all') ||
        perms.contains('leave.review') ||
        perms.contains('leave.approve');

    if (hasPermission) {
      await leaveProv.refreshBoth(token);
    } else {
      await leaveProv.loadMy(token);
    }
  }

  Future<void> _refreshAll() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;
    await context.read<LeaveProvider>().loadAll(token);
  }

  Future<void> _refreshMy() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;
    await context.read<LeaveProvider>().loadMy(token);
  }

  void _showSnack(BuildContext context, String message,
      {_SnackTone tone = _SnackTone.info}) {
    switch (tone) {
      case _SnackTone.success:
        AppSnackBar.success(context, message);
        break;
      case _SnackTone.error:
        AppSnackBar.error(context, message);
        break;
      case _SnackTone.info:
      default:
        AppSnackBar.info(context, message);
        break;
    }
  }

  void _openAddForm() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddLeaveForm()),
    );

    if (result == true) {
      await _refreshAll();
      await _refreshMy();
    }
  }

  void _handleReview(Leave leave) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ReviewDialog(
        leaveId: leave.id,
        onReview: (remarks) async {
          final token = context.read<AuthProvider>().token;
          if (token == null) {
            if (!dialogContext.mounted) return false;
            _showSnack(dialogContext, 'Not authenticated',
                tone: _SnackTone.error);
            return false;
          }

          final prov = context.read<LeaveProvider>();
          final success = await prov.reviewLeave(token, leave.id, remarks);

          if (!dialogContext.mounted) return false;

          if (success) {
            Navigator.of(dialogContext).pop(); // Close dialog
            if (mounted) {
              _showSnack(context, 'Leave reviewed successfully ✅',
                  tone: _SnackTone.success);
              await _refreshAll();
              await _refreshMy();
            }
            return true;
          } else {
            _showSnack(
              dialogContext,
              'Failed to review leave: ${prov.error ?? "Unknown error"}',
              tone: _SnackTone.error,
            );
            return false;
          }
        },
      ),
    );
  }

  void _handleApprove(Leave leave) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ApproveDialog(
        leaveId: leave.id,
        onApprove: (remarks) async {
          final token = context.read<AuthProvider>().token;
          if (token == null) {
            if (!dialogContext.mounted) return false;
            _showSnack(dialogContext, 'Not authenticated',
                tone: _SnackTone.error);
            return false;
          }

          final prov = context.read<LeaveProvider>();
          final success = await prov.approveLeave(token, leave.id, remarks);

          if (!dialogContext.mounted) return false;

          if (success) {
            Navigator.of(dialogContext).pop(); // Close dialog
            if (mounted) {
              _showSnack(context, 'Leave approved successfully ✅',
                  tone: _SnackTone.success);
              await _refreshAll();
              await _refreshMy();
            }
            return true;
          } else {
            _showSnack(
              dialogContext,
              'Failed to approve leave: ${prov.error ?? "Unknown error"}',
              tone: _SnackTone.error,
            );
            return false;
          }
        },
      ),
    );
  }

  void _handleEdit(Leave leave) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditLeaveForm(leave: leave)),
    ).then((result) {
      if (result == true) {
        _refreshAll();
        _refreshMy();
      }
    });
  }

  void _handleDelete(Leave leave) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Leave Request'),
        content:
            const Text('Are you sure you want to delete this leave request?'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              final token = context.read<AuthProvider>().token;
              if (token == null) {
                if (!mounted) return;
                _showSnack(context, 'Not authenticated',
                    tone: _SnackTone.error);
                return;
              }

              final prov = context.read<LeaveProvider>();
              final success = await prov.deleteLeave(token, leave.id);

              if (!mounted) return;

              if (success) {
                _showSnack(context, 'Leave request deleted successfully ✅',
                    tone: _SnackTone.success);
                await _refreshAll();
                await _refreshMy();
              } else {
                _showSnack(
                  context,
                  'Failed to delete leave: ${prov.error ?? "Unknown error"}',
                  tone: _SnackTone.error,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<LeaveProvider>();

    // Check permissions: show "Leave Request" tab only if user has 'leave.review' or 'leave.approve' permission
    final hasLeavePermission = context.select<AuthProvider, bool>((auth) {
      final perms = auth.user?.permissions ?? const <String>[];
      if (perms.contains('all')) return true;
      return perms.contains('leave.review') || perms.contains('leave.approve');
    });

    final tabCount = hasLeavePermission ? 2 : 1;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        body: Column(
          children: [
            Material(
              color: Colors.white,
              child: TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: [
                  if (hasLeavePermission) const Tab(text: 'Leave Request'),
                  const Tab(text: 'My Leave'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  if (hasLeavePermission)
                    RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: _buildLeaveList(
                        items: prov.allLeaves,
                        loading: prov.loadingAll,
                        error: prov.error,
                        isAdminTab: true,
                      ),
                    ),
                  RefreshIndicator(
                    onRefresh: _refreshMy,
                    child: _buildLeaveList(
                      items: prov.myLeaves,
                      loading: prov.loadingMy,
                      error: prov.error,
                      isAdminTab: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                final currentIndex = tabController.index;
                // Show FAB on My Leave tab:
                // - If has permission: My Leave is at index 1
                // - If no permission: My Leave is at index 0
                final isMyLeaveTab =
                    hasLeavePermission ? currentIndex == 1 : currentIndex == 0;
                return isMyLeaveTab
                    ? FloatingActionButton(
                        heroTag: 'Leave Tab',
                        onPressed: _openAddForm,
                        backgroundColor: const Color(0xFFA7D222),
                        child: const Icon(Icons.add, color: Colors.white),
                      )
                    : const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeaveList({
    required List<Leave> items,
    required bool loading,
    String? error,
    required bool isAdminTab,
  }) {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 40),
          const SizedBox(height: 12),
          const Text('Failed to load leave requests',
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center),
        ],
      );
    }

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No leave requests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  !isAdminTab
                      ? 'Tap + to request leave'
                      : 'No leave requests to review',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _leaveCard(items[i], isAdminTab: isAdminTab),
    );
  }

  Widget _leaveCard(Leave leave, {required bool isAdminTab}) {
    return _LeaveCardWidget(
      leave: leave,
      isAdminTab: isAdminTab,
      onReview: _handleReview,
      onApprove: _handleApprove,
      onEdit: _handleEdit,
      onDelete: _handleDelete,
    );
  }
}

class _LeaveCardWidget extends StatefulWidget {
  final Leave leave;
  final bool isAdminTab;
  final void Function(Leave) onReview;
  final void Function(Leave) onApprove;
  final void Function(Leave) onEdit;
  final void Function(Leave) onDelete;

  const _LeaveCardWidget({
    required this.leave,
    required this.isAdminTab,
    required this.onReview,
    required this.onApprove,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_LeaveCardWidget> createState() => _LeaveCardWidgetState();
}

class _LeaveCardWidgetState extends State<_LeaveCardWidget> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final leave = widget.leave;

    Color statusColor;
    IconData statusIcon;

    switch (leave.status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    final isApprovedOrRejected = leave.status.toLowerCase() == 'approved' ||
        leave.status.toLowerCase() == 'rejected';
    final isPending = leave.status.toLowerCase() == 'pending';
    final isReviewed = leave.status.toLowerCase() == 'reviewed';
    final showAdminActions =
        widget.isAdminTab; // Review/Approve only in "Leave Request" tab
    final showUserActions = !widget.isAdminTab &&
        user?.userId ==
            leave.userId; // Edit/Delete only in "My Leave" tab for own requests
    final canEditOrDelete = isPending ||
        !isApprovedOrRejected; // Can only edit/delete if not approved/rejected

    // Check if start and end dates are the same
    final isSameDate = leave.startDate != null &&
        leave.endDate != null &&
        leave.startDate!.year == leave.endDate!.year &&
        leave.startDate!.month == leave.endDate!.month &&
        leave.startDate!.day == leave.endDate!.day;

    // Calculate number of days if dates are different
    int? numberOfDays;
    if (!isSameDate && leave.startDate != null && leave.endDate != null) {
      numberOfDays = leave.endDate!.difference(leave.startDate!).inDays + 1;
    }

    final hasDetails = leave.reason != null ||
        leave.remarks != null ||
        leave.approvedRemarks != null;

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
                // Left: User Profile Image
                CircleAvatar(
                  radius: 20,
                  backgroundImage: leave.userProfileImageUrl != null &&
                          leave.userProfileImageUrl!.isNotEmpty
                      ? NetworkImage(leave.userProfileImageUrl!)
                      : const AssetImage('assets/images/profile.jpg')
                          as ImageProvider,
                  onBackgroundImageError: (_, __) {},
                  child: leave.userProfileImageUrl == null ||
                          leave.userProfileImageUrl!.isEmpty
                      ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                      : null,
                ),
                const SizedBox(width: 10),
                // Center: Two rows - (Leave Type + User Name), (Status + Date/Days)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: Leave Type and User Name
                      Row(
                        children: [
                          // Leave Type
                          Text(
                            '${leave.leaveType ?? 'Leave'} Leave',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          // User Name (only in admin tab when collapsed)
                          if (widget.isAdminTab &&
                              leave.userName != null &&
                              leave.userName!.isNotEmpty &&
                              !_showDetails) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                leave.userName!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Row 2: Status and Date/Days
                      Row(
                        children: [
                          // Status
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: statusColor, size: 10),
                                const SizedBox(width: 4),
                                Text(
                                  leave.status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Date or Days
                          Icon(Icons.calendar_today,
                              size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            isSameDate
                                ? leave.formattedStartDate
                                : numberOfDays != null
                                    ? '$numberOfDays ${numberOfDays == 1 ? 'Day' : 'Days'}'
                                    : '—',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Right: Arrow (vertically centered)
                if (hasDetails)
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
            if (_showDetails) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if (leave.userName != null &&
                  leave.userName!.isNotEmpty &&
                  (widget.isAdminTab || user?.userId != leave.userId)) ...[
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Requested by',
                  value: leave.userName!,
                ),
                const SizedBox(height: 8),
              ],
              if (!isSameDate) ...[
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'Start Date',
                  value: leave.formattedStartDate,
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  icon: Icons.event,
                  label: 'End Date',
                  value: leave.formattedEndDate,
                ),
                const SizedBox(height: 8),
              ],
              if (leave.reason != null && leave.reason!.isNotEmpty) ...[
                _InfoRow(
                  icon: Icons.description,
                  label: 'Reason',
                  value: leave.reason!,
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
              ],
              if (leave.remarks != null && leave.remarks!.isNotEmpty) ...[
                _InfoRow(
                  icon: Icons.comment,
                  label: 'Remarks',
                  value: leave.remarks!,
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
              ],
              if (leave.approvedRemarks != null &&
                  leave.approvedRemarks!.isNotEmpty) ...[
                _InfoRow(
                  icon: Icons.check_circle_outline,
                  label: 'Approved Remarks',
                  value: leave.approvedRemarks!,
                  maxLines: 3,
                ),
              ],
            ],
            if (showAdminActions && (isPending || isReviewed)) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (isPending)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isApprovedOrRejected
                            ? null
                            : () => widget.onReview(leave),
                        icon: const Icon(Icons.visibility,
                            size: 16, color: Colors.white),
                        label: const Text('Review',
                            style:
                                TextStyle(fontSize: 12, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ),
                  if (isPending) const SizedBox(width: 8),
                  if (isReviewed)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isApprovedOrRejected
                            ? null
                            : () => widget.onApprove(leave),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (showUserActions && canEditOrDelete) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onEdit(leave),
                      icon:
                          const Icon(Icons.edit, size: 16, color: Colors.white),
                      label: const Text('Edit',
                          style: TextStyle(fontSize: 12, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onDelete(leave),
                      icon: const Icon(Icons.delete,
                          size: 16, color: Colors.white),
                      label: const Text('Delete',
                          style: TextStyle(fontSize: 12, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
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

class _ApproveDialog extends StatefulWidget {
  final int leaveId;
  final Future<bool> Function(String) onApprove;

  const _ApproveDialog({
    required this.leaveId,
    required this.onApprove,
  });

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    final success = await widget.onApprove(_remarksController.text.trim());
    if (mounted && !success) {
      // Only reset if approval failed (dialog still open)
      setState(() => _submitting = false);
    }
    // If success, dialog will be closed by the callback
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text('Approve Leave', style: theme.textTheme.titleMedium),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter approval remarks',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarksController,
                decoration: InputDecoration(
                  labelText: 'Approval Remarks',
                  hintText: 'Enter your approval remarks...',
                  prefixIcon: const Icon(Icons.comment),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade600),
                  ),
                ),
                maxLines: 4,
                enabled: !_submitting,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter approval remarks';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: ElevatedButton(
                onPressed:
                    _submitting ? null : () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Approval'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  final int leaveId;
  final Future<bool> Function(String) onReview;

  const _ReviewDialog({
    required this.leaveId,
    required this.onReview,
  });

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    final success = await widget.onReview(_remarksController.text.trim());
    if (mounted && !success) {
      // Only reset if review failed (dialog still open)
      setState(() => _submitting = false);
    }
    // If success, dialog will be closed by the callback
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.visibility, color: Colors.blue, size: 20),
          const SizedBox(width: 10),
          Text('Review Leave', style: theme.textTheme.titleMedium),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter review remarks',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarksController,
                decoration: InputDecoration(
                  labelText: 'Review Remarks',
                  hintText: 'Enter your review remarks...',
                  prefixIcon: const Icon(Icons.comment),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade600),
                  ),
                ),
                maxLines: 4,
                enabled: !_submitting,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter review remarks';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: ElevatedButton(
                onPressed:
                    _submitting ? null : () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black87,
              fontSize: 12,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
