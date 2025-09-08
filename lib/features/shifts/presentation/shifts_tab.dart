import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import '../../../providers/imagepicker_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../users/providers/users_provider.dart';
import '../models/assign_shift_models.dart';
import '../models/lookup_models.dart';
import '../models/my_shifts_models.dart';
import '../models/week_off.dart';
import '../providers/lookup_provider.dart';
import '../providers/shift_assign_provider.dart';
import '../providers/shifts_provider.dart';
import '../providers/week_off_provider.dart';

class ShiftsTab extends StatefulWidget {
  const ShiftsTab({super.key});

  @override
  State<ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<ShiftsTab> with SingleTickerProviderStateMixin {
  TabController? _tabCtrl;
  bool get _hasAssignShiftView {
    final perms = context.read<AuthProvider>().user?.permissions ?? const <String>[];
    print("Permision : $perms");
    if (perms.contains('all')) return true;
    return perms.contains('assignshift.view');
  }

  void _initOrUpdateTabController({bool force = false}) {
    final len = _hasAssignShiftView ? 3 : 1;
    print("len $len");
    if (_tabCtrl == null || force || _tabCtrl!.length != len) {
      final initialIndex = (_tabCtrl?.index ?? 0).clamp(0, len - 1);
      _tabCtrl?.dispose();
      _tabCtrl = TabController(length: len, vsync: this, initialIndex: initialIndex);
      setState(() {}); // trigger rebuild after creating controller
    }
  }

  @override
  void initState() {
    super.initState();

    _initOrUpdateTabController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final token = context.read<AuthProvider>().token;
      if (token != null) {
        context.read<ShiftsProvider>().fetchMyShifts(token);
        context.read<LookupProvider>().ensureBasics(token);
        context.read<UsersProvider>().load(token);
        if (_hasAssignShiftView) {
          context.read<ShiftAssignProvider>().fetchAll(token);
        }
      }
      _initOrUpdateTabController();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initOrUpdateTabController();
  }

  // @override
  // void initState() {
  //   super.initState();
  //   _tabCtrl = TabController(length: 2, vsync: this);
  //
  //   // Load My Shifts on open
  //   Future.microtask(() {
  //     final token = context.read<AuthProvider>().token;
  //     if (token != null) {
  //       context.read<ShiftsProvider>().fetchMyShifts(token);
  //       context.read<ShiftAssignProvider>().fetchAll(token);
  //       context.read<LookupProvider>().ensureBasics(token);
  //       context.watch<UsersProvider>().load(token);
  //     }
  //   });
  // }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  Future<void> _refreshMy() async {
    final token = context.read<AuthProvider>().token;
    if (token != null) await context.read<ShiftsProvider>().fetchMyShifts(token);
  }

  // ======== CHECK-IN / OUT LOGIC ========

  Future<void> _handleCheckIn(BuildContext context, int assignmentId) async {
    final prov = context.read<ShiftsProvider>();
    final token = context.read<AuthProvider>().token;
    final a = prov.todaysAssignment;
    if (token == null || a == null) return;
    final photo = await context
        .read<ImagePickerProvider>()
        .pickCompressedImage(source: ImageSource.camera);

    if (photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photo captured')),
      );
      return;
    }

    // Step 2: Get location for preview (provider will read again before submit)
    final location = Location();
    final pos = await location.getLocation();
    final lat = pos.latitude ?? 0.0;
    final lon = pos.longitude ?? 0.0;

    // Step 3: Preview before submit
    final confirm = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _CheckPreviewScreen(
          imageFile: File(photo.path),
          latitude: lat,
          longitude: lon,
          type: 'Check-in',
        ),
      ),
    );
    if (confirm != true) return;

    // Step 4: Distance & force flag
    final stationLat = double.tryParse(a.station?.latitude ?? '') ?? 0;
    final stationLng = double.tryParse(a.station?.longitude ?? '') ?? 0;
    final distance = prov.distanceMeters(lat, lon, stationLat, stationLng);
    bool forceMark = false;
    if (distance > 200) {
      forceMark = await _showForceDialog(context, distance);
    }

    // Step 5: Call Provider API (provider will refresh on success)
    final ok = await prov.performCheckIn(
      token: token,
      assignmentId: a.id,
      stationLat: stationLat,
      stationLon: stationLng,
      image: File(photo.path),
      forceIfFar: forceMark,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in successful')),
      );
    } else {
      final err = prov.error ?? 'Check-in failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  Future<void> _handleCheckOut(BuildContext context, int assignmentId) async {
    final prov = context.read<ShiftsProvider>();
    final token = context.read<AuthProvider>().token;
    final a = prov.todaysAssignment;
    final att = prov.todaysAttendance;
    if (token == null || a == null || att == null) return;

    // Step 1: Capture selfie
    final photo = await context
        .read<ImagePickerProvider>()
        .pickCompressedImage(source: ImageSource.camera); // or ImageSource.gallery

    if (photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photo captured')),
      );
      return;
    }

    // Step 2: Get location for preview (provider will read again before submit)
    final location = Location();
    final pos = await location.getLocation();
    final lat = pos.latitude ?? 0.0;
    final lon = pos.longitude ?? 0.0;

    // Step 3: Preview before submit
    final confirm = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _CheckPreviewScreen(
          imageFile: File(photo.path),
          latitude: lat,
          longitude: lon,
          type: 'Check-out',
        ),
      ),
    );
    if (confirm != true) return;

    // Step 4: Distance & force flag
    final stationLat = double.tryParse(a.station?.latitude ?? '') ?? 0;
    final stationLng = double.tryParse(a.station?.longitude ?? '') ?? 0;
    final distance = prov.distanceMeters(lat, lon, stationLat, stationLng);
    bool forceMark = false;
    if (distance > 200) {
      forceMark = await _showForceDialog(context, distance);
    }

    // Step 5: Call Provider API (provider will refresh on success)
    final ok = await prov.performCheckOut(
      token: token,
      attendanceId: att.id,
      assignmentId: a.id,
      stationLat: stationLat,
      stationLon: stationLng,
      image: File(photo.path),
      forceIfFar: forceMark,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-out successful')),
      );
    } else {
      final err = prov.error ?? 'Check-out failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  Future<bool> _showForceDialog(BuildContext ctx, double distance) async {
    return await showDialog<bool>(
      context: ctx,
      builder: (ctx) => AlertDialog(
        title: const Text('Far from Station'),
        content: Text(
          'You are ${(distance / 1000).toStringAsFixed(2)} km away from station. '
              'Do you want to force mark?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Force Mark')),
        ],
      ),
    ) ??
        false;
  }

  @override

  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final hasAssignShiftView = context.select<AuthProvider, bool>((auth) {
      final perms = auth.user?.permissions ?? const <String>[];
      if (perms.contains('all')) return true;
      return perms.contains('assignshift.view');
    });
    print("hasAssignShiftView $hasAssignShiftView");
    final tabCount = hasAssignShiftView ? 3 : 1;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            tabs: [
              if (hasAssignShiftView) const Tab(text: 'My Duty'),
              if (hasAssignShiftView) const Tab(text: 'All Shifts'),
              if (hasAssignShiftView) const Tab(text: 'All Week Off'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ---------- My Duty ----------
            Consumer<ShiftsProvider>(
              builder: (_, prov, __) {
                if (prov.loading && prov.assignments.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (prov.error != null) {
                  return RefreshIndicator(
                    onRefresh: _refreshMy,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(prov.error!, style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refreshMy,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _todayCard(context, prov),
                      const SizedBox(height: 12),
                      _assignedDevicesSection(prov.devices),
                      const SizedBox(height: 12),
                      _attendanceSection(prov.attendance),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),

            // ---------- All Shifts (only if allowed) ----------
            if (hasAssignShiftView)
              Stack(
                children: [
                  Consumer<ShiftAssignProvider>(
                    builder: (_, prov, __) {
                      final token = context.read<AuthProvider>().token;

                      return RefreshIndicator(
                        onRefresh: () async {
                          if (token != null) await prov.fetchAll(token);
                        },
                        child: prov.loading && prov.items.isEmpty
                            ? ListView(
                          children: const [
                            SizedBox(height: 200),
                            Center(child: CircularProgressIndicator()),
                          ],
                        )
                            : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: prov.items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final s = prov.items[i];
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: const Icon(Icons.assignment_turned_in_outlined, size: 36, color: Colors.blue),
                                  title: Text(
                                    '${s.stationName ?? s.station?.name ?? '-'} • Gate ${s.gateName ?? s.gates?.name ?? '-'}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: Colors.grey[800], // softer color for professional look
                                        fontSize: 14,
                                        height: 1.4, // line spacing for readability
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'User: ',
                                          style: TextStyle(fontWeight: FontWeight.bold), // medium weight for label
                                        ),
                                        TextSpan(
                                          text: s.assignedUserName,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        const TextSpan(
                                          text: ' | ',
                                          style: TextStyle(fontWeight: FontWeight.bold), // medium weight for label
                                        ),
                                        const TextSpan(
                                          text: 'Shift: ',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: s.shiftName,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        const TextSpan(text: '\n'),
                                        const TextSpan(
                                          text: 'Date: ',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: _fmtDate(s.assignedDate),
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton(
                                    icon: const Icon(Icons.more_vert),
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        enabled: s.isCompleted != 1,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              onPressed: () async {
                                                if (s.isCompleted == 1) return;
                                                final t = context.read<AuthProvider>().token;
                                                if (t == null) return;

                                                final input = await _openAssignForm(context, initial: s, token: t);
                                                if (input != null) {
                                                  final ok = await prov.update(t, s.id, input);
                                                  _toast(context, ok ? 'Updated' : prov.error ?? 'Update failed');
                                                }

                                                Navigator.pop(context); // Close the menu after action
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () async {
                                                if (s.isCompleted == 1) return;
                                                final t = context.read<AuthProvider>().token;
                                                if (t == null) return;

                                                final okConfirm = await _confirmDelete(context);
                                                if (okConfirm == true) {
                                                  final ok = await prov.remove(t, s.id);
                                                  _toast(context, ok ? 'Deleted' : prov.error ?? 'Delete failed');
                                                }

                                                Navigator.pop(context); // Close the menu after action
                                              },
                                            ),
                                          ],
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
                    },
                  ),

                  // FAB (create)
                  // Positioned(
                  //   right: 16,
                  //   bottom: 80,
                  //   child: FloatingActionButton.extended(
                  //     heroTag: 'Assign Shift',
                  //     onPressed: () async {
                  //       final token = context.read<AuthProvider>().token;
                  //       if (token == null) {
                  //         ScaffoldMessenger.of(context).showSnackBar(
                  //           const SnackBar(content: Text('Session expired. Please login again.')),
                  //         );
                  //         return;
                  //       }
                  //       final input = await _openAssignForm(context, token: token);
                  //       if (input != null) {
                  //         final ok = await context.read<ShiftAssignProvider>().create(token, input);
                  //         final msg = ok
                  //             ? 'Assigned'
                  //             : (context.read<ShiftAssignProvider>().error ?? 'Failed');
                  //         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  //       }
                  //     },
                  //     icon: const Icon(Icons.add),
                  //     label: const Text('Assign'),
                  //   ),
                  // ),
                  // Positioned(
                  //   right: 16,
                  //   bottom: 16,
                  //   child: FloatingActionButton.extended(
                  //     heroTag: 'Bulk Assign Shift',
                  //     onPressed: () async {
                  //       final token = context.read<AuthProvider>().token;
                  //       if (token == null) {
                  //         ScaffoldMessenger.of(context).showSnackBar(
                  //           const SnackBar(content: Text('Session expired. Please login again.')),
                  //         );
                  //         return;
                  //       }
                  //       final input = await _openAssignForm(context, token: token);
                  //       if (input != null) {
                  //         final ok = await context.read<ShiftAssignProvider>().create(token, input);
                  //         final msg = ok
                  //             ? 'Assigned'
                  //             : (context.read<ShiftAssignProvider>().error ?? 'Failed');
                  //         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  //       }
                  //     },
                  //     icon: const Icon(Icons.add),
                  //     label: const Text('Assign Bulk Shift'),
                  //   ),
                  // ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FloatingActionButton.extended(
                          heroTag: 'assign_shift',
                          onPressed: () async {
                            final token = context.read<AuthProvider>().token;
                            if (token == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Session expired. Please login again.')),
                              );
                              return;
                            }
                            final input = await _openAssignForm(context, token: token);
                            if (input != null) {
                              final ok = await context.read<ShiftAssignProvider>().create(token, input);
                              final msg = ok
                                  ? 'Assigned'
                                  : (context.read<ShiftAssignProvider>().error ?? 'Failed');
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          },
                          icon: const Icon(Icons.filter_tilt_shift_sharp),
                          label: const Text('Assign'),
                        ),
                        const SizedBox(height: 12), // spacing between buttons
                        FloatingActionButton.extended(
                          heroTag: 'bulk_assign_shift',
                          onPressed: () async {
                            final token = context.read<AuthProvider>().token;
                            if (token == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Session expired. Please login again.')),
                              );
                              return;
                            }
                            final input = await _openBulkAssignForm(context, token: token);
                            if (input != null) {
                              final ok = await context.read<ShiftAssignProvider>().bulkCreate(token, input);
                              final msg = ok
                                  ? 'Bulk Assigned'
                                  : (context.read<ShiftAssignProvider>().error ?? 'Failed');
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          },
                          icon: const Icon(Icons.filter_tilt_shift_sharp),
                          label: const Text('Bulk Assign'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (hasAssignShiftView)
              Stack(
                children: [
                  Consumer<WeekOffProvider>(
                    builder: (context, provider, _) {
                      final token = context.read<AuthProvider>().token;

                      if (!provider.loading && !provider.initialized && token != null) {
                        provider.fetchWeekOffs(token); // fetch initial data
                      }

                      if (provider.loading && provider.weekOffs.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (provider.error != null) {
                        return Center(
                          child: Text(provider.error!, style: const TextStyle(color: Colors.red)),
                        );
                      }

                      if (provider.weekOffs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.beach_access, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No Week Offs Found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                              SizedBox(height: 8),
                              Text('Tap + to add a new Week Off.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          if (token != null) await provider.fetchWeekOffs(token, forceRefresh: true);
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: provider.weekOffs.length,
                          itemBuilder: (context, index) {
                            final item = provider.weekOffs[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                leading: const Icon(Icons.event_available, size: 36, color: Colors.blue),
                                title: Text(
                                  '${item.userName} ${item.weekday != null ? '- ${item.weekday}' : ' - NA'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Recurring: ${item.isRecurring ? 'Yes' : 'No'}'),
                                    if (item.offDate != null)
                                      Text('Off Date: ${_formatDate(item.offDate!)}'),
                                    if (item.reason != null) Text('Reason: ${item.reason}'),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) async {
                                    final token = context.read<AuthProvider>().token;
                                    if (token == null) return;

                                    if (value == 'edit') {
                                      final updated = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => WeekOffScreen(
                                            weekOff: item,
                                            token: token,
                                          ),
                                        ),
                                      );

                                      if (updated != null && updated is WeekOff) {
                                        await provider.updateWeekOff(token, updated);
                                        await provider.fetchWeekOffs(token);
                                      }
                                    } else if (value == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Confirm Delete'),
                                          content: const Text('Are you sure you want to delete this Week Off?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        await provider.deleteWeekOff(token, item.id);
                                        await provider.fetchWeekOffs(token);
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          GestureDetector(
                                            onTap: () => Navigator.pop(_, 'edit'),
                                            child: const Icon(Icons.edit, color: Colors.blue),
                                          ),
                                          GestureDetector(
                                            onTap: () => Navigator.pop(_, 'delete'),
                                            child: const Icon(Icons.delete, color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.extended(
                      heroTag: 'weekoff_tab',
                      onPressed: () async {
                        final token = context.read<AuthProvider>().token;
                        if (token == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Session expired. Please login again.')),
                          );
                          return;
                        }

                        final newWeekOff = await showModalBottomSheet<WeekOff>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (_) => Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: WeekOffScreen(token: token),
                          ),
                        );

                        if (newWeekOff != null) {
                          final ok = await context.read<WeekOffProvider>().createWeekOff(
                            token,
                            newWeekOff,
                          );
                          final msg = ok
                              ? 'Week off assigned successfully'
                              : (context.read<WeekOffProvider>().error ?? 'Failed');
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

                          await context.read<WeekOffProvider>().fetchWeekOffs(token); // ✅ Refresh after create
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Week Off'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return "${date.day.toString().padLeft(2,'0')}-${date.month.toString().padLeft(2,'0')}-${date.year}";
  }

  void _toast(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool?> _confirmDelete(BuildContext ctx) {
    return showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete assignment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
  }
  // === Widgets ===

  Widget _todayCard(BuildContext context, ShiftsProvider prov) {
    final color = Theme.of(context).colorScheme;
    final a = prov.todaysAssignment;
    final att = prov.todaysAttendance;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: a == null
            ? const Center(child: Text('No Shift Assigned Today', style: TextStyle(fontSize: 16)))
            : Builder(
          builder: (_) {
            // ---- Guarded/derived flags ----
            final assignmentId = a.id;
            final bool isCompleted = (a.isCompleted == true) || (a.isCompleted == 1) || (a.isCompleted?.toString() == '1');

            // Use attendance only if it matches THIS assignment
            final matchedAtt = (att != null && att.userShiftAssignmentId == assignmentId) ? att : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Shift",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.primaryContainer,
                      child: const Icon(Icons.work_outline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${a.station?.name ?? '-'} • Gate ${a.gates?.name ?? '-'}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 6),
                    Text('${a.shift?.name ?? ''}  ${a.shift?.startTime ?? ''} - ${a.shift?.endTime ?? ''}'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 6),
                    Text(_fmtDate(a.assignedDate)),
                  ],
                ),

                // ---- Only show status + action buttons when NOT completed ----
                if (!isCompleted) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Status chip uses only the matched attendance
                      _statusChip(matchedAtt),
                      const Spacer(),
                      // Pass prov; if your _checkButtons can accept the assignmentId, even better:
                      _checkButtons(context, prov, assignmentId)
                      // _checkButtons(context, prov),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Shift completed chip; no buttons
                      _completedChip(),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _completedChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDCF7E3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
          SizedBox(width: 6),
          Text('Shift Completed',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
        ],
      ),
    );
  }

  Widget _statusChip(AttendanceRecord? att) {
    // Robust "has checked out" check
    bool _hasCheckedOut(AttendanceRecord? r) {
      if (r == null) return false;
      final v = r.checkOutTime;
      if (v == null) return false;
      return v.trim().isNotEmpty;
    }

    String label;
    Color color;

    if (att == null) {
      label = 'Not checked-in';
      color = Colors.orange;
    } else if (!_hasCheckedOut(att)) {
      label = 'Checked-in';
      color = Colors.green;
    } else {
      label = 'Completed';
      color = Colors.blueGrey;
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      avatar: CircleAvatar(backgroundColor: color, radius: 8),
    );
  }

  Widget _checkButtons(BuildContext context, ShiftsProvider prov, int assignmentId) {
    final assignment = prov.todaysAssignment;
    if (assignment == null) return const SizedBox.shrink();

    final bool isCompleted = (assignment.isCompleted == true) ||
        (assignment.isCompleted == 1) ||
        (assignment?.isCompleted.toString() == '1');
    if (isCompleted) return const SizedBox.shrink();

    // ✅ Use your provider method here
    final att = prov.todayAttendanceForAssignment(assignmentId);

    // If String? for checkout; if DateTime?, change to `final hasCheckedOut = att?.checkOutTime != null;`
    final bool hasCheckedOut = att != null &&
        att.checkOutTime != null &&
        (att.checkOutTime is String ? (att.checkOutTime as String).isNotEmpty : true);

    // Keep your global gates if you use them for time windows/policy
    final baseCanIn  = prov.canCheckIn(assignmentId);
    final baseCanOut = prov.canCheckOut(assignmentId);
    final showCheckIn  = (att == null) && baseCanIn;
    final showCheckOut = (att != null) && !hasCheckedOut && baseCanOut;
    if (!showCheckIn && !showCheckOut) return const SizedBox.shrink();

    final busyIn  = prov.checkingIn;
    final busyOut = prov.checkingOut;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (showCheckIn)
          ElevatedButton.icon(
            onPressed: busyIn ? null : () async {
              if (prov.checkingIn) return;
              await _handleCheckIn(context, assignmentId);
            },
            icon: busyIn
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.login),
            label: Text(busyIn ? 'Checking in…' : 'Check-in'),
          ),

        if (showCheckOut)
          OutlinedButton.icon(
            onPressed: busyOut ? null : () async {
              if (prov.checkingOut) return;
              await _handleCheckOut(context, assignmentId);
            },
            icon: busyOut
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout),
            label: Text(busyOut ? 'Checking out…' : 'Check-out'),
          ),

        if (baseCanOut && att == null)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'Checkout locked: no attendance for this shift',
              style: TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ),
      ],
    );
  }

  Widget _assignedDevicesSection(List<AssignedDevice> devices) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: devices.isEmpty
            ? const Center(
          child: Text('No Device Assigned', style: TextStyle(fontSize: 16)),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assigned Devices', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...devices.map(
                  (d) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.devices_other),
                title: Text(d.deviceSerial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: Text('${d.deviceModel}', style: const TextStyle(fontSize: 10)),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Gate ${d.gate} • ${d.gateType}'),
                    Text(d.station, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceSection(List<AttendanceRecord> items) {
    final sorted = [...items]..sort((a, b) => b.date.compareTo(a.date));
    final last10 = sorted.take(10).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: last10.isEmpty
            ? const Center(
                child: Text('No Attendance History', style: TextStyle(fontSize: 16))
            )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance (Last 10 days)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...last10.map(
                  (a) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month),
                title: Text(_fmtDate(a.date)),
                subtitle: Text('In: ${a.checkInTime ?? '-'}  |  Out: ${a.checkOutTime ?? '-'}'),
                trailing: _badge(a.status),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String status) {
    Color c = Colors.blueGrey;
    final s = status.toLowerCase();
    if (s.contains('present')) c = Colors.green;
    if (s.contains('absent')) c = Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
    );
  }

  Future<AssignShiftInput?> _openAssignForm(
      BuildContext context, {
        required String token,
        AssignShift? initial,
      }) {
    return showModalBottomSheet<AssignShiftInput>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AssignFormSheet(token: token, initial: initial),
    );
  }

  Future<AssignBulkShiftInput?> _openBulkAssignForm(
      BuildContext context, {
        required String token,
        AssignShift? initial,
      }) {
    return showModalBottomSheet<AssignBulkShiftInput>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AssignBulkFormSheet(token: token, initial: initial),
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

// ========== PREVIEW SCREEN ==========
class _CheckPreviewScreen extends StatelessWidget {
  final File imageFile;
  final double latitude;
  final double longitude;
  final String type;

  const _CheckPreviewScreen({
    required this.imageFile,
    required this.latitude,
    required this.longitude,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$type Preview')),
      body: Column(
        children: [
          Expanded(child: Image.file(imageFile, fit: BoxFit.cover, width: double.infinity)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _AssignFormSheet extends StatefulWidget {
  final String token;
  final AssignShift? initial;
  const _AssignFormSheet({required this.token, this.initial});

  @override
  State<_AssignFormSheet> createState() => _AssignFormSheetState();
}

class _AssignFormSheetState extends State<_AssignFormSheet> {
  static const brand = Color(0xFFA7D222);

  final _formKey = GlobalKey<FormState>();
  final _dateCtrl = TextEditingController();

  bool _loading = true;
  String? _error;

  int? _shiftId;
  int? _stationId;
  int? _gateId;
  DateTime? _date;
  int? _userId;

  @override
  void initState() {
    super.initState();
    // seed initial values (edit case)
    final i = widget.initial;
    _userId = widget.initial?.userId;
    if (i != null) {
      _shiftId = i.shiftId;
      _stationId = i.stationId;
      _gateId = i.gateId;
      _date = i.assignedDate;
      _dateCtrl.text = _fmtDate(i.assignedDate);
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final meta = context.read<LookupProvider>();
    final usersProv = context.read<UsersProvider>();
    try {
      await meta.ensureBasics(widget.token);
      if (_stationId != null) {
        await meta.fetchGatesForStation(widget.token, _stationId!);
      }

      if (usersProv.items.isEmpty) {
        await usersProv.load(widget.token);
      }
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = context.watch<LookupProvider>();
    final usersProv = context.watch<UsersProvider>();

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(height: 4, width: 60),
            Center(child: CircularProgressIndicator()),
            SizedBox(height: 16),
            Text('Loading…'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () { Navigator.pop(context); },
              child: const Text('Close'),
            )
          ],
        ),
      );
    }

    final gates = (_stationId == null)
        ? const <GateLite>[]
        : (meta.gatesByStation[_stationId!] ?? const <GateLite>[]);
    final gatesLoading = (_stationId != null) && meta.isLoadingGates(_stationId!);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16, right: 16, top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, width: 60,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Text(widget.initial == null ? 'Assign Shift' : 'Update Assignment',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            // Date
            TextFormField(
              controller: _dateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Assigned Date',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.date_range, color: brand),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (picked != null) {
                      setState(() { _date = picked; _dateCtrl.text = _fmtDate(picked); });
                    }
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Pick date' : null,
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<int>(
              value: _userId, // safe
              isExpanded: true,
              items: usersProv.items.map((u) {
                final title = (u.name.isNotEmpty == true) ? u.name : (u.email ?? 'User ${u.id}');
                return DropdownMenuItem<int>(value: u.id, child: Text(title));
              }).toList(),
              onChanged: (v) => setState(() => _userId = v),
              decoration: const InputDecoration(
                labelText: 'User',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null ? 'Select a user' : null,
            ),

            const SizedBox(height: 10),

            // Shift
            DropdownButtonFormField<int>(
              value: _shiftId,
              items: meta.shifts.map((s) => DropdownMenuItem(
                value: s.id,
                child: Text('${s.name} (${s.startTime ?? '--'} - ${s.endTime ?? '--'})'),
              )).toList(),
              onChanged: (v) => setState(() => _shiftId = v),
              decoration: const InputDecoration(labelText: 'Shift', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Select a shift' : null,
            ),
            const SizedBox(height: 10),

            // Station
            DropdownButtonFormField<int>(
              value: _stationId,
              items: meta.stations.map((st) => DropdownMenuItem(
                value: st.id, child: Text(st.name),
              )).toList(),
              onChanged: (v) async {
                setState(() { _stationId = v; _gateId = null; });
                if (v != null) {
                  await context.read<LookupProvider>().fetchGatesForStation(widget.token, v);
                }
              },
              decoration: const InputDecoration(labelText: 'Station', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Select a station' : null,
            ),
            const SizedBox(height: 10),

            // Gate
            gatesLoading
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
                : DropdownButtonFormField<int>(
              value: _gateId,
              items: gates.map((g) => DropdownMenuItem(
                value: g.id, child: Text('${g.name} (${g.type ?? '-'})'),
              )).toList(),
              onChanged: (v) => setState(() => _gateId = v),
              decoration: const InputDecoration(labelText: 'Gate', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Select a gate' : null,
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.save),
                label: Text(widget.initial == null ? 'Assign' : 'Update'),
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  final d = _date;
                  if (d == null || _userId == null || _shiftId == null || _stationId == null || _gateId == null) return;
                  final input = AssignShiftInput(
                    assignedDate: d,
                    userId: _userId!,
                    shiftId: _shiftId!,
                    stationId: _stationId!,
                    gateId: _gateId!,
                  );
                  Navigator.pop(context, input);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

    String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _AssignBulkFormSheet extends StatefulWidget {
  final String token;
  final AssignShift? initial;
  const _AssignBulkFormSheet({required this.token, this.initial});

  @override
  State<_AssignBulkFormSheet> createState() => _AssignBulkFormSheetState();
}

class _AssignBulkFormSheetState extends State<_AssignBulkFormSheet> {
  static const brand = Color(0xFFA7D222);

  final _formKey = GlobalKey<FormState>();
  final _dateFromCtrl = TextEditingController();
  final _dateToCtrl = TextEditingController();

  bool _loading = true;
  String? _error;

  int? _shiftId;
  int? _stationId;
  int? _gateId;
  DateTime? _fromDate;
  DateTime? _toDate;
  int? _userId;

  @override
  void initState() {
    super.initState();
    // seed initial values (edit case)
    final i = widget.initial;
    _userId = widget.initial?.userId;
    if (i != null) {
      _shiftId = i.shiftId;
      _stationId = i.stationId;
      _gateId = i.gateId;
      _fromDate = i.assignedFromDate;
      _toDate = i.assignedToDate;
      _dateFromCtrl.text = _fmtDate(i.assignedFromDate);
      _dateToCtrl.text = _fmtDate(i.assignedToDate);
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final meta = context.read<LookupProvider>();
    final usersProv = context.read<UsersProvider>();
    try {
      await meta.ensureBasics(widget.token);
      if (_stationId != null) {
        await meta.fetchGatesForStation(widget.token, _stationId!);
      }

      if (usersProv.items.isEmpty) {
        await usersProv.load(widget.token);
      }
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _dateFromCtrl.dispose();
    _dateToCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = context.watch<LookupProvider>();
    final usersProv = context.watch<UsersProvider>();

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(height: 4, width: 60),
            Center(child: CircularProgressIndicator()),
            SizedBox(height: 16),
            Text('Loading…'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () { Navigator.pop(context); },
              child: const Text('Close'),
            )
          ],
        ),
      );
    }

    final gates = (_stationId == null)
        ? const <GateLite>[]
        : (meta.gatesByStation[_stationId!] ?? const <GateLite>[]);
    final gatesLoading = (_stationId != null) && meta.isLoadingGates(_stationId!);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16, right: 16, top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, width: 60,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Text(widget.initial == null ? 'Assign Bulk Shift' : 'Update Assignment',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            // Date
            TextFormField(
              controller: _dateFromCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Assigned From Date',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.date_range, color: brand),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fromDate ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (picked != null) {
                      setState(() { _fromDate = picked; _dateFromCtrl.text = _fmtDate(picked); });
                    }
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Pick date' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _dateToCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Assigned To Date',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.date_range, color: brand),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _toDate ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (picked != null) {
                      setState(() { _toDate = picked; _dateToCtrl.text = _fmtDate(picked); });
                    }
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Pick date' : null,
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<int>(
              value: _userId, // safe
              isExpanded: true,
              items: usersProv.items.map((u) {
                final title = (u.name.isNotEmpty == true) ? u.name : (u.email ?? 'User ${u.id}');
                return DropdownMenuItem<int>(value: u.id, child: Text(title));
              }).toList(),
              onChanged: (v) => setState(() => _userId = v),
              decoration: const InputDecoration(
                labelText: 'User',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null ? 'Select a user' : null,
            ),

            const SizedBox(height: 10),

            // Shift
            DropdownButtonFormField<int>(
              value: _shiftId,
              items: meta.shifts.map((s) => DropdownMenuItem(
                value: s.id,
                child: Text('${s.name} (${s.startTime ?? '--'} - ${s.endTime ?? '--'})'),
              )).toList(),
              onChanged: (v) => setState(() => _shiftId = v),
              decoration: const InputDecoration(labelText: 'Shift', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Select a shift' : null,
            ),
            const SizedBox(height: 10),

            // Station
            DropdownButtonFormField<int>(
              value: _stationId,
              items: meta.stations.map((st) => DropdownMenuItem(
                value: st.id, child: Text(st.name),
              )).toList(),
              onChanged: (v) async {
                setState(() { _stationId = v; _gateId = null; });
                if (v != null) {
                  await context.read<LookupProvider>().fetchGatesForStation(widget.token, v);
                }
              },
              decoration: const InputDecoration(labelText: 'Station', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Select a station' : null,
            ),
            const SizedBox(height: 10),

            // Gate
            gatesLoading
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
                : DropdownButtonFormField<int>(
              value: _gateId,
              items: gates.map((g) => DropdownMenuItem(
                value: g.id, child: Text('${g.name} (${g.type ?? '-'})'),
              )).toList(),
              onChanged: (v) => setState(() => _gateId = v),
              decoration: const InputDecoration(labelText: 'Gate', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Select a gate' : null,
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.save),
                label: Text(widget.initial == null ? 'Assign' : 'Update'),
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  final fromDate = _fromDate;
                  final toDate = _toDate;
                  if (fromDate == null || toDate == null || _userId == null || _shiftId == null || _stationId == null || _gateId == null) return;
                  final input = AssignBulkShiftInput(
                    assignedFromDate: fromDate,
                    assignedToDate: toDate,
                    userId: _userId!,
                    shiftId: _shiftId!,
                    stationId: _stationId!,
                    gateId: _gateId!,
                  );
                  Navigator.pop(context, input);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class WeekOffScreen extends StatefulWidget {
  final WeekOff? weekOff;
  final String token;

  const WeekOffScreen({Key? key, this.weekOff, required this.token})
      : super(key: key);

  @override
  State<WeekOffScreen> createState() => _WeekOffScreenState();
}

class _WeekOffScreenState extends State<WeekOffScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _offDate;
  bool _isRecurring = false;
  String? _weekday;
  String? _reason;
  int? _userId;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userId = widget.weekOff?.userId;
    _offDate = widget.weekOff?.offDate;
    _isRecurring = widget.weekOff?.isRecurring ?? false;
    _weekday = widget.weekOff?.weekday?.isNotEmpty == true
        ? widget.weekOff!.weekday
        : null;
    _reason = widget.weekOff?.reason;

    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final usersProv = context.read<UsersProvider>();
      if (usersProv.items.isEmpty) {
        await usersProv.load(widget.token);
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersProv = context.watch<UsersProvider>();

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        ),
      );
    }

    return Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 60,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.weekOff == null ? 'Add Week Off' : 'Edit Week Off',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                // User Dropdown
                DropdownButtonFormField<int>(
                  value: _userId,
                  items: usersProv.items.map((u) {
                    final title = u.name.isNotEmpty
                        ? u.name
                        : (u.email ?? 'User ${u.id}');
                    return DropdownMenuItem<int>(
                      value: u.id,
                      child: Text(title),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _userId = v),
                  decoration: const InputDecoration(
                    labelText: 'User',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null ? 'Select a user' : null,
                ),
                const SizedBox(height: 12),

                // Date Picker (only show if not recurring)
                if (!_isRecurring)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.date_range),
                    title: Text(
                      _offDate != null
                          ? "${_offDate!.day.toString().padLeft(2, '0')}-${_offDate!.month.toString().padLeft(2, '0')}-${_offDate!.year}"
                          : "Pick Off Date",
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _offDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _offDate = picked);
                    },
                  ),
                const SizedBox(height: 12),

                // Recurring Switch
                SwitchListTile(
                  title: const Text("Recurring weekly"),
                  value: _isRecurring,
                  onChanged: (val) {
                    setState(() {
                      _isRecurring = val;
                      if (val) _offDate = null; // clear date if recurring
                    });
                  },
                ),

                // Weekday dropdown (only show if recurring)
                if (_isRecurring)
                  DropdownButtonFormField<String>(
                    value: _weekday,
                    items: const [
                      DropdownMenuItem(value: "Monday", child: Text("Monday")),
                      DropdownMenuItem(value: "Tuesday", child: Text("Tuesday")),
                      DropdownMenuItem(
                          value: "Wednesday", child: Text("Wednesday")),
                      DropdownMenuItem(
                          value: "Thursday", child: Text("Thursday")),
                      DropdownMenuItem(value: "Friday", child: Text("Friday")),
                      DropdownMenuItem(value: "Saturday", child: Text("Saturday")),
                      DropdownMenuItem(value: "Sunday", child: Text("Sunday")),
                    ],
                    onChanged: (v) => setState(() => _weekday = v ?? ''),
                    decoration: const InputDecoration(
                      labelText: "Select Weekday",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    _isRecurring && (v == null || v.isEmpty)
                        ? 'Select a weekday'
                        : null,
                  ),
                const SizedBox(height: 12),

                // Reason
                TextFormField(
                  initialValue: _reason,
                  decoration: const InputDecoration(
                    labelText: "Reason",
                    prefixIcon: Icon(Icons.note),
                    border: OutlineInputBorder(),
                  ),
                  onSaved: (val) => _reason = val,
                ),
                const SizedBox(height: 16),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("Save"),
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;

                      if (!_isRecurring && _offDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Pick an off date")),
                        );
                        return;
                      }

                      _formKey.currentState?.save();

                      final weekOff = WeekOff(
                        id: widget.weekOff?.id ?? 0,
                        userId: _userId!,
                        assignBy: widget.weekOff?.assignBy ?? 0,
                        organizationId:
                        widget.weekOff?.organizationId ?? 0,
                        offDate: _isRecurring ? null : _offDate, // nullable if recurring
                        weekday: _isRecurring ? (_weekday ?? '') : '',
                        isRecurring: _isRecurring,
                        reason: _reason,
                        createdAt: widget.weekOff?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                        userName: widget.weekOff?.userName ?? '',
                      );

                      Navigator.pop(context, weekOff);
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
    // return Material(
    //   borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    //   clipBehavior: Clip.antiAlias,
    //   child: Padding(
    //     padding: EdgeInsets.only(
    //       bottom: MediaQuery.of(context).viewInsets.bottom,
    //       left: 16,
    //       right: 16,
    //       top: 16,
    //     ),
    //     child: SingleChildScrollView(
    //       child: Form(
    //         key: _formKey,
    //         child: Column(
    //           mainAxisSize: MainAxisSize.min,
    //           children: [
    //             Container(
    //               height: 4,
    //               width: 60,
    //               decoration: BoxDecoration(
    //                   color: Colors.grey[300],
    //                   borderRadius: BorderRadius.circular(2)),
    //             ),
    //             const SizedBox(height: 12),
    //             Text(
    //               widget.weekOff == null ? 'Add Week Off' : 'Edit Week Off',
    //               style: const TextStyle(
    //                   fontWeight: FontWeight.bold, fontSize: 16),
    //             ),
    //             const SizedBox(height: 12),
    //
    //             // User Dropdown
    //             DropdownButtonFormField<int>(
    //               value: _userId,
    //               items: usersProv.items.map((u) {
    //                 final title = u.name.isNotEmpty
    //                     ? u.name
    //                     : (u.email ?? 'User ${u.id}');
    //                 return DropdownMenuItem<int>(
    //                   value: u.id,
    //                   child: Text(title),
    //                 );
    //               }).toList(),
    //               onChanged: (v) => setState(() => _userId = v),
    //               decoration: const InputDecoration(
    //                 labelText: 'User',
    //                 border: OutlineInputBorder(),
    //               ),
    //               validator: (v) => v == null ? 'Select a user' : null,
    //             ),
    //             const SizedBox(height: 12),
    //
    //             // Date Picker
    //             ListTile(
    //               contentPadding: EdgeInsets.zero,
    //               leading: const Icon(Icons.date_range),
    //               title: Text(
    //                 _offDate != null
    //                     ? "${_offDate!.day.toString().padLeft(2, '0')}-${_offDate!.month.toString().padLeft(2, '0')}-${_offDate!.year}"
    //                     : "Pick Off Date",
    //               ),
    //               onTap: () async {
    //                 final picked = await showDatePicker(
    //                   context: context,
    //                   initialDate: _offDate ?? DateTime.now(),
    //                   firstDate: DateTime(2020),
    //                   lastDate: DateTime(2100),
    //                 );
    //                 if (picked != null) {
    //                   setState(() => _offDate = picked);
    //                 }
    //               },
    //             ),
    //             const SizedBox(height: 12),
    //
    //             // Recurring
    //             SwitchListTile(
    //               title: const Text("Recurring weekly"),
    //               value: _isRecurring,
    //               onChanged: (val) => setState(() => _isRecurring = val),
    //             ),
    //
    //             // Weekday dropdown
    //             if (_isRecurring)
    //               DropdownButtonFormField<String>(
    //                 value: _weekday,
    //                 items: const [
    //                   DropdownMenuItem(value: "Monday", child: Text("Monday")),
    //                   DropdownMenuItem(value: "Tuesday", child: Text("Tuesday")),
    //                   DropdownMenuItem(
    //                       value: "Wednesday", child: Text("Wednesday")),
    //                   DropdownMenuItem(
    //                       value: "Thursday", child: Text("Thursday")),
    //                   DropdownMenuItem(value: "Friday", child: Text("Friday")),
    //                   DropdownMenuItem(value: "Saturday", child: Text("Saturday")),
    //                   DropdownMenuItem(value: "Sunday", child: Text("Sunday")),
    //                 ],
    //                 onChanged: (v) => setState(() => _weekday = v ?? ''),
    //                 decoration: const InputDecoration(
    //                   labelText: "Select Weekday",
    //                   border: OutlineInputBorder(),
    //                 ),
    //                 validator: (v) =>
    //                 v == null || v.isEmpty ? 'Select a weekday' : null,
    //               ),
    //             const SizedBox(height: 12),
    //
    //             // Reason
    //             TextFormField(
    //               initialValue: _reason,
    //               decoration: const InputDecoration(
    //                 labelText: "Reason",
    //                 prefixIcon: Icon(Icons.note),
    //                 border: OutlineInputBorder(),
    //               ),
    //               onSaved: (val) => _reason = val,
    //             ),
    //             const SizedBox(height: 16),
    //
    //             SizedBox(
    //               width: double.infinity,
    //               child: ElevatedButton.icon(
    //                 icon: const Icon(Icons.save),
    //                 label: const Text("Save"),
    //                 onPressed: () {
    //                   if (!_formKey.currentState!.validate()) return;
    //                   if (_offDate == null) {
    //                     ScaffoldMessenger.of(context).showSnackBar(
    //                       const SnackBar(content: Text("Pick a date")),
    //                     );
    //                     return;
    //                   }
    //                   _formKey.currentState?.save();
    //
    //                   final weekOff = WeekOff(
    //                     id: widget.weekOff?.id ?? 0,
    //                     userId: _userId!,
    //                     assignBy: widget.weekOff?.assignBy ?? 0,
    //                     organizationId:
    //                     widget.weekOff?.organizationId ?? 0,
    //                     offDate: _offDate!,
    //                     weekday: _isRecurring ? (_weekday ?? '') : '',
    //                     isRecurring: _isRecurring,
    //                     reason: _reason,
    //                     createdAt: widget.weekOff?.createdAt ?? DateTime.now(),
    //                     updatedAt: DateTime.now(),
    //                     userName: widget.weekOff?.userName ?? '',
    //                   );
    //
    //                   Navigator.pop(context, weekOff);
    //                 },
    //               ),
    //             ),
    //             const SizedBox(height: 12),
    //           ],
    //         ),
    //       ),
    //     ),
    //   ),
    // );
  }
}