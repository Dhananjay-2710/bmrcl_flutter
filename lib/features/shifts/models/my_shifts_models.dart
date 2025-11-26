class ShiftInfo {
  final int id;
  final String name;
  final String? description;
  final String startTime;
  final String endTime;
  final String? breakStartTime;
  final String? breakEndTime;
  final int isNightShift;
  final int isActive;

  ShiftInfo({
    required this.id,
    required this.name,
    this.description,
    required this.startTime,
    required this.endTime,
    this.breakStartTime,
    this.breakEndTime,
    required this.isNightShift,
    required this.isActive,
  });

  factory ShiftInfo.fromJson(Map<String, dynamic> j) => ShiftInfo(
    id: (j['id'] as num).toInt(),
    name: j['name']?.toString() ?? '',
    description: j['description']?.toString(),
    startTime: j['start_time']?.toString() ?? '',
    endTime: j['end_time']?.toString() ?? '',
    breakStartTime: j['break_start_time']?.toString(),
    breakEndTime: j['break_end_time']?.toString(),
    isNightShift: j['is_night_shift'] == true || j['is_night_shift'] == 1 || j['is_night_shift'] == '1' ? 1 : 0,
    isActive: j['is_active'] == true || j['is_active'] == 1 || j['is_active'] == '1' ? 1 : 0,
  );
}

class StationInfo {
  final int id;
  final String name;
  final String? stationImage;
  final String? shortName;
  final String? code;
  final String? latitude;
  final String? longitude;
  final int isActive;

  StationInfo({
    required this.id,
    required this.name,
    this.stationImage,
    this.shortName,
    this.code,
    this.latitude,
    this.longitude,
    required this.isActive,
  });

  factory StationInfo.fromJson(Map<String, dynamic> j) => StationInfo(
    id: (j['id'] as num).toInt(),
    name: j['name']?.toString() ?? '',
    stationImage: j['station_image']?.toString(),
    shortName: j['short_name']?.toString(),
    code: j['code']?.toString(),
    latitude: j['latitude']?.toString(),
    longitude: j['longitude']?.toString(),
    isActive: (j['is_active'] as num?)?.toInt() ?? 0,
  );
}

class GateInfo {
  final int id;
  final String name;
  final String? gateImage;
  final String? type;
  final int stationId;
  final int organizationId;
  final int status;

  GateInfo({
    required this.id,
    required this.name,
    this.gateImage,
    this.type,
    required this.stationId,
    required this.organizationId,
    required this.status,
  });

  factory GateInfo.fromJson(Map<String, dynamic> j) => GateInfo(
    id: (j['id'] as num).toInt(),
    name: j['name']?.toString() ?? '',
    gateImage: j['gate_image']?.toString(),
    type: j['type']?.toString(),
    stationId: (j['station_id'] as num?)?.toInt() ?? 0,
    organizationId: (j['organization_id'] as num?)?.toInt() ?? 0,
    status: (j['status'] as num?)?.toInt() ?? 0,
  );
}

class ShiftAssignment {
  final int id;
  final int userId;
  final int shiftId;
  final int stationId;
  final int gateId;
  final DateTime assignedDate;
  final int assignedByUserId;
  final int organizationId;
  final int isCompleted;
  final bool isActive;
  final ShiftInfo? shift;
  final StationInfo? station;
  final GateInfo? gates;

  ShiftAssignment({
    required this.id,
    required this.userId,
    required this.shiftId,
    required this.stationId,
    required this.gateId,
    required this.assignedDate,
    required this.assignedByUserId,
    required this.organizationId,
    required this.isCompleted,
    required this.isActive,
    this.shift,
    this.station,
    this.gates,
  });

  factory ShiftAssignment.fromJson(Map<String, dynamic> j) => ShiftAssignment(
    id: (j['id'] as num).toInt(),
    userId: (j['user_id'] as num?)?.toInt() ?? 0,
    shiftId: (j['shift_id'] as num?)?.toInt() ?? 0,
    stationId: (j['station_id'] as num?)?.toInt() ?? 0,
    gateId: (j['gate_id'] as num?)?.toInt() ?? 0,
    assignedDate: DateTime.tryParse(j['assigned_date']?.toString() ?? '') ??
        DateTime(1970),
    assignedByUserId: (j['assigned_by_user_id'] as num?)?.toInt() ?? 0,
    organizationId: (j['organization_id'] as num?)?.toInt() ?? 0,
    isCompleted: (j['is_completed'] as num?)?.toInt() ?? 0,
    isActive: j['is_active'] == true ||
        j['is_active'] == 1 ||
        j['is_active'] == '1',
    shift: j['shift'] is Map<String, dynamic>
        ? ShiftInfo.fromJson(j['shift'])
        : null,
    station: j['station'] is Map<String, dynamic>
        ? StationInfo.fromJson(j['station'])
        : null,
    gates: j['gates'] is Map<String, dynamic>
        ? GateInfo.fromJson(j['gates'])
        : null,
  );
}

class AttendanceRecord {
  final int id;
  final int userId;
  final int userShiftAssignmentId;
  final DateTime date; // yyyy-MM-dd
  final String status;
  final String? checkInTime; // HH:mm:ss (or null)
  final String? checkOutTime; // HH:mm:ss (or null)
  final String? checkInLatitude;
  final String? checkInLongitude;
  final String? checkOutLatitude;
  final String? checkOutLongitude;
  final String? checkInImage;
  final String? checkOutImage;
  final int? checkInForceMark;
  final int? checkOutForceMark;
  final String? remarks;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.userShiftAssignmentId,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkInImage,
    this.checkOutImage,
    this.checkInForceMark,
    this.checkOutForceMark,
    this.remarks,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      /// Return a default "empty" record instead of crashing
      return AttendanceRecord(
        id: 0,
        userId: 0,
        userShiftAssignmentId: 0,
        date: DateTime(1970),
        status: '',
      );
    }

    return AttendanceRecord(
      id: (j['id'] as num?)?.toInt() ?? 0,
      userId: (j['user_id'] as num?)?.toInt() ?? 0,
      userShiftAssignmentId: (j['user_shift_assignment_id'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime(1970),
      status: j['status']?.toString() ?? '',
      checkInTime: j['check_in_time']?.toString(),
      checkOutTime: j['check_out_time']?.toString(),
      checkInLatitude: j['check_in_latitude']?.toString(),
      checkInLongitude: j['check_in_longitude']?.toString(),
      checkOutLatitude: j['check_out_latitude']?.toString(),
      checkOutLongitude: j['check_out_longitude']?.toString(),
      checkInImage: j['check_in_image']?.toString(),
      checkOutImage: j['check_out_image']?.toString(),
      checkInForceMark: (j['check_in_force_mark'] as num?)?.toInt(),
      checkOutForceMark: (j['check_out_force_mark'] as num?)?.toInt(),
      remarks: j['remarks']?.toString(),
    );
  }
}

class AssignedDevice {
  final int assignedDeviceId;
  final String device;
  final String deviceModel;
  final String deviceSerial;
  final String gate;
  final String gateType;
  final String station;

  AssignedDevice({
    required this.assignedDeviceId,
    required this.device,
    required this.deviceModel,
    required this.deviceSerial,
    required this.gate,
    required this.gateType,
    required this.station,
  });

  factory AssignedDevice.fromJson(Map<String, dynamic> j) => AssignedDevice(
    assignedDeviceId: (j['assigned_device_id'] as num).toInt(),
    device: j['device']?.toString() ?? '',
    deviceModel: j['device_model']?.toString() ?? '',
    deviceSerial: j['device_serial']?.toString() ?? '',
    gate: j['gate']?.toString() ?? '',
    gateType: j['gate_type']?.toString() ?? '',
    station: j['station']?.toString() ?? '',
  );
}

class MyShiftsBundle {
  final List<ShiftAssignment> assignments;
  final List<AttendanceRecord> attendance;
  final List<AssignedDevice> devices;

  MyShiftsBundle({
    required this.assignments,
    required this.attendance,
    required this.devices,
  });

  factory MyShiftsBundle.fromJson(Map<String, dynamic> j) {
    final asg = (j['assign_shift'] as List? ?? [])
        .whereType<Map<String, dynamic>>() // filters only Map
        .map((e) => ShiftAssignment.fromJson(e))
        .toList();

    final att = (j['attendance'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AttendanceRecord.fromJson)
        .toList();

    final dev = (j['assigned_device'] as List? ?? [])
        .whereType<Map<String, dynamic>>() // filters only Map
        .map((e) => AssignedDevice.fromJson(e))
        .toList();

    return MyShiftsBundle(assignments: asg, attendance: att, devices: dev);
  }
}
