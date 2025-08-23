class DeviceModel {
  final int id;
  final String name;
  final String? type;
  final String? deviceImageUrl;
  final String? serialNumber;

  DeviceModel({
    required this.id,
    required this.name,
    this.type,
    this.deviceImageUrl,
    this.serialNumber,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> j) {
    return DeviceModel(
      id: j['id'] ?? 0,
      name: j['name'] ?? '',
      type: j['type'],
      deviceImageUrl: j['device_image_url'] ?? j['device_image'],
      serialNumber: j['serial_number'],
    );
  }

  @override
  String toString() => 'DeviceModel(id:$id, name:$name)';
}
