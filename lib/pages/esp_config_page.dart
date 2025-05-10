import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:ai_device_manager/pages/assistant_page.dart';
import 'package:ai_device_manager/pages/device_config_page.dart';
import 'package:ai_device_manager/device.dart';
import 'package:ai_device_manager/widgets/latest_received_image.dart';
import 'package:ai_device_manager/l10n/app_localizations.dart';
import 'dart:io' show Platform;

class ESPConfigPage extends StatefulWidget {
  final String deviceId;
  final String userId;

  const ESPConfigPage({
    Key? key,
    required this.deviceId,
    required this.userId,
  }) : super(key: key);

  @override
  State<ESPConfigPage> createState() => _ESPConfigPageState();
}

class _ESPConfigPageState extends State<ESPConfigPage> {
  // Firebase instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Bluetooth state
  List<BluetoothDevice> _foundDevices = [];
  BluetoothDevice? _selectedDevice;
  BluetoothCharacteristic? _wifiCharacteristic;
  bool _isScanning = false;
  bool _showDeviceList = true;
  bool _isLoading = true;

  // Camera settings state
  int _hours = 0;
  int _minutes = 1;
  int _seconds = 0;
  bool _motionTriggered = false;
  bool _saveImages = true;
  String? _savedCameraId;

  // Constants
  static const String _targetCharacteristicUuid = "87654321-4321-4321-4321-abcdefabcdef";
  static const Duration _scanDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _disconnectDevice();
    super.dispose();
  }

  // Initialization methods
  Future<void> _initialize() async {
    await _loadSettings();
    if (_savedCameraId != null) {
      setState(() => _showDeviceList = false);
    } else {
      await _checkBluetoothPermissions();
    }
    setState(() => _isLoading = false);
  }

  Future<bool> _isInitialSetup() async {
    final doc = await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('devices')
        .doc(widget.deviceId)
        .get();

    if (!doc.exists) return true;

    final data = doc.data()!;
    // Check if last_conversation_summary exists and is not empty
    final hasConversationHistory = data.containsKey('last_conversation_summary') && 
                                 data['last_conversation_summary'] != null &&
                                 data['last_conversation_summary'].toString().isNotEmpty;
    
    return !hasConversationHistory;
}

  Future<void> _navigateNext(BuildContext context) async {
    bool isInitial = await _isInitialSetup();
    
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => isInitial
            ? AssistantPage(
                userId: widget.userId,
                deviceId: widget.deviceId,
              )
            : DeviceConfigPage(
                device: Device(id: widget.deviceId, name: ''),
                userId: widget.userId,
              ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('devices')
          .doc(widget.deviceId)
          .get();

      if (!doc.exists) return;

      final data = doc.data()!;
      setState(() {
        _hours = data['captureIntervalHours'] ?? 0;
        _minutes = data['captureIntervalMinutes'] ?? 1;
        _seconds = data['captureIntervalSeconds'] ?? 0;
        _motionTriggered = data['motionTriggered'] ?? false;
        _saveImages = data['saveImages'] ?? true;
        _savedCameraId = data['connectedCameraId'];
        _showDeviceList = data['connectedCameraId'] == null;
      });
    } catch (e) {
      _showError('Error loading settings: $e');
    }
  }

  // Permission handling
  Future<void> _checkBluetoothPermissions() async {
    try {
      bool isBtEnabled = await FlutterBluePlus.isOn;
      
      // Only check location for Android
      bool isLocationEnabled = Platform.isAndroid 
          ? await Permission.location.serviceStatus.isEnabled 
          : true;  // Skip location check for iOS

      if (!isBtEnabled || (Platform.isAndroid && !isLocationEnabled)) {
        if (!mounted) return; 
        _showServicesDialog(!isBtEnabled, Platform.isAndroid && !isLocationEnabled);
        return;
      }

      // Request only the permissions needed for this platform
      List<Permission> permissionsToRequest = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ];
      
      // Only add location permission for Android
      if (Platform.isAndroid) {
        permissionsToRequest.add(Permission.location);
      }
      
      Map<Permission, PermissionStatus> statuses = await permissionsToRequest.request();

      if (statuses.values.every((status) => status.isGranted)) {
        _startScanning();
      } else {
        _showPermissionDialog();
      }
    } catch (e) {
      _showError('Permission check failed: $e');
    }
  }



  void _showServicesDialog(bool needsBluetooth, bool needsLocation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.permissionsRequired),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.toContinuePleaseEnable),
            const SizedBox(height: 8),
            if (needsBluetooth)
              const Row(
                children: [
                  Icon(Icons.bluetooth, size: 20),
                  SizedBox(width: 8),
                  Text('Bluetooth'),
                ],
              ),
            if (needsLocation && Platform.isAndroid)  // Only show location for Android
              const Row(
                children: [
                  Icon(Icons.location_on, size: 20),
                  SizedBox(width: 8),
                  Text('GPS'),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (needsBluetooth) {
                await FlutterBluePlus.turnOn();
              }
              if (needsLocation && Platform.isAndroid) {  // Only handle location for Android
                await openAppSettings();
              }
              // Recheck after settings change
              await _checkBluetoothPermissions();
            },
            child: Text(context.l10n.openSettings),
          ),
        ],
      ),
    );
  }


  Future<void> _showWiFiCredentialsDialog(String currentSSID) async {
    final TextEditingController ssidController = TextEditingController(text: currentSSID);
    final TextEditingController passwordController = TextEditingController();
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('WiFi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ssidController,
                decoration: InputDecoration(
                  labelText: context.l10n.espWifiSSID,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: context.l10n.espWifiPassword,
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                if (ssidController.text.isEmpty || passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.pleaseFillInAllFields)),
                  );
                  return;
                }
                
                Navigator.pop(context);
                await _sendWiFiCredentials(
                  ssidController.text,
                  passwordController.text,
                );
              },
              child: Text(context.l10n.connect),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendWiFiCredentials(String ssid, String password) async {
    if (_wifiCharacteristic == null) {
      _showError('Device not properly connected');
      return;
    }

    try {
      // Format: userID,deviceID,ssid,password
      final String credentials = '${widget.userId},${widget.deviceId},$ssid,$password';
      
      await _wifiCharacteristic!.write(credentials.codeUnits);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WiFi credentials sent to device')),
      );
      
    } catch (e) {
      _showError('Failed to send WiFi credentials: $e');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.permissionsRequired),
        content: Text(Platform.isAndroid 
          ? context.l10n.permissionsBluetoothLocationMessage 
          : 'This app needs Bluetooth permissions to find and connect to cameras.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.pleaseFillInAllFields)
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              // Recheck after settings change
              await _checkBluetoothPermissions();
            },
            child: Text(context.l10n.openSettings)
          ),
        ],
      ),
    );
  }

  // Bluetooth scanning and connection
  Future<void> _startScanning() async {
    setState(() {
      _foundDevices.clear();
      _isScanning = true;
    });

    try {
      FlutterBluePlus.startScan(timeout: _scanDuration);

      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.name.startsWith('Camera Device') && 
              !_foundDevices.contains(result.device)) {
            setState(() => _foundDevices.add(result.device));
          }
        }
      });

      await Future.delayed(_scanDuration);
      await FlutterBluePlus.stopScan();
    } catch (e) {
      _showError('Error scanning for devices: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }


  Future<void> _fetchDeviceName(BluetoothDevice device) async {
    try {
      await device.connect();
      await Future.delayed(const Duration(seconds: 1));  // Give time for name retrieval
      await device.disconnect();

      // Force UI update with the retrieved name
      setState(() {});
    } catch (e) {
      print('Failed to fetch device name: $e');
    }
  }



  Future<void> _connectToDevice(BluetoothDevice device) async {
  try {
    setState(() => _isLoading = true);
    
    // Connect to the device
    await device.connect();
    setState(() => _selectedDevice = device);

    // Discover services
    List<BluetoothService> services = await device.discoverServices();
    
    // Find our target characteristic
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == _targetCharacteristicUuid) {
          _wifiCharacteristic = characteristic;
          
          // Get current WiFi SSID
          final networkInfo = NetworkInfo();
          final ssid = await networkInfo.getWifiName(); // Returns with quotes, need to clean
          final cleanSSID = ssid?.replaceAll('"', '') ?? '';
          
          // Show WiFi credentials dialog
          if (mounted) {
            await _showWiFiCredentialsDialog(cleanSSID);
          }
          
          break;
        }
      }
    }

    setState(() {
      _showDeviceList = false;
      _savedCameraId = device.id.toString();
    });
    
  } catch (e) {
    _showError('Failed to connect: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}

  Future<void> _disconnectDevice() async {
    if (_selectedDevice != null) {
      try {
        await _selectedDevice!.disconnect();
        _selectedDevice = null;
        _wifiCharacteristic = null;
        _savedCameraId = null;
      } catch (e) {
        _showError('Error disconnecting: $e');
      }
    }
  }

  // Settings management
  Future<void> _saveAndExit() async {
    setState(() => _isLoading = true);
    try {
      await _updateFirestore({
        'captureIntervalHours': _hours,
        'captureIntervalMinutes': _minutes,
        'captureIntervalSeconds': _seconds,
        'motionTriggered': _motionTriggered,
        'saveImages': _saveImages,
        'connectedCameraId': _savedCameraId,
      });
      
      if (mounted) {
        await _navigateNext(context);
      }
    } catch (e) {
      _showError('Error saving settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateFirestore(Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('devices')
        .doc(widget.deviceId)
        .update(data);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }

  // UI Components
  Widget _buildNumberPicker(String label, int value, Function(int) onChanged, {int max = 59}) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        SizedBox(
          height: 150,
          child: ListWheelScrollView(
            itemExtent: 40,
            useMagnifier: true,
            magnification: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            controller: FixedExtentScrollController(initialItem: value),
            children: List.generate(
              max + 1,
              (index) => Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedCamera() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Connected camera card
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                LatestReceivedImage(
                  userId: widget.userId,
                  deviceId: widget.deviceId,
                  size: 80,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.connectedCamera,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(_savedCameraId ?? "Unknown ID"),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await _disconnectDevice();
                    setState(() => _showDeviceList = true);
                    _startScanning();
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(context.l10n.replace),
                ),
              ],
            ),
          ),
        ),

        // Camera settings
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.captureInterval,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildNumberPicker(
                      context.l10n.hours,
                      _hours,
                      (value) => setState(() => _hours = value),
                      max: 23,
                    ),
                  ),
                  Expanded(
                    child: _buildNumberPicker(
                      context.l10n.minutes,
                      _minutes,
                      (value) => setState(() => _minutes = value),
                    ),
                  ),
                  Expanded(
                    child: _buildNumberPicker(
                      context.l10n.seconds,
                      _seconds,
                      (value) => setState(() => _seconds = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(context.l10n.motionTriggered),
                      subtitle: Text(context.l10n.motionTriggeredExplanation),
                      value: _motionTriggered,
                      onChanged: (value) => setState(() => _motionTriggered = value),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(context.l10n.saveImages),
                      subtitle: Text(context.l10n.saveImagesExplanation),
                      value: _saveImages,
                      onChanged: (value) => setState(() => _saveImages = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveAndExit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Text(context.l10n.espSaveSettings),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceList() {
    return Column(
      children: [
        if (_isScanning)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _foundDevices.length,
          itemBuilder: (context, index) {
            final device = _foundDevices[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(device.name),
                subtitle: Text(device.id.toString()),
                trailing: ElevatedButton(
                  onPressed: () => _connectToDevice(device),
                  child: Text(context.l10n.connect),
                ),
              ),
            );
          },
        ),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cameraSetup),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Show skip button only during initial setup and when camera isn't configured
            if (_showDeviceList)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(context.l10n.noCameraConnected,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(context.l10n.espSetupCameraLaterExplanation,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _navigateNext(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            context.l10n.espSetupCameraLater,
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Rest of the content
            _showDeviceList ? _buildDeviceList() : _buildConnectedCamera(),
          ],
        ),
      ),
      floatingActionButton: _showDeviceList ? FloatingActionButton(
        onPressed: () async {
          await _checkBluetoothPermissions(); // Now checks Bluetooth/Location before scanning
        },
        child: const Icon(Icons.refresh),
      ) : null,
    );
  }
}
