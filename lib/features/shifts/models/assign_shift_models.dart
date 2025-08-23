class AssignShift {
  final int id;
  final int userId;
  final int shiftId;
  final int stationId;
  final int gateId;
  final DateTime assignedDate;
  final int? isCompleted; // 0/1
  final bool? isActive;

  final String? assignedByUserName;
  final String? stationName;
  final String? gateName;
  final String? shiftName;
  final String? assignedUserName;
  final int? assignDevicesCount;

  final AssignUserSimple? assignedBy;
  final StationSimple? station;
  final GateSimple? gates;

  AssignShift({
    required this.id,
    required this.userId,
    required this.shiftId,
    required this.stationId,
    required this.gateId,
    required this.assignedDate,
    this.isCompleted,
    this.isActive,
    this.assignedByUserName,
    this.stationName,
    this.gateName,
    this.shiftName,
    this.assignedUserName,
    this.assignDevicesCount,
    this.assignedBy,
    this.station,
    this.gates,
  });

  factory AssignShift.fromJson(Map<String, dynamic> j) {
    return AssignShift(
      id: j['id'] as int,
      userId: j['user_id'] as int,
      shiftId: j['shift_id'] as int,
      stationId: j['station_id'] as int,
      gateId: j['gate_id'] as int,
      assignedDate: _parseDate(j['assigned_date']),
      isCompleted: j['is_completed'] is int ? j['is_completed'] as int : null,
      isActive: j['is_active'] as bool?,
      assignedByUserName: j['assigned_by_user_name'] as String?,
      stationName: j['station_name'] as String?,
      gateName: j['gate_name'] as String?,
      assignDevicesCount: j['assign_devices_count'] as int?,
      assignedBy: j['assigned_by'] is Map ? AssignUserSimple.fromJson(j['assigned_by']) : null,
      station: j['station'] is Map ? StationSimple.fromJson(j['station']) : null,
      gates: j['gates'] is Map ? GateSimple.fromJson(j['gates']) : null,
      shiftName: j['shift_name'] as String?,
      assignedUserName: j['user_name'] as String?,
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    final s = v.toString();
    // handles "YYYY-MM-DD" or "YYYY/MM/DD"
    final norm = s.contains('/') ? s.replaceAll('/', '-') : s;
    return DateTime.parse(norm);
  }
}

class AssignUserSimple {
  final int id;
  final String name;
  final String? profileImage;
  final String email;

  AssignUserSimple({required this.id, required this.name, this.profileImage, required this.email});
  factory AssignUserSimple.fromJson(Map<String, dynamic> j) => AssignUserSimple(
    id: j['id'] as int,
    name: j['name'] as String,
    profileImage: j['profile_image'] as String?,
    email: j['email'] as String,
  );
}

class StationSimple {
  final int id;
  final String name;
  final String? latitude;
  final String? longitude;

  StationSimple({required this.id, required this.name, this.latitude, this.longitude});
  factory StationSimple.fromJson(Map<String, dynamic> j) => StationSimple(
    id: j['id'] as int,
    name: j['name'] as String,
    latitude: j['latitude'] as String?,
    longitude: j['longitude'] as String?,
  );
}

class GateSimple {
  final int id;
  final String name;
  final String? type;
  GateSimple({required this.id, required this.name, this.type});
  factory GateSimple.fromJson(Map<String, dynamic> j) => GateSimple(
    id: j['id'] as int,
    name: j['name'] as String,
    type: j['type'] as String?,
  );
}

/// Request payload for create/update
class AssignShiftInput {
  final DateTime assignedDate;
  final int userId;
  final int shiftId;
  final int stationId;
  final int gateId;

  AssignShiftInput({
    required this.assignedDate,
    required this.userId,
    required this.shiftId,
    required this.stationId,
    required this.gateId,
  });

  Map<String, dynamic> toJson() => {
    // API expects "YYYY/MM/DD"
    'assigned_date': _fmt(assignedDate),
    'user_id': userId,
    'shift_id': shiftId,
    'station_id': stationId,
    'gate_id': gateId,
  };

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y/$m/$day';
  }
}
