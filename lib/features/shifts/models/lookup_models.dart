class ShiftLite {
  final int id;
  final String name;
  final String? startTime;
  final String? endTime;
  final int? isNightShift;

  ShiftLite({required this.id, required this.name, this.startTime, this.endTime, this.isNightShift});

  factory ShiftLite.fromJson(Map<String, dynamic> j) => ShiftLite(
    id: j['id'] as int,
    name: j['name'] as String,
    startTime: j['start_time'] as String?,
    endTime: j['end_time'] as String?,
    isNightShift: j['is_night_shift'] as int?,
  );
}

class StationLite {
  final int id;
  final String name;
  final String? latitude;
  final String? longitude;

  StationLite({required this.id, required this.name, this.latitude, this.longitude});

  factory StationLite.fromJson(Map<String, dynamic> j) => StationLite(
    id: j['id'] as int,
    name: j['name'] as String,
    latitude: j['latitude'] as String?,
    longitude: j['longitude'] as String?,
  );
}

class GateLite {
  final int id;
  final String name;
  final String? type;
  final int stationId;

  GateLite({required this.id, required this.name, required this.stationId, this.type});

  factory GateLite.fromJson(Map<String, dynamic> j, {required int stationId}) => GateLite(
    id: j['id'] as int,
    name: j['name'] as String,
    stationId: stationId,
    type: j['type'] as String?,
  );
}
