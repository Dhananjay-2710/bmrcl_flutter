class Station {
  final int id;
  final String name;
  final String shortName;
  final String code;
  final double latitude;
  final double longitude;

  Station({
    required this.id,
    required this.name,
    required this.shortName,
    required this.code,
    required this.latitude,
    required this.longitude,
  });

  factory Station.fromJson(Map<String, dynamic> j) => Station(
    id: (j['id'] as num).toInt(),
    name: j['name']?.toString() ?? '',
    shortName: j['short_name']?.toString() ?? '',
    code: j['code']?.toString() ?? '',
    latitude: double.tryParse(j['latitude']?.toString() ?? '') ?? 0.0,
    longitude: double.tryParse(j['longitude']?.toString() ?? '') ?? 0.0,
  );
}
