import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import '../../../providers/imagepicker_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../users/providers/users_provider.dart';
import '../models/assign_shift_models.dart';
import '../models/lookup_models.dart';
import '../models/my_shifts_models.dart';
import '../providers/lookup_provider.dart';
import '../providers/shift_assign_provider.dart';
import '../providers/shifts_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ShiftsTab extends StatefulWidget {
  const ShiftsTab({super.key});

  @override
  State<ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<ShiftsTab> with SingleTickerProviderStateMixin {
  TabController? _tabCtrl;
  // final ImagePicker _picker = ImagePicker();
  // bool get _hasAssignShiftView => context.select<AuthProvider, bool>((auth) {
  //   final role  = auth.user?.role;
  //   final perms = auth.user?.permissions ?? const <String>[];
  //
  //   // elevated roles get full access
  //   // const elevated = {'Admin', 'Manager', 'CEO', 'super_admin'};
  //   // if (elevated.contains(role)) return true;
  //
  //   // explicit super-permission
  //   if (perms.contains('all')) return true;
  //
  //   // specific permission
  //   return perms.contains('assignshift.view');
  // });

  bool get _hasAssignShiftView {
    final perms = context.read<AuthProvider>().user?.permissions ?? const <String>[];
    print("Permision : $perms");
    if (perms.contains('all')) return true;
    return perms.contains('assignshift.view');
  }

  void _initOrUpdateTabController({bool force = false}) {
    final len = _hasAssignShiftView ? 2 : 1;
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

    // Step 1: Capture selfie
    // final File? photo = await pickCompressedImage();
    // if (photo == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('No photo captured')),
    //   );
    //   return;
    // }
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
    // final File? photo = await pickCompressedImage();
    // if (photo == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('No photo captured')),
    //   );
    //   return;
    // }
    // final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    // if (photo == null) return;

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

  // Future<File?> pickCompressedImage() async {
  //   // Step 1: Pick image
  //   final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
  //   if (photo == null) return null;
  //
  //   final File file = File(photo.path);
  //
  //   // Step 2: Temp path
  //   final dir = await getTemporaryDirectory();
  //   final targetPath = p.join(
  //     dir.path,
  //     "compressed_${DateTime.now().millisecondsSinceEpoch}.jpg",
  //   );
  //
  //   // Step 3: Compress
  //   final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
  //     file.absolute.path,
  //     targetPath,
  //     quality: 80,
  //     minWidth: 1280,
  //     minHeight: 720,
  //   );
  //
  //   if (compressedFile == null) return file;
  //
  //   // Step 4: Convert XFile → File
  //   final compressed = File(compressedFile.path);
  //
  //   // Step 5: Size check
  //   final sizeInMB = compressed.lengthSync() / (1024 * 1024);
  //   print("Compressed size: ${sizeInMB.toStringAsFixed(2)} MB");
  //
  //   if (sizeInMB > 5) {
  //     // re-compress lower quality if needed
  //     final XFile? smallerFile = await FlutterImageCompress.compressAndGetFile(
  //       compressed.path,
  //       targetPath,
  //       quality: 60,
  //       minWidth: 1024,
  //       minHeight: 576,
  //     );
  //     return smallerFile != null ? File(smallerFile.path) : compressed;
  //   }
  //
  //   return compressed;
  // }

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
  // Widget build(BuildContext context) {
  //   // final color = Theme.of(context).colorScheme; // (unused)
  //   final hasAssignShiftView = context.select<AuthProvider, bool>((auth) {
  //     final perms = auth.user?.permissions ?? const <String>[];
  //     if (perms.contains('all')) return true;
  //     return perms.contains('assignshift.view');
  //   });
  //
  //   // Build dynamic tabs + views
  //   final tabs = <Tab>[
  //     const Tab(text: 'My Duty'),
  //     if (hasAssignShiftView) const Tab(text: 'All Shifts'),
  //   ];
  //
  //   final views = <Widget>[
  //     // ---------- My Duty ----------
  //     Consumer<ShiftsProvider>(
  //       builder: (_, prov, __) {
  //         if (prov.loading && prov.assignments.isEmpty) {
  //           return const Center(child: CircularProgressIndicator());
  //         }
  //         if (prov.error != null) {
  //           return RefreshIndicator(
  //             onRefresh: _refreshMy,
  //             child: ListView(
  //               physics: const AlwaysScrollableScrollPhysics(),
  //               padding: const EdgeInsets.all(16),
  //               children: [
  //                 Text(prov.error!, style: const TextStyle(color: Colors.red)),
  //               ],
  //             ),
  //           );
  //         }
  //         return RefreshIndicator(
  //           onRefresh: _refreshMy,
  //           child: ListView(
  //             padding: const EdgeInsets.all(12),
  //             children: [
  //               _todayCard(context, prov),
  //               const SizedBox(height: 12),
  //               _assignedDevicesSection(prov.devices),
  //               const SizedBox(height: 12),
  //               _attendanceSection(prov.attendance),
  //               const SizedBox(height: 40),
  //             ],
  //           ),
  //         );
  //       },
  //     ),
  //
  //     // ---------- All Shifts (only if allowed) ----------
  //     if (hasAssignShiftView)
  //       Stack(
  //         children: [
  //           Consumer<ShiftAssignProvider>(
  //             builder: (_, prov, __) {
  //               final token = context.read<AuthProvider>().token;
  //
  //               return RefreshIndicator(
  //                 onRefresh: () async {
  //                   if (token != null) await prov.fetchAll(token);
  //                 },
  //                 child: prov.loading && prov.items.isEmpty
  //                     ? ListView(
  //                   children: const [
  //                     SizedBox(height: 200),
  //                     Center(child: CircularProgressIndicator()),
  //                   ],
  //                 )
  //                     : ListView.separated(
  //                   physics: const AlwaysScrollableScrollPhysics(),
  //                   padding: const EdgeInsets.all(16),
  //                   itemCount: prov.items.length,
  //                   separatorBuilder: (_, __) => const SizedBox(height: 10),
  //                   itemBuilder: (_, i) {
  //                     final s = prov.items[i];
  //                     return ListTile(
  //                       shape: RoundedRectangleBorder(
  //                         borderRadius: BorderRadius.circular(12),
  //                       ),
  //                       tileColor: Colors.grey.shade50,
  //                       leading: const Icon(Icons.assignment_turned_in_outlined),
  //                       title: Text(
  //                         '${s.stationName ?? s.station?.name ?? '-'} • Gate ${s.gateName ?? s.gates?.name ?? '-'}',
  //                       ),
  //                       subtitle: Text(
  //                         'User: ${s.assignedUserName}  |  Shift: ${s.shiftName}\nDate: ${_fmtDate(s.assignedDate)}',
  //                       ),
  //                       isThreeLine: true,
  //                       trailing: PopupMenuButton<String>(
  //                         onSelected: (v) async {
  //                           if (s.isCompleted == 1) return;
  //                           final t = context.read<AuthProvider>().token;
  //                           if (t == null) return;
  //
  //                           if (v == 'edit') {
  //                             final input = await _openAssignForm(context, initial: s, token: t);
  //                             if (input != null) {
  //                               final ok = await prov.update(t, s.id, input);
  //                               _toast(context, ok ? 'Updated' : prov.error ?? 'Update failed');
  //                             }
  //                           } else if (v == 'delete') {
  //                             final okConfirm = await _confirmDelete(context);
  //                             if (okConfirm == true) {
  //                               final ok = await prov.remove(t, s.id);
  //                               _toast(context, ok ? 'Deleted' : prov.error ?? 'Delete failed');
  //                             }
  //                           }
  //                         },
  //                         itemBuilder: (_) => [
  //                           PopupMenuItem(
  //                             value: 'edit',
  //                             enabled: s.isCompleted != 1,
  //                             child: Text(
  //                               'Edit',
  //                               style: TextStyle(
  //                                 color: s.isCompleted == 1 ? Colors.grey : Colors.black,
  //                               ),
  //                             ),
  //                           ),
  //                           PopupMenuItem(
  //                             value: 'delete',
  //                             enabled: s.isCompleted != 1,
  //                             child: Text(
  //                               'Delete',
  //                               style: TextStyle(
  //                                 color: s.isCompleted == 1 ? Colors.grey : Colors.black,
  //                               ),
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     );
  //                   },
  //                 ),
  //               );
  //             },
  //           ),
  //
  //           // FAB (create)
  //           Positioned(
  //             right: 16,
  //             bottom: 16,
  //             child: FloatingActionButton.extended(
  //               onPressed: () async {
  //                 final token = context.read<AuthProvider>().token;
  //                 if (token == null) {
  //                   ScaffoldMessenger.of(context).showSnackBar(
  //                     const SnackBar(content: Text('Session expired. Please login again.')),
  //                   );
  //                   return;
  //                 }
  //                 final input = await _openAssignForm(context, token: token);
  //                 if (input != null) {
  //                   final ok = await context.read<ShiftAssignProvider>().create(token, input);
  //                   final msg = ok
  //                       ? 'Assigned'
  //                       : (context.read<ShiftAssignProvider>().error ?? 'Failed');
  //                   // ignore: use_build_context_synchronously
  //                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  //                 }
  //               },
  //               icon: const Icon(Icons.add),
  //               label: const Text('Assign'),
  //             ),
  //           ),
  //         ],
  //       ),
  //   ];
  //
  //   return DefaultTabController(
  //     key: ValueKey(tabs.length), // rebuild when tab count changes
  //     length: tabs.length,
  //     child: Scaffold(
  //       appBar: AppBar(
  //         automaticallyImplyLeading: false,
  //         title: null, // <- remove the title
  //         // Show TabBar only if there are 2 tabs
  //         bottom: tabs.length > 1
  //             ? TabBar(
  //           tabs: tabs,
  //           isScrollable: false,
  //           indicatorWeight: 3,
  //         )
  //             : null,
  //         elevation: 0,
  //       ),
  //       // If only one tab, render its view directly; otherwise use TabBarView
  //       body: tabs.length > 1 ? TabBarView(children: views) : views.first,
  //     ),
  //   );
  //
  // }

  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final hasAssignShiftView = context.select<AuthProvider, bool>((auth) {
      final perms = auth.user?.permissions ?? const <String>[];
      if (perms.contains('all')) return true;
      return perms.contains('assignshift.view');
    });
    print("hasAssignShiftView $hasAssignShiftView");
    final tabCount = hasAssignShiftView ? 2 : 1;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            tabs: [
              if (hasAssignShiftView) const Tab(text: 'My Duty'),
              if (hasAssignShiftView) const Tab(text: 'All Shifts'),
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
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              tileColor: Colors.grey.shade50,
                              leading: const Icon(Icons.assignment_turned_in_outlined),
                              title: Text(
                                '${s.stationName ?? s.station?.name ?? '-'} • Gate ${s.gateName ?? s.gates?.name ?? '-'}',
                              ),
                              subtitle: Text(
                                'User: ${s.assignedUserName}  |  Shift: ${s.shiftName}\nDate: ${_fmtDate(s.assignedDate)}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (s.isCompleted == 1) return; // block actions if completed
                                  final t = context.read<AuthProvider>().token;
                                  if (t == null) return;

                                  if (v == 'edit') {
                                    final input = await _openAssignForm(context, initial: s, token: t);
                                    if (input != null) {
                                      final ok = await prov.update(t, s.id, input);
                                      _toast(context, ok ? 'Updated' : prov.error ?? 'Update failed');
                                    }
                                  } else if (v == 'delete') {
                                    final okConfirm = await _confirmDelete(context);
                                    if (okConfirm == true) {
                                      final ok = await prov.remove(t, s.id);
                                      _toast(context, ok ? 'Deleted' : prov.error ?? 'Delete failed');
                                    }
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    enabled: s.isCompleted != 1,
                                    child: Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: s.isCompleted == 1 ? Colors.grey : Colors.black,
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    enabled: s.isCompleted != 1,
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: s.isCompleted == 1 ? Colors.grey : Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  // FAB (create)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.extended(
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
                      icon: const Icon(Icons.add),
                      label: const Text('Assign'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
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
  final _userCtrl = TextEditingController();
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
      _userCtrl.text = i.userId.toString();
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
    _userCtrl.dispose();
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
                  // final uid = int.tryParse(_userCtrl.text);
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