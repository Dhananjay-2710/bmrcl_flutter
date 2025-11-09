import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import '../../../providers/imagepicker_provider.dart';
import '../../../core/services/location_permission_service.dart';
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
import 'shift_assignment_detail_screen.dart';
import '../../../shared/utils/app_snackbar.dart';

enum _ShiftSnackTone { info, success, error }

class ShiftsTab extends StatefulWidget {
  const ShiftsTab({super.key});

  @override
  State<ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<ShiftsTab>
    with SingleTickerProviderStateMixin {
  TabController? _tabCtrl;
  bool get _hasAssignShiftView {
    final perms =
        context.read<AuthProvider>().user?.permissions ?? const <String>[];
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
      _tabCtrl =
          TabController(length: len, vsync: this, initialIndex: initialIndex);
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
    if (token != null)
      await context.read<ShiftsProvider>().fetchMyShifts(token);
  }

  void _showSnack(BuildContext context, String message,
      {_ShiftSnackTone tone = _ShiftSnackTone.info}) {
    switch (tone) {
      case _ShiftSnackTone.success:
        AppSnackBar.success(context, message);
        break;
      case _ShiftSnackTone.error:
        AppSnackBar.error(context, message);
        break;
      case _ShiftSnackTone.info:
      default:
        AppSnackBar.info(context, message);
    }
  }

  // ======== CHECK-IN / OUT LOGIC ========

  Future<void> _handleCheckIn(BuildContext context, int assignmentId) async {
    final prov = context.read<ShiftsProvider>();
    final token = context.read<AuthProvider>().token;
    final a = prov.todaysAssignment;
    if (token == null || a == null) return;

    final permissionReady =
        await LocationPermissionService.instance.ensureReady(context);
    if (!permissionReady) {
      _showSnack(context, 'Location permission is required to check-in',
          tone: _ShiftSnackTone.error);
      return;
    }

    final photo = await context
        .read<ImagePickerProvider>()
        .pickCompressedImage(source: ImageSource.camera);

    if (photo == null) {
      _showSnack(context, 'No photo captured', tone: _ShiftSnackTone.info);
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
      _showSnack(context, 'Check-in successful', tone: _ShiftSnackTone.success);
    } else {
      final err = prov.error ?? 'Check-in failed';
      _showSnack(context, err, tone: _ShiftSnackTone.error);
    }
  }

  Future<void> _handleCheckOut(BuildContext context, int assignmentId) async {
    final prov = context.read<ShiftsProvider>();
    final token = context.read<AuthProvider>().token;
    final a = prov.todaysAssignment;
    final att = prov.todaysAttendance;
    if (token == null || a == null || att == null) return;

    final permissionReady =
        await LocationPermissionService.instance.ensureReady(context);
    if (!permissionReady) {
      _showSnack(context, 'Location permission is required to check-out',
          tone: _ShiftSnackTone.error);
      return;
    }

    // Step 1: Capture selfie
    final photo = await context.read<ImagePickerProvider>().pickCompressedImage(
        source: ImageSource.camera); // or ImageSource.gallery

    if (photo == null) {
      _showSnack(context, 'No photo captured', tone: _ShiftSnackTone.info);
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
      _showSnack(context, 'Check-out successful',
          tone: _ShiftSnackTone.success);
    } else {
      final err = prov.error ?? 'Check-out failed';
      _showSnack(context, err, tone: _ShiftSnackTone.error);
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
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Force Mark',
                    style: TextStyle(color: Colors.white)),
              ),
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
                        Text(prov.error!,
                            style: const TextStyle(color: Colors.red)),
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
                                padding: const EdgeInsets.all(12),
                                itemCount: prov.items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final s = prov.items[i];
                                  return _ShiftCardWidget(
                                    shift: s,
                                    onEdit: () async {
                                      if (s.isCompleted == 1) return;
                                      final t =
                                          context.read<AuthProvider>().token;
                                      if (t == null) return;

                                      final input = await _openAssignForm(
                                          context,
                                          initial: s,
                                          token: t);
                                      if (input != null) {
                                        final ok =
                                            await prov.update(t, s.id, input);
                                        _showSnack(
                                          context,
                                          ok
                                              ? 'Updated'
                                              : prov.error ?? 'Update failed',
                                          tone: ok
                                              ? _ShiftSnackTone.success
                                              : _ShiftSnackTone.error,
                                        );
                                      }
                                    },
                                    onDelete: () async {
                                      if (s.isCompleted == 1) return;
                                      final t =
                                          context.read<AuthProvider>().token;
                                      if (t == null) return;

                                      final okConfirm =
                                          await _confirmDelete(context);
                                      if (okConfirm == true) {
                                        final ok = await prov.remove(t, s.id);
                                        _showSnack(
                                          context,
                                          ok
                                              ? 'Deleted'
                                              : prov.error ?? 'Delete failed',
                                          tone: ok
                                              ? _ShiftSnackTone.success
                                              : _ShiftSnackTone.error,
                                        );
                                      }
                                    },
                                    formatDate: _fmtDate,
                                    onTap: () =>
                                        _openShiftDetailScreen(context, s.id),
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
                          backgroundColor: const Color(0xFFA7D222),
                          foregroundColor: Colors.white,
                          onPressed: () async {
                            final token = context.read<AuthProvider>().token;
                            if (token == null) {
                              _showSnack(context,
                                  'Session expired. Please login again.',
                                  tone: _ShiftSnackTone.error);
                              return;
                            }
                            final input =
                                await _openAssignForm(context, token: token);
                            if (input != null) {
                              final ok = await context
                                  .read<ShiftAssignProvider>()
                                  .create(token, input);
                              final msg = ok
                                  ? 'Assigned'
                                  : (context
                                          .read<ShiftAssignProvider>()
                                          .error ??
                                      'Failed');
                              _showSnack(
                                context,
                                msg,
                                tone: ok
                                    ? _ShiftSnackTone.success
                                    : _ShiftSnackTone.error,
                              );
                            }
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Assign'),
                        ),
                        const SizedBox(height: 12), // spacing between buttons
                        FloatingActionButton.extended(
                          heroTag: 'bulk_assign_shift',
                          backgroundColor: const Color(0xFFA7D222),
                          foregroundColor: Colors.white,
                          onPressed: () async {
                            final token = context.read<AuthProvider>().token;
                            if (token == null) {
                              _showSnack(context,
                                  'Session expired. Please login again.',
                                  tone: _ShiftSnackTone.error);
                              return;
                            }
                            final input = await _openBulkAssignForm(context,
                                token: token);
                            if (input != null) {
                              final ok = await context
                                  .read<ShiftAssignProvider>()
                                  .bulkCreate(token, input);
                              final msg = ok
                                  ? 'Bulk Assigned'
                                  : (context
                                          .read<ShiftAssignProvider>()
                                          .error ??
                                      'Failed');
                              _showSnack(
                                context,
                                msg,
                                tone: ok
                                    ? _ShiftSnackTone.success
                                    : _ShiftSnackTone.error,
                              );
                            }
                          },
                          icon: const Icon(Icons.add_box, color: Colors.white),
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

                      if (!provider.loading &&
                          !provider.initialized &&
                          token != null) {
                        provider.fetchWeekOffs(token); // fetch initial data
                      }

                      if (provider.loading && provider.weekOffs.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (provider.error != null) {
                        return Center(
                          child: Text(provider.error!,
                              style: const TextStyle(color: Colors.red)),
                        );
                      }

                      if (provider.weekOffs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.beach_access,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No Week Offs Found',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.grey)),
                              SizedBox(height: 8),
                              Text('Tap + to add a new Week Off.',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          if (token != null)
                            await provider.fetchWeekOffs(token,
                                forceRefresh: true);
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          itemCount: provider.weekOffs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = provider.weekOffs[index];
                            return _WeekOffCardWidget(
                              weekOff: item,
                              onEdit: () async {
                                final token =
                                    context.read<AuthProvider>().token;
                                if (token == null) return;

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
                              },
                              onDelete: () async {
                                final token =
                                    context.read<AuthProvider>().token;
                                if (token == null) return;

                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Confirm Delete'),
                                    content: const Text(
                                        'Are you sure you want to delete this Week Off?'),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
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
                                  await provider.deleteWeekOff(token, item.id);
                                  await provider.fetchWeekOffs(token);
                                }
                              },
                              formatDate: _formatDate,
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
                      backgroundColor: const Color(0xFFA7D222),
                      foregroundColor: Colors.white,
                      onPressed: () async {
                        final token = context.read<AuthProvider>().token;
                        if (token == null) {
                          _showSnack(
                              context, 'Session expired. Please login again.',
                              tone: _ShiftSnackTone.error);
                          return;
                        }

                        final newWeekOff = await Navigator.push<WeekOff>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WeekOffScreen(token: token),
                          ),
                        );

                        if (newWeekOff != null) {
                          final ok = await context
                              .read<WeekOffProvider>()
                              .createWeekOff(
                                token,
                                newWeekOff,
                              );
                          final msg = ok
                              ? 'Week off assigned successfully'
                              : (context.read<WeekOffProvider>().error ??
                                  'Failed');
                          _showSnack(
                            context,
                            msg,
                            tone: ok
                                ? _ShiftSnackTone.success
                                : _ShiftSnackTone.error,
                          );

                          await context
                              .read<WeekOffProvider>()
                              .fetchWeekOffs(token); // ✅ Refresh after create
                        }
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
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
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  void _toast(BuildContext ctx, String msg,
      {_ShiftSnackTone tone = _ShiftSnackTone.info}) {
    _showSnack(ctx, msg, tone: tone);
  }

  Future<bool?> _confirmDelete(BuildContext ctx) {
    return showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete assignment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
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
            ? const Center(
                child: Text('No Shift Assigned Today',
                    style: TextStyle(fontSize: 16)))
            : Builder(
                builder: (_) {
                  // ---- Guarded/derived flags ----
                  final assignmentId = a.id;
                  final bool isCompleted = (a.isCompleted == true) ||
                      (a.isCompleted == 1) ||
                      (a.isCompleted?.toString() == '1');

                  // Use attendance only if it matches THIS assignment
                  final matchedAtt =
                      (att != null && att.userShiftAssignmentId == assignmentId)
                          ? att
                          : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Today's Shift",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
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
                              '${a.station?.name ?? '-'} • Access Point ${a.gates?.name ?? '-'}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Shift: ${a.shift?.name ?? '-'}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.schedule,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Timing: ${a.shift?.startTime ?? '-'} - ${a.shift?.endTime ?? '-'}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      if (a.shift?.breakStartTime != null &&
                          a.shift?.breakEndTime != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.free_breakfast,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Break: ${a.shift?.breakStartTime} - ${a.shift?.breakEndTime}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Date: ${_fmtDate(a.assignedDate)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      if (a.gates?.type != null &&
                          a.gates!.type!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.door_front_door,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Access Point Type: ${a.gates?.type}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ],

                      // Show attendance details if available
                      if (matchedAtt != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.how_to_reg,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Attendance: ${matchedAtt.status}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        if (matchedAtt.checkInTime != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.login,
                                  size: 18, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                'Check-in: ${matchedAtt.checkInTime}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                        if (matchedAtt.checkOutTime != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.logout,
                                  size: 18, color: Colors.red),
                              const SizedBox(width: 6),
                              Text(
                                'Check-out: ${matchedAtt.checkOutTime}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ],

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
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32))),
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

  Widget _checkButtons(
      BuildContext context, ShiftsProvider prov, int assignmentId) {
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
        (att.checkOutTime is String
            ? (att.checkOutTime as String).isNotEmpty
            : true);

    // Keep your global gates if you use them for time windows/policy
    final baseCanIn = prov.canCheckIn(assignmentId);
    final baseCanOut = prov.canCheckOut(assignmentId);
    final showCheckIn = (att == null) && baseCanIn;
    final showCheckOut = (att != null) && !hasCheckedOut && baseCanOut;
    if (!showCheckIn && !showCheckOut) return const SizedBox.shrink();

    final busyIn = prov.checkingIn;
    final busyOut = prov.checkingOut;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (showCheckIn)
          ElevatedButton.icon(
            onPressed: busyIn
                ? null
                : () async {
                    if (prov.checkingIn) return;
                    await _handleCheckIn(context, assignmentId);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: busyIn
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.login, color: Colors.white),
            label: Text(
              busyIn ? 'Checking in…' : 'Check-in',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        if (showCheckOut)
          ElevatedButton.icon(
            onPressed: busyOut
                ? null
                : () async {
                    if (prov.checkingOut) return;
                    await _handleCheckOut(context, assignmentId);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: busyOut
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.logout, color: Colors.white),
            label: Text(
              busyOut ? 'Checking out…' : 'Check-out',
              style: const TextStyle(color: Colors.white),
            ),
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
                child:
                    Text('No Device Assigned', style: TextStyle(fontSize: 16)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assigned Devices',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...devices.map(
                    (d) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.devices_other),
                      title: Text(d.deviceSerial,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: Text('${d.deviceModel}',
                          style: const TextStyle(fontSize: 10)),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Access Point ${d.gate} • ${d.gateType}'),
                          Text(d.station,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
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
                child: Text('No Attendance History',
                    style: TextStyle(fontSize: 16)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance (Last 10 days)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...last10.map(
                    (a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month),
                      title: Text(_fmtDate(a.date)),
                      subtitle: Text(
                          'In: ${a.checkInTime ?? '-'}  |  Out: ${a.checkOutTime ?? '-'}'),
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
      child:
          Text(status, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
    );
  }

  Future<AssignShiftInput?> _openAssignForm(
    BuildContext context, {
    required String token,
    AssignShift? initial,
  }) async {
    return await Navigator.push<AssignShiftInput>(
      context,
      MaterialPageRoute(
        builder: (_) => _AssignFormScreen(token: token, initial: initial),
      ),
    );
  }

  Future<void> _openShiftDetailScreen(
      BuildContext context, int assignmentId) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      _toast(context, 'Session expired. Please login again.',
          tone: _ShiftSnackTone.error);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShiftAssignmentDetailScreen(
          assignmentId: assignmentId,
          token: token,
        ),
      ),
    );
  }

  Future<AssignBulkShiftInput?> _openBulkAssignForm(
    BuildContext context, {
    required String token,
    AssignShift? initial,
  }) async {
    return await Navigator.push<AssignBulkShiftInput>(
      context,
      MaterialPageRoute(
        builder: (_) => _AssignBulkFormScreen(token: token, initial: initial),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

// ========== SHIFT CARD WIDGET ==========
class _ShiftCardWidget extends StatefulWidget {
  final AssignShift shift;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(DateTime) formatDate;
  final VoidCallback? onTap;

  const _ShiftCardWidget({
    required this.shift,
    required this.onEdit,
    required this.onDelete,
    required this.formatDate,
    this.onTap,
  });

  @override
  State<_ShiftCardWidget> createState() => _ShiftCardWidgetState();
}

class _ShiftCardWidgetState extends State<_ShiftCardWidget> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shift = widget.shift;
    final isCompleted = shift.isCompleted == 1;
    final hasAttendance = shift.hasAttendance ?? false;

    // Determine circle color: green for completed, blue for has attendance, red for pending
    final circleColor =
        isCompleted ? Colors.green : (hasAttendance ? Colors.blue : Colors.red);

    // Determine main status text
    final String mainStatus;
    final Color mainStatusColor;
    final IconData mainStatusIcon;

    if (isCompleted) {
      mainStatus = 'Completed';
      mainStatusColor = Colors.green;
      mainStatusIcon = Icons.check_circle;
    } else if (hasAttendance) {
      mainStatus = 'On Job';
      mainStatusColor = Colors.blue;
      mainStatusIcon = Icons.work;
    } else {
      mainStatus = 'Pending';
      mainStatusColor = Colors.orange;
      mainStatusIcon = Icons.pending;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: (shift.userProfileImageUrl != null &&
                            shift.userProfileImageUrl!.trim().isNotEmpty &&
                            shift.userProfileImageUrl!.trim().toLowerCase() != 'null')
                        ? NetworkImage(shift.userProfileImageUrl!)
                        : const AssetImage('assets/images/profile.jpg')
                            as ImageProvider,
                    child: (shift.userProfileImageUrl == null ||
                            shift.userProfileImageUrl!.trim().isEmpty ||
                            shift.userProfileImageUrl!.trim().toLowerCase() == 'null')
                        ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: circleColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                shift.assignedUserName ?? 'User',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: mainStatusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(mainStatusIcon,
                                      size: 10, color: mainStatusColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    mainStatus,
                                    style: TextStyle(
                                      color: mainStatusColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${shift.stationName ?? shift.station?.name ?? '-'} • Access Point ${shift.gateName ?? shift.gates?.name ?? '-'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${shift.shiftName ?? 'Shift'} • ${widget.formatDate(shift.assignedDate)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[700],
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasAttendance &&
                                shift.attendanceStatus != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getAttendanceColor(
                                          shift.attendanceStatus!)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getAttendanceIcon(
                                          shift.attendanceStatus!),
                                      color: _getAttendanceColor(
                                          shift.attendanceStatus!),
                                      size: 10,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      shift.attendanceStatus!,
                                      style: TextStyle(
                                        color: _getAttendanceColor(
                                            shift.attendanceStatus!),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
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
                _buildDetailRow(Icons.location_on, 'Station',
                    shift.stationName ?? shift.station?.name ?? '-', theme),
                const SizedBox(height: 6),
                _buildDetailRow(
                  Icons.door_front_door,
                  'Access Point',
                  _buildGateInfo(shift),
                  theme,
                ),
                const SizedBox(height: 6),
                _buildDetailRow(Icons.access_time, 'Shift',
                    shift.shiftName ?? shift.shift?.name ?? '-', theme),
                const SizedBox(height: 6),
                _buildDetailRow(
                  Icons.schedule,
                  'Shift Timing',
                  _buildShiftTiming(shift),
                  theme,
                ),
                if (_hasBreakTiming(shift)) ...[
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    Icons.free_breakfast,
                    'Break Timing',
                    _buildBreakTiming(shift),
                    theme,
                  ),
                ],
                const SizedBox(height: 8),
                // Edit and Delete Buttons (only if not completed and no attendance)
                if (!isCompleted) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: hasAttendance ? null : widget.onEdit,
                          icon: const Icon(Icons.edit,
                              size: 16, color: Colors.white),
                          label: const Text('Edit',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            disabledBackgroundColor: Colors.grey,
                            disabledForegroundColor: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: null, // Disabled delete button
                          icon: const Icon(Icons.delete,
                              size: 16, color: Colors.white),
                          label: const Text('Delete',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            disabledBackgroundColor: Colors.grey,
                            disabledForegroundColor: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _buildGateInfo(AssignShift shift) {
    final gateName = shift.gateName ?? shift.gates?.name ?? '-';
    final gateType = shift.gates?.type;
    if (gateType != null && gateType.isNotEmpty) {
      return '$gateName ($gateType)';
    }
    return gateName;
  }

  String _buildShiftTiming(AssignShift shift) {
    final startTime = shift.shift?.startTime;
    final endTime = shift.shift?.endTime;
    if (startTime != null && endTime != null) {
      return '$startTime - $endTime';
    }
    return '-';
  }

  bool _hasBreakTiming(AssignShift shift) {
    final breakStart = shift.shift?.breakStartTime;
    final breakEnd = shift.shift?.breakEndTime;
    return breakStart != null &&
        breakEnd != null &&
        breakStart.isNotEmpty &&
        breakEnd.isNotEmpty;
  }

  String _buildBreakTiming(AssignShift shift) {
    final breakStart = shift.shift?.breakStartTime;
    final breakEnd = shift.shift?.breakEndTime;
    if (breakStart != null && breakEnd != null) {
      return '$breakStart - $breakEnd';
    }
    return '-';
  }

  Color _getAttendanceColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'half day':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getAttendanceIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'late':
        return Icons.access_time;
      case 'half day':
        return Icons.schedule;
      default:
        return Icons.info;
    }
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
          Expanded(
              child: Image.file(imageFile,
                  fit: BoxFit.cover, width: double.infinity)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Retake',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Confirm',
                        style: TextStyle(color: Colors.white)),
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

class _AssignFormScreen extends StatefulWidget {
  final String token;
  final AssignShift? initial;
  const _AssignFormScreen({required this.token, this.initial});

  @override
  State<_AssignFormScreen> createState() => _AssignFormScreenState();
}

class _AssignFormScreenState extends State<_AssignFormScreen> {
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
  bool _canSubmit = false;
  bool _hasChanges = false;
  DateTime? _initialDate;
  int? _initialUserId;
  int? _initialShiftId;
  int? _initialStationId;
  int? _initialGateId;

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
    _captureInitialValues();
    _bootstrap();
  }

  void _captureInitialValues() {
    _initialDate = _date;
    _initialUserId = _userId;
    _initialShiftId = _shiftId;
    _initialStationId = _stationId;
    _initialGateId = _gateId;
    _updateSubmitState();
  }

  void _updateSubmitState() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final dateValid = _date != null &&
        (_date!.isAfter(todayStart) ||
            (widget.initial != null && _isSameDate(_date, _initialDate)));
    final userValid = _userId != null;
    final shiftValid = _shiftId != null;
    final stationValid = _stationId != null;
    final gateValid = _gateId != null;

    final isValid =
        dateValid && userValid && shiftValid && stationValid && gateValid;

    bool changed;
    if (widget.initial == null) {
      changed = isValid;
    } else {
      changed = !_isSameDate(_date, _initialDate) ||
          _userId != _initialUserId ||
          _shiftId != _initialShiftId ||
          _stationId != _initialStationId ||
          _gateId != _initialGateId;
    }

    final shouldEnable = isValid && changed;

    if (_canSubmit != shouldEnable || _hasChanges != changed) {
      setState(() {
        _canSubmit = shouldEnable;
        _hasChanges = changed;
      });
    }
  }

  bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
      _updateSubmitState();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      _updateSubmitState();
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Assign Shift' : 'Edit Shift'),
        backgroundColor: brand,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Close'),
                        )
                      ],
                    ),
                  ),
                )
              : _buildForm(context, meta, usersProv),
    );
  }

  Widget _buildForm(
      BuildContext context, LookupProvider meta, UsersProvider usersProv) {
    final gates = (_stationId == null)
        ? const <GateLite>[]
        : (meta.gatesByStation[_stationId!] ?? const <GateLite>[]);
    final gatesLoading =
        (_stationId != null) && meta.isLoadingGates(_stationId!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date
            TextFormField(
              controller: _dateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Assigned Date',
                prefixIcon: const Icon(Icons.calendar_today),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: () async {
                    final now = DateTime.now();
                    final todayStart = DateTime(now.year, now.month, now.day);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date != null && _date!.isAfter(todayStart)
                          ? _date!
                          : todayStart,
                      firstDate: todayStart,
                      lastDate: DateTime(now.year + 2),
                    );
                    if (picked != null) {
                      setState(() {
                        _date = picked;
                        _dateCtrl.text = _fmtDate(picked);
                        _updateSubmitState();
                      });
                    }
                  },
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Pick date' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              value: _userId, // safe
              isExpanded: true,
              items: usersProv.items.map((u) {
                final title = (u.name.isNotEmpty == true)
                    ? u.name
                    : (u.email ?? 'User ${u.id}');
                return DropdownMenuItem<int>(value: u.id, child: Text(title));
              }).toList(),
              onChanged: (v) {
                setState(() => _userId = v);
                _updateSubmitState();
              },
              decoration: const InputDecoration(
                labelText: 'User',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null ? 'Select a user' : null,
            ),

            const SizedBox(height: 16),

            // Shift
            DropdownButtonFormField<int>(
              value: _shiftId,
              items: meta.shifts
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(
                            '${s.name} (${s.startTime ?? '--'} - ${s.endTime ?? '--'})'),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _shiftId = v);
                _updateSubmitState();
              },
              decoration: const InputDecoration(
                  labelText: 'Shift', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Select a shift' : null,
            ),
            const SizedBox(height: 16),

            // Station
            DropdownButtonFormField<int>(
              value: _stationId,
              items: meta.stations
                  .map((st) => DropdownMenuItem(
                        value: st.id,
                        child: Text(st.name),
                      ))
                  .toList(),
              onChanged: (v) async {
                setState(() {
                  _stationId = v;
                  _gateId = null;
                  _updateSubmitState();
                });
                if (v != null) {
                  await context
                      .read<LookupProvider>()
                      .fetchGatesForStation(widget.token, v);
                  _updateSubmitState();
                }
              },
              decoration: const InputDecoration(
                  labelText: 'Station', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Select a station' : null,
            ),
            const SizedBox(height: 16),

            // Gate
            gatesLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                : DropdownButtonFormField<int>(
                    value: _gateId,
                    items: gates
                        .map((g) => DropdownMenuItem(
                              value: g.id,
                              child: Text('${g.name} (${g.type ?? '-'})'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _gateId = v);
                      _updateSubmitState();
                    },
                    decoration: const InputDecoration(
                        labelText: 'Access Point', border: OutlineInputBorder()),
                    validator: (v) => v == null ? 'Select a access point' : null,
                  ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.blue.withOpacity(0.5),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: Text(
                    widget.initial == null ? 'Assign Shift' : 'Update Shift'),
                onPressed: !_canSubmit
                    ? null
                    : () {
                        if (!_formKey.currentState!.validate()) return;

                        if (widget.initial != null && !_hasChanges) {
                          AppSnackBar.error(
                              context, 'No changes to update');
                          return;
                        }

                        final d = _date;
                        if (d == null ||
                            _userId == null ||
                            _shiftId == null ||
                            _stationId == null ||
                            _gateId == null) {
                          AppSnackBar.error(
                              context, 'Please complete all required fields.');
                          return;
                        }
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _AssignBulkFormScreen extends StatefulWidget {
  final String token;
  final AssignShift? initial;
  const _AssignBulkFormScreen({required this.token, this.initial});

  @override
  State<_AssignBulkFormScreen> createState() => _AssignBulkFormScreenState();
}

class _AssignBulkFormScreenState extends State<_AssignBulkFormScreen> {
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
  bool _canSubmit = false;
  bool _hasChanges = false;
  DateTime? _initialFrom;
  DateTime? _initialTo;
  int? _initialUserId;
  int? _initialShiftId;
  int? _initialStationId;
  int? _initialGateId;

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
    _captureInitialValues();
    _bootstrap();
  }

  void _captureInitialValues() {
    _initialFrom = _fromDate;
    _initialTo = _toDate;
    _initialUserId = _userId;
    _initialShiftId = _shiftId;
    _initialStationId = _stationId;
    _initialGateId = _gateId;
    _updateSubmitState();
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
      _updateSubmitState();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      _updateSubmitState();
    }
  }

  @override
  void dispose() {
    _dateFromCtrl.dispose();
    _dateToCtrl.dispose();
    super.dispose();
  }

  bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _updateSubmitState() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    final fromValid = _fromDate != null &&
        (_fromDate!.isAfter(todayStart) ||
            (widget.initial != null && _isSameDate(_fromDate, _initialFrom)));
    final toValid = _toDate != null &&
        (_toDate!.isAfter(todayStart) ||
            (widget.initial != null && _isSameDate(_toDate, _initialTo)));
    final rangeValid =
        fromValid && toValid && (_toDate!.isAfter(_fromDate!) || _isSameDate(_toDate, _fromDate));
    final userValid = _userId != null;
    final shiftValid = _shiftId != null;
    final stationValid = _stationId != null;
    final gateValid = _gateId != null;

    final isValid =
        rangeValid && userValid && shiftValid && stationValid && gateValid;

    bool changed;
    if (widget.initial == null) {
      changed = isValid;
    } else {
      changed = !_isSameDate(_fromDate, _initialFrom) ||
          !_isSameDate(_toDate, _initialTo) ||
          _userId != _initialUserId ||
          _shiftId != _initialShiftId ||
          _stationId != _initialStationId ||
          _gateId != _initialGateId;
    }

    final shouldEnable = isValid && changed;

    if (_canSubmit != shouldEnable || _hasChanges != changed) {
      setState(() {
        _canSubmit = shouldEnable;
        _hasChanges = changed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = context.watch<LookupProvider>();
    final usersProv = context.watch<UsersProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bulk Assign Shifts'),
        backgroundColor: brand,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Close'),
                        )
                      ],
                    ),
                  ),
                )
              : _buildForm(context, meta, usersProv),
    );
  }

  Widget _buildForm(
      BuildContext context, LookupProvider meta, UsersProvider usersProv) {
    final gates = (_stationId == null)
        ? const <GateLite>[]
        : (meta.gatesByStation[_stationId!] ?? const <GateLite>[]);
    final gatesLoading =
        (_stationId != null) && meta.isLoadingGates(_stationId!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // From Date
            TextFormField(
              controller: _dateFromCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'From Date',
                prefixIcon: const Icon(Icons.calendar_today),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fromDate ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (picked != null) {
                      setState(() {
                        _fromDate = picked;
                        _dateFromCtrl.text = _fmtDate(picked);
                      });
                    }
                  },
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Pick date' : null,
            ),
            const SizedBox(height: 16),

            // To Date
            TextFormField(
              controller: _dateToCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'To Date',
                prefixIcon: const Icon(Icons.event),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _toDate ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (picked != null) {
                      setState(() {
                        _toDate = picked;
                        _dateToCtrl.text = _fmtDate(picked);
                      });
                    }
                  },
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Pick date' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              value: _userId, // safe
              isExpanded: true,
              items: usersProv.items.map((u) {
                final title = (u.name.isNotEmpty == true)
                    ? u.name
                    : (u.email ?? 'User ${u.id}');
                return DropdownMenuItem<int>(value: u.id, child: Text(title));
              }).toList(),
              onChanged: (v) {
                setState(() => _userId = v);
                _updateSubmitState();
              },
              decoration: const InputDecoration(
                labelText: 'User',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null ? 'Select a user' : null,
            ),

            const SizedBox(height: 16),

            // Shift
            DropdownButtonFormField<int>(
              value: _shiftId,
              items: meta.shifts
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(
                            '${s.name} (${s.startTime ?? '--'} - ${s.endTime ?? '--'})'),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _shiftId = v);
                _updateSubmitState();
              },
              decoration: const InputDecoration(
                  labelText: 'Shift', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Select a shift' : null,
            ),
            const SizedBox(height: 16),

            // Station
            DropdownButtonFormField<int>(
              value: _stationId,
              items: meta.stations
                  .map((st) => DropdownMenuItem(
                        value: st.id,
                        child: Text(st.name),
                      ))
                  .toList(),
              onChanged: (v) async {
                setState(() {
                  _stationId = v;
                  _gateId = null;
                  _updateSubmitState();
                });
                if (v != null) {
                  await context
                      .read<LookupProvider>()
                      .fetchGatesForStation(widget.token, v);
                  _updateSubmitState();
                }
              },
              decoration: const InputDecoration(
                  labelText: 'Station', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Select a station' : null,
            ),
            const SizedBox(height: 16),

            // Gate
            gatesLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                : DropdownButtonFormField<int>(
                    value: _gateId,
                    items: gates
                        .map((g) => DropdownMenuItem(
                              value: g.id,
                              child: Text('${g.name} (${g.type ?? '-'})'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _gateId = v);
                      _updateSubmitState();
                    },
                    decoration: const InputDecoration(
                        labelText: 'Access Point', border: OutlineInputBorder()),
                    validator: (v) => v == null ? 'Select a access point' : null,
                  ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.blue.withOpacity(0.5),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: const Text('Bulk Assign Shifts'),
                onPressed: !_canSubmit
                    ? null
                    : () {
                        if (!_formKey.currentState!.validate()) return;

                        if (widget.initial != null && !_hasChanges) {
                          AppSnackBar.error(
                              context, 'No changes to update');
                          return;
                        }

                        final fromDate = _fromDate;
                        final toDate = _toDate;
                        if (fromDate == null ||
                            toDate == null ||
                            fromDate.isAfter(toDate) ||
                            _userId == null ||
                            _shiftId == null ||
                            _stationId == null ||
                            _gateId == null) {
                          AppSnackBar.error(
                              context, 'Please complete all required fields.');
                          return;
                        }
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ========== WEEK OFF CARD WIDGET ==========
class _WeekOffCardWidget extends StatefulWidget {
  final WeekOff weekOff;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(DateTime) formatDate;

  const _WeekOffCardWidget({
    required this.weekOff,
    required this.onEdit,
    required this.onDelete,
    required this.formatDate,
  });

  @override
  State<_WeekOffCardWidget> createState() => _WeekOffCardWidgetState();
}

class _WeekOffCardWidgetState extends State<_WeekOffCardWidget> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekOff = widget.weekOff;

    // Check if week off has passed or is today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isPassed = false;

    if (weekOff.offDate != null) {
      final offDate = DateTime(
          weekOff.offDate!.year, weekOff.offDate!.month, weekOff.offDate!.day);
      isPassed = offDate.isBefore(today) || offDate.isAtSameMomentAs(today);
    }

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
                  backgroundImage: (weekOff.userProfileImageUrl != null &&
                          weekOff.userProfileImageUrl!.trim().isNotEmpty &&
                          weekOff.userProfileImageUrl!.trim().toLowerCase() != 'null')
                      ? NetworkImage(weekOff.userProfileImageUrl!)
                      : const AssetImage('assets/images/profile.jpg')
                          as ImageProvider,
                  child: (weekOff.userProfileImageUrl == null ||
                          weekOff.userProfileImageUrl!.trim().isEmpty ||
                          weekOff.userProfileImageUrl!.trim().toLowerCase() == 'null')
                      ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                      : null,
                ),
                const SizedBox(width: 10),
                // Center: User Name, Date/Recurring, Reason
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: User Name with grey circle
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              weekOff.userName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Row 2: Date and Recurring
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              weekOff.isRecurring
                                  ? 'Recurring: ${weekOff.weekday ?? 'N/A'}'
                                  : 'Date: ${weekOff.offDate != null ? widget.formatDate(weekOff.offDate!) : 'N/A'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Row 3: Reason
                      if (weekOff.reason != null && weekOff.reason!.isNotEmpty)
                        Text(
                          'Reason: ${weekOff.reason}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              // Details
              _buildDetailRow(Icons.person, 'User', weekOff.userName, theme),
              const SizedBox(height: 6),
              if (weekOff.offDate != null)
                _buildDetailRow(Icons.calendar_today, 'Off Date',
                    widget.formatDate(weekOff.offDate!), theme),
              if (weekOff.offDate != null) const SizedBox(height: 6),
              _buildDetailRow(
                Icons.repeat,
                'Recurring',
                weekOff.isRecurring
                    ? 'Yes (${weekOff.weekday ?? 'N/A'})'
                    : 'No',
                theme,
              ),
              const SizedBox(height: 6),
              if (weekOff.reason != null && weekOff.reason!.isNotEmpty)
                _buildDetailRow(Icons.note, 'Reason', weekOff.reason!, theme),
              if (weekOff.reason != null && weekOff.reason!.isNotEmpty)
                const SizedBox(height: 8),

              // Edit and Delete Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isPassed ? null : widget.onEdit,
                      icon:
                          const Icon(Icons.edit, size: 16, color: Colors.white),
                      label: const Text('Edit',
                          style: TextStyle(fontSize: 12, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        disabledBackgroundColor: Colors.grey,
                        disabledForegroundColor: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isPassed ? null : widget.onDelete,
                      icon: const Icon(Icons.delete,
                          size: 16, color: Colors.white),
                      label: const Text('Delete',
                          style: TextStyle(fontSize: 12, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        disabledBackgroundColor: Colors.grey,
                        disabledForegroundColor: Colors.white70,
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

  Widget _buildDetailRow(
      IconData icon, String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
  int? _userId;
  late final TextEditingController _reasonController;
  bool _canSubmit = false;
  bool _hasChanges = false;
  int? _initialUserId;
  DateTime? _initialOffDate;
  bool _initialIsRecurring = false;
  String? _initialWeekday;
  String _initialReason = '';

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
    _reasonController =
        TextEditingController(text: widget.weekOff?.reason ?? '');
    _captureInitialValues();
    _reasonController.addListener(_updateSubmitState);

    _loadUsers();
  }

  void _captureInitialValues() {
    _initialUserId = _userId;
    _initialOffDate = _offDate;
    _initialIsRecurring = _isRecurring;
    _initialWeekday = _weekday;
    _initialReason = _reasonController.text.trim();
    _updateSubmitState();
  }

  bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _updateSubmitState() {
    final reason = _reasonController.text.trim();
    final reasonValid = reason.length >= 5;
    final userValid = _userId != null;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final scheduleValid = _isRecurring
        ? (_weekday != null && _weekday!.isNotEmpty)
        : (_offDate != null && _offDate!.isAfter(todayStart));

    bool changed;
    if (widget.weekOff == null) {
      changed = userValid || scheduleValid || reason.isNotEmpty;
    } else {
      changed = (_userId != _initialUserId) ||
          (_isRecurring != _initialIsRecurring) ||
          (!_isRecurring && !_isSameDate(_offDate, _initialOffDate)) ||
          (_isRecurring && _weekday != _initialWeekday) ||
          (reason != _initialReason);
    }

    final shouldEnable = reasonValid && userValid && scheduleValid && changed;

    if (shouldEnable != _canSubmit || changed != _hasChanges) {
      setState(() {
        _canSubmit = shouldEnable;
        _hasChanges = changed;
      });
    }
  }

  @override
  void dispose() {
    _reasonController.removeListener(_updateSubmitState);
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final usersProv = context.read<UsersProvider>();
      if (usersProv.items.isEmpty) {
        await usersProv.load(widget.token);
      }
      setState(() => _loading = false);
      _updateSubmitState();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      _updateSubmitState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersProv = context.watch<UsersProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.weekOff == null ? 'Add Week Off' : 'Edit Week Off'),
        backgroundColor: const Color(0xFFA7D222),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        )
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                          onChanged: (v) {
                            setState(() => _userId = v);
                            _updateSubmitState();
                          },
                          decoration: const InputDecoration(
                            labelText: 'User',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null ? 'Select a user' : null,
                        ),
                        const SizedBox(height: 16),

                        // Date Picker (only show if not recurring)
                        if (!_isRecurring)
                          InkWell(
                            onTap: () async {
                              final now = DateTime.now();
                              final minDate = DateTime(
                                now.year,
                                now.month,
                                now.day,
                              ).add(const Duration(days: 1));
                              final initialDate = (_offDate != null &&
                                      _offDate!.isAfter(minDate))
                                  ? _offDate!
                                  : minDate;
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: initialDate,
                                firstDate: minDate,
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => _offDate = picked);
                                _updateSubmitState();
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Off Date',
                                prefixIcon: Icon(Icons.calendar_today),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _offDate != null
                                    ? "${_offDate!.day.toString().padLeft(2, '0')}-${_offDate!.month.toString().padLeft(2, '0')}-${_offDate!.year}"
                                    : "Pick Off Date",
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Recurring Switch
                        SwitchListTile(
                          title: const Text("Recurring weekly"),
                          value: _isRecurring,
                          onChanged: (val) {
                            setState(() {
                              _isRecurring = val;
                              if (val) {
                                _offDate = null; // clear date if recurring
                              } else {
                                _weekday = null;
                              }
                            });
                            _updateSubmitState();
                          },
                        ),

                        // Weekday dropdown (only show if recurring)
                        if (_isRecurring)
                          DropdownButtonFormField<String>(
                            value: _weekday,
                            items: const [
                              DropdownMenuItem(
                                  value: "Monday", child: Text("Monday")),
                              DropdownMenuItem(
                                  value: "Tuesday", child: Text("Tuesday")),
                              DropdownMenuItem(
                                  value: "Wednesday", child: Text("Wednesday")),
                              DropdownMenuItem(
                                  value: "Thursday", child: Text("Thursday")),
                              DropdownMenuItem(
                                  value: "Friday", child: Text("Friday")),
                              DropdownMenuItem(
                                  value: "Saturday", child: Text("Saturday")),
                              DropdownMenuItem(
                                  value: "Sunday", child: Text("Sunday")),
                            ],
                            onChanged: (v) {
                              setState(() => _weekday = v ?? '');
                              _updateSubmitState();
                            },
                            decoration: const InputDecoration(
                              labelText: "Select Weekday",
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                _isRecurring && (v == null || v.isEmpty)
                                    ? 'Select a weekday'
                                    : null,
                          ),
                        const SizedBox(height: 16),

                        // Reason
                        TextFormField(
                          controller: _reasonController,
                          decoration: const InputDecoration(
                            labelText: "Reason",
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Reason is required';
                            if (value.length < 5) {
                              return 'Reason must be at least 5 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              disabledBackgroundColor:
                                  Colors.blue.withOpacity(0.5),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white70,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text("Save Week Off"),
                            onPressed: !_canSubmit
                                ? null
                                : () {
                              if (!_formKey.currentState!.validate()) return;

                              if (!_isRecurring && _offDate == null) {
                                AppSnackBar.info(context, 'Pick an off date');
                                return;
                              }

                              if (_isRecurring &&
                                  (_weekday == null || _weekday!.isEmpty)) {
                                AppSnackBar.info(
                                    context, 'Select a weekday for recurring week off');
                                return;
                              }

                              if (widget.weekOff != null && !_hasChanges) {
                                AppSnackBar.error(
                                    context, 'No changes to update');
                                return;
                              }

                              if (!_canSubmit) {
                                AppSnackBar.error(
                                    context, 'Please complete all required fields.');
                                return;
                              }

                              final weekOff = WeekOff(
                                id: widget.weekOff?.id ?? 0,
                                userId: _userId!,
                                assignBy: widget.weekOff?.assignBy ?? 0,
                                organizationId:
                                    widget.weekOff?.organizationId ?? 0,
                                offDate: _isRecurring
                                    ? null
                                    : _offDate, // nullable if recurring
                                weekday: _isRecurring ? (_weekday ?? '') : '',
                                isRecurring: _isRecurring,
                                reason: _reasonController.text.trim(),
                                createdAt:
                                    widget.weekOff?.createdAt ?? DateTime.now(),
                                updatedAt: DateTime.now(),
                                userName: widget.weekOff?.userName ?? '',
                              );

                              Navigator.pop(context, weekOff);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
