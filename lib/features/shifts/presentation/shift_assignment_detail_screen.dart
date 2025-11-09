import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/assign_shift_models.dart';
import '../providers/shift_assign_provider.dart';

class ShiftAssignmentDetailScreen extends StatefulWidget {
  final int assignmentId;
  final String token;

  const ShiftAssignmentDetailScreen(
      {super.key, required this.assignmentId, required this.token});

  @override
  State<ShiftAssignmentDetailScreen> createState() =>
      _ShiftAssignmentDetailScreenState();
}

class _ShiftAssignmentDetailScreenState
    extends State<ShiftAssignmentDetailScreen> {
  static const Color _brand = Color(0xFFA7D222);
  late Future<AssignShiftDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AssignShiftDetail> _load() {
    final provider = context.read<ShiftAssignProvider>();
    return provider.fetchDetail(widget.token, widget.assignmentId);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Assignment'),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<AssignShiftDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message:
                  snapshot.error?.toString() ?? 'Failed to load shift details.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return _ErrorState(
              message: 'Missing shift detail data.',
              onRetry: _refresh,
            );
          }

          final detail = snapshot.data!;

          return RefreshIndicator(
            color: _brand,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _ShiftInfoCard(detail: detail),
                if (detail.assignDevices.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AssignedDevicesCard(detail: detail),
                ],
                const SizedBox(height: 16),
                _AttendanceInfoCard(detail: detail),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShiftInfoCard extends StatefulWidget {
  final AssignShiftDetail detail;
  const _ShiftInfoCard({required this.detail});

  @override
  State<_ShiftInfoCard> createState() => _ShiftInfoCardState();
}

class _ShiftInfoCardState extends State<_ShiftInfoCard> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = widget.detail;
    final completionLabel = _completionLabel(detail);
    final completionColor = _completionColor(detail);

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
                _ProfileAvatar(url: detail.userProfileImageUrl, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        detail.userName ?? 'User',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Name: ${detail.userName ?? '-'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assigned: ${detail.assignedDate ?? '-'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Phone: ${detail.userPhone ?? '-'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _statusChip(completionLabel, completionColor),
                          if (detail.attendanceStatus != null &&
                              detail.attendanceStatus!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _statusChip(
                              detail.attendanceStatus!,
                              _attendanceColor(detail.attendanceStatus!),
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
            if (_showDetails) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.location_on,
                label: 'Station',
                value: detail.stationName ?? '-',
              ),
              const SizedBox(height: 6),
              _DetailRow(
                icon: Icons.door_front_door,
                label: 'Access Point',
                value: detail.gateName ?? '-',
              ),
              const SizedBox(height: 6),
              _DetailRow(
                icon: Icons.person_outline,
                label: 'Assigned By',
                value: detail.assignedByUserName ?? '-',
              ),
              const SizedBox(height: 6),
              _DetailRow(
                icon: Icons.devices_other,
                label: 'Devices Assigned',
                value: detail.assignDevicesCount != null
                    ? detail.assignDevicesCount.toString()
                    : '-',
              ),
              if ((detail.remarks ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                _DetailRow(
                  icon: Icons.note,
                  label: 'Remarks',
                  value: detail.remarks!,
                  maxLines: 3,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _completionLabel(AssignShiftDetail detail) {
    if (detail.isCompleted == 1) return 'Completed';
    if (detail.hasAttendance == true) return 'On Job';
    if (detail.isCompleted == 0) return 'Pending';
    return '-';
  }

  Color _completionColor(AssignShiftDetail detail) {
    if (detail.isCompleted == 1) return Colors.green;
    if (detail.hasAttendance == true && detail.isCompleted == 0) {
      return Colors.blue;
    }
    if (detail.isCompleted == 0) return Colors.orange;
    return Colors.grey;
  }

  Color _attendanceColor(String status) {
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
        return Colors.blueGrey;
    }
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _AttendanceInfoCard extends StatefulWidget {
  final AssignShiftDetail detail;
  const _AttendanceInfoCard({required this.detail});

  @override
  State<_AttendanceInfoCard> createState() => _AttendanceInfoCardState();
}

class _AttendanceInfoCardState extends State<_AttendanceInfoCard> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = widget.detail;
    final hasAttendance = detail.hasAttendance == true;
    final statusText =
        hasAttendance ? (detail.attendanceStatus ?? 'On Duty') : 'Not Marked';
    final statusColor = hasAttendance ? _statusColor(statusText) : Colors.grey;
    final checkInMarked =
        detail.checkInTime != null && detail.checkInTime!.isNotEmpty;
    final checkOutMarked =
        detail.checkOutTime != null && detail.checkOutTime!.isNotEmpty;

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
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withOpacity(0.12),
                  child: Icon(Icons.badge, color: statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Attendance',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasAttendance ? 'Marked' : 'Pending',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
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
            if (_showDetails) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _checkSection(
                title: 'Check-in',
                icon: Icons.login,
                accent: Colors.green,
                statusLabel: checkInMarked ? 'Marked' : 'Pending',
                statusColor: checkInMarked ? Colors.green : Colors.orange,
                time: detail.checkInTime,
                forceMark: _formatBool(detail.checkInForceMark),
                latitude: detail.checkInLatitude,
                longitude: detail.checkInLongitude,
                imageUrl: detail.checkInImageUrl,
              ),
              const SizedBox(height: 10),
              _checkSection(
                title: 'Check-out',
                icon: Icons.logout,
                accent: Colors.indigo,
                statusLabel: checkOutMarked ? 'Marked' : 'Pending',
                statusColor: checkOutMarked ? Colors.indigo : Colors.orange,
                time: detail.checkOutTime,
                forceMark: _formatBool(detail.checkOutForceMark),
                latitude: detail.checkOutLatitude,
                longitude: detail.checkOutLongitude,
                imageUrl: detail.checkOutImageUrl,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _checkSection({
    required String title,
    required IconData icon,
    required Color accent,
    required String statusLabel,
    required Color statusColor,
    required String? time,
    required String forceMark,
    required String? latitude,
    required String? longitude,
    required String? imageUrl,
  }) {
    final theme = Theme.of(context);
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(icon: Icons.access_time, label: 'Time', value: time ?? '-'),
                    const SizedBox(height: 6),
                    _DetailRow(icon: Icons.shield, label: 'Force Mark', value: forceMark),
                    const SizedBox(height: 6),
                    _DetailRow(
                      icon: Icons.my_location,
                      label: 'Latitude',
                      value: latitude ?? '-',
                    ),
                    const SizedBox(height: 6),
                    _DetailRow(
                      icon: Icons.my_location_outlined,
                      label: 'Longitude',
                      value: longitude ?? '-',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('present') || lower.contains('on')) return Colors.green;
    if (lower.contains('absent') || lower.contains('miss')) return Colors.red;
    if (lower.contains('late')) return Colors.orange;
    return Colors.blueGrey;
  }

  String _formatBool(bool? value) {
    if (value == null) return '-';
    return value ? 'Yes' : 'No';
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? url;
  final double size;

  const _ProfileAvatar({this.url, this.size = 40});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(url!),
        backgroundColor: Colors.transparent,
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFA7D222).withOpacity(0.3),
      child: Icon(Icons.person, size: size * 0.6, color: Colors.grey[700]),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String title;
  const _ImagePlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported, color: Colors.grey),
          const SizedBox(height: 6),
          Text(
            'No $title Image',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _AssignedDevicesCard extends StatefulWidget {
  final AssignShiftDetail detail;
  const _AssignedDevicesCard({required this.detail});

  @override
  State<_AssignedDevicesCard> createState() => _AssignedDevicesCardState();
}

class _AssignedDevicesCardState extends State<_AssignedDevicesCard> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices = widget.detail.assignDevices;

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
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFA7D222).withOpacity(0.12),
                  child: const Icon(Icons.devices_other, color: Color(0xFFA7D222)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Assigned Devices',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${devices.length} device${devices.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          fontSize: 11,
                        ),
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
            if (_showDetails) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...devices.asMap().entries.map((entry) {
                final index = entry.key;
                final device = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                      icon: Icons.devices_other,
                      label: 'Device',
                      value: device.deviceName ?? '-',
                    ),
                    const SizedBox(height: 6),
                    _DetailRow(
                      icon: Icons.confirmation_number,
                      label: 'Serial Number',
                      value: device.deviceSerialNumber ?? '-',
                    ),
                    const SizedBox(height: 6),
                    _DetailRow(
                      icon: Icons.qr_code_2,
                      label: 'Model Number',
                      value: device.deviceModelNumber ?? '-',
                    ),
                    const SizedBox(height: 6),
                    _DetailRow(
                      icon: Icons.info_outline,
                      label: 'Status',
                      value: _formatDeviceStatus(device.deviceStatus),
                    ),
                    if (index != devices.length - 1) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDeviceStatus(String? status) {
    switch (status) {
      case '1':
        return 'Active';
      case '0':
        return 'Inactive';
      default:
        return status ?? '-';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  const _DetailRow({
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

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA7D222),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
