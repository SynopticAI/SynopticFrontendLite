class Device {
  final String id;
  final String name;
  String imageUrl;  // Storage path for device icon
  String? taskDescription;
  String status;
  String inferenceMode; // New: point, boundingBox, counting, classification, VGA
  String? groupId; // New: for organizing devices in groups
  String promptTemplate; // New: template for Moondream inference
  double setupStage; // Simplified: now just 0-2 instead of 0-5
  
  // Camera settings (maintained from original)
  String? connectedCameraId;
  int captureIntervalHours;
  int captureIntervalMinutes;
  int captureIntervalSeconds;
  bool motionTriggered;
  bool saveImages;

  // WiFi and connectivity
  int? wifiSignalStrength; // RSSI value in dBm
  String? lastHeartbeat; // Timestamp in milliseconds
  
  // NEW: Per-device notification settings
  List<String> enabledFCMTokens; // FCM tokens that have opted in for this device's notifications

  Device({
    required this.id,
    required this.name,
    String? imageUrl,
    this.taskDescription,
    this.status = 'Not Configured',
    this.inferenceMode = 'Detect',
    this.groupId,
    this.promptTemplate = '',
    this.connectedCameraId,
    this.captureIntervalHours = 0,
    this.captureIntervalMinutes = 1,
    this.captureIntervalSeconds = 0,
    this.motionTriggered = false,
    this.saveImages = true,
    this.setupStage = 0, // Default to first stage (0 = not started)
    this.wifiSignalStrength,
    this.lastHeartbeat,
    List<String>? enabledFCMTokens, // NEW
  }) : imageUrl = imageUrl ?? 'users/$id/devices/$id/icon.png',
       enabledFCMTokens = enabledFCMTokens ?? []; // Default to empty list

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'taskDescription': taskDescription,
      'status': status,
      'inferenceMode': inferenceMode,
      'groupId': groupId,
      'promptTemplate': promptTemplate,
      'connectedCameraId': connectedCameraId,
      'captureIntervalHours': captureIntervalHours,
      'captureIntervalMinutes': captureIntervalMinutes,
      'captureIntervalSeconds': captureIntervalSeconds,
      'motionTriggered': motionTriggered,
      'saveImages': saveImages,
      'setupStage': setupStage,
      'wifi_signal_strength': wifiSignalStrength,
      'last_heartbeat': lastHeartbeat,
      'enabledFCMTokens': enabledFCMTokens, // NEW
    };
  }

  static Device fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'],
      name: map['name'],
      imageUrl: map['imageUrl'],
      taskDescription: map['taskDescription'],
      status: map['status'] ?? 'Not Configured',
      inferenceMode: map['inferenceMode'] ?? 'Detect',
      groupId: map['groupId'],
      promptTemplate: map['promptTemplate'] ?? '',
      connectedCameraId: map['connectedCameraId'],
      captureIntervalHours: map['captureIntervalHours'] ?? 0,
      captureIntervalMinutes: map['captureIntervalMinutes'] ?? 1,
      captureIntervalSeconds: map['captureIntervalSeconds'] ?? 0,
      motionTriggered: map['motionTriggered'] ?? false,
      saveImages: map['saveImages'] ?? true,
      setupStage: (map['setupStage'] ?? 0).toDouble(),
      wifiSignalStrength: map['wifi_signal_strength'] as int?,
      lastHeartbeat: map['last_heartbeat'] as String?,
      enabledFCMTokens: List<String>.from(map['enabledFCMTokens'] ?? []), // NEW
    );
  }
}