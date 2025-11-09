class AssignShift {
  final int id;
  final int userId;
  final int shiftId;
  final int stationId;
  final int gateId;
  final DateTime assignedDate;
  final DateTime assignedFromDate;
  final DateTime assignedToDate;
  final int? isCompleted; // 0/1
  final bool? isActive;
  final bool? hasAttendance;
  final String? attendanceStatus;
  final int? attendanceId;

  final String? assignedByUserName;
  final String? stationName;
  final String? gateName;
  final String? shiftName;
  final String? assignedUserName;
  final int? assignDevicesCount;
  final String? userProfileImageUrl;

  final AssignUserSimple? assignedBy;
  final StationSimple? station;
  final GateSimple? gates;
  final ShiftSimple? shift;

  AssignShift({
    required this.id,
    required this.userId,
    required this.shiftId,
    required this.stationId,
    required this.gateId,
    required this.assignedDate,
    required this.assignedFromDate,
    required this.assignedToDate,
    this.isCompleted,
    this.isActive,
    this.hasAttendance,
    this.attendanceStatus,
    this.attendanceId,
    this.assignedByUserName,
    this.stationName,
    this.gateName,
    this.shiftName,
    this.assignedUserName,
    this.assignDevicesCount,
    this.userProfileImageUrl,
    this.assignedBy,
    this.station,
    this.gates,
    this.shift,
  });

  factory AssignShift.fromJson(Map<String, dynamic> j) {
    return AssignShift(
      id: j['id'] as int,
      userId: j['user_id'] as int,
      shiftId: j['shift_id'] as int,
      stationId: j['station_id'] as int,
      gateId: j['gate_id'] as int,
      assignedDate: _parseDate(j['assigned_date']),
      assignedFromDate: _parseDate(j['assigned_date']),
      assignedToDate: _parseDate(j['assigned_date']),
      isCompleted: j['is_completed'] is int ? j['is_completed'] as int : null,
      isActive: j['is_active'] as bool?,
      hasAttendance: j['has_attendance'] as bool?,
      attendanceStatus: j['attendance_status'] as String?,
      attendanceId: j['attendance_id'] as int?,
      assignedByUserName: j['assigned_by_user_name'] as String?,
      stationName: j['station_name'] as String?,
      gateName: j['gate_name'] as String?,
      assignDevicesCount: j['assign_devices_count'] as int?,
      userProfileImageUrl: j['user_profile_image_url'] as String?,
      assignedBy: j['assigned_by'] is Map ? AssignUserSimple.fromJson(j['assigned_by']) : null,
      station: j['station'] is Map ? StationSimple.fromJson(j['station']) : null,
      gates: j['gates'] is Map ? GateSimple.fromJson(j['gates']) : null,
      shift: j['shift'] is Map ? ShiftSimple.fromJson(j['shift']) : null,
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

class ShiftSimple {
  final int id;
  final String name;
  final String? startTime;
  final String? endTime;
  final String? breakStartTime;
  final String? breakEndTime;
  
  ShiftSimple({
    required this.id,
    required this.name,
    this.startTime,
    this.endTime,
    this.breakStartTime,
    this.breakEndTime,
  });
  
  factory ShiftSimple.fromJson(Map<String, dynamic> j) => ShiftSimple(
    id: j['id'] as int,
    name: j['name'] as String,
    startTime: j['start_time'] as String?,
    endTime: j['end_time'] as String?,
    breakStartTime: j['break_start_time'] as String?,
    breakEndTime: j['break_end_time'] as String?,
  );
}

class AssignShiftDetail {
  final int id;
  final int userId;
  final int shiftId;
  final int stationId;
  final int gateId;
  final String? assignedDate;
  final int? assignedByUserId;
  final int? organizationId;
  final int? isCompleted;
  final bool? isActive;
  final String? assignedByUserName;
  final String? stationName;
  final String? gateName;
  final String? shiftName;
  final String? userName;
  final String? userPhone;
  final String? userProfileImageUrl;
  final int? assignDevicesCount;
  final List<AssignShiftDevice> assignDevices;
  final bool? hasAttendance;
  final String? attendanceStatus;
  final int? attendanceId;
  final String? checkInTime;
  final String? checkOutTime;
  final String? checkInLatitude;
  final String? checkInLongitude;
  final String? checkOutLatitude;
  final String? checkOutLongitude;
  final String? checkInImageUrl;
  final String? checkOutImageUrl;
  final bool? checkInForceMark;
  final bool? checkOutForceMark;
  final String? remarks;

  AssignShiftDetail({
    required this.id,
    required this.userId,
    required this.shiftId,
    required this.stationId,
    required this.gateId,
    this.assignedDate,
    this.assignedByUserId,
    this.organizationId,
    this.isCompleted,
    this.isActive,
    this.assignedByUserName,
    this.stationName,
    this.gateName,
    this.shiftName,
    this.userName,
    this.userPhone,
    this.userProfileImageUrl,
    this.assignDevicesCount,
    this.assignDevices = const [],
    this.hasAttendance,
    this.attendanceStatus,
    this.attendanceId,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkInImageUrl,
    this.checkOutImageUrl,
    this.checkInForceMark,
    this.checkOutForceMark,
    this.remarks,
  });

  factory AssignShiftDetail.fromJson(Map<String, dynamic> j) {
    return AssignShiftDetail(
      id: j['id'] as int,
      userId: j['user_id'] as int,
      shiftId: j['shift_id'] as int,
      stationId: j['station_id'] as int,
      gateId: j['gate_id'] as int,
      assignedDate: j['assigned_date']?.toString(),
      assignedByUserId: j['assigned_by_user_id'] as int?,
      organizationId: j['organization_id'] as int?,
      isCompleted: j['is_completed'] is int ? j['is_completed'] as int : int.tryParse(j['is_completed']?.toString() ?? ''),
      isActive: _parseBool(j['is_active']),
      assignedByUserName: j['assigned_by_user_name'] as String?,
      stationName: j['station_name'] as String?,
      gateName: j['gate_name'] as String?,
      shiftName: j['shift_name'] as String?,
      userName: j['user_name'] as String?,
      userPhone: j['user_phone_number'] as String?,
      userProfileImageUrl: j['user_profile_image_url'] as String?,
      assignDevicesCount: j['assign_devices_count'] as int?,
      assignDevices: (j['assign_devices'] is List)
          ? (j['assign_devices'] as List)
              .whereType<Map>()
              .map((e) => AssignShiftDevice.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      hasAttendance: _parseBool(j['has_attendance']),
      attendanceStatus: j['attendance_status'] as String?,
      attendanceId: j['attendance_id'] as int?,
      checkInTime: j['check_in_time']?.toString(),
      checkOutTime: j['check_out_time']?.toString(),
      checkInLatitude: j['check_in_latitude']?.toString(),
      checkInLongitude: j['check_in_longitude']?.toString(),
      checkOutLatitude: j['check_out_latitude']?.toString(),
      checkOutLongitude: j['check_out_longitude']?.toString(),
      checkInImageUrl: j['check_in_image_url'] as String?,
      checkOutImageUrl: j['check_out_image_url'] as String?,
      checkInForceMark: _parseBool(j['check_in_force_mark']),
      checkOutForceMark: _parseBool(j['check_out_force_mark']),
      remarks: j['remarks']?.toString(),
    );
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value != 0;
    final lower = value.toString().toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
    return null;
  }
}

class AssignShiftDevice {
  final int assignDeviceId;
  final int deviceId;
  final String? deviceName;
  final String? deviceSerialNumber;
  final String? deviceModelNumber;
  final String? deviceStatus;

  AssignShiftDevice({
    required this.assignDeviceId,
    required this.deviceId,
    this.deviceName,
    this.deviceSerialNumber,
    this.deviceModelNumber,
    this.deviceStatus,
  });

  factory AssignShiftDevice.fromJson(Map<String, dynamic> json) => AssignShiftDevice(
        assignDeviceId: json['assign_device_id'] as int,
        deviceId: json['device_id'] as int,
        deviceName: json['device_name'] as String?,
        deviceSerialNumber: json['device_serial_number']?.toString(),
        deviceModelNumber: json['device_model_number']?.toString(),
        deviceStatus: json['device_status']?.toString(),
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

class AssignBulkShiftInput {
  final DateTime assignedFromDate;
  final DateTime assignedToDate;
  final int userId;
  final int shiftId;
  final int stationId;
  final int gateId;

  AssignBulkShiftInput({
    required this.assignedFromDate,
    required this.assignedToDate,
    required this.userId,
    required this.shiftId,
    required this.stationId,
    required this.gateId,
  });

  Map<String, dynamic> toJson() => {
    // API expects "YYYY/MM/DD"
    'assigned_from_date': _fmt(assignedFromDate),
    'assigned_to_date': _fmt(assignedToDate),
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