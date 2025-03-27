class DeviceGroup {
  String id;
  String name;
  List<String> deviceIds;

  DeviceGroup({
    required this.id,
    required this.name,
    List<String>? deviceIds,
  }) : deviceIds = deviceIds ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'deviceIds': deviceIds,
    };
  }

  static DeviceGroup fromMap(Map<String, dynamic> map) {
    return DeviceGroup(
      id: map['id'],
      name: map['name'],
      deviceIds: List<String>.from(map['deviceIds'] ?? []),
    );
  }
}