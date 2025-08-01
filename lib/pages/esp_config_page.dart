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
import 'dart:async';

import 'package:ai_device_manager/l10n/context_extensions.dart';

  // WiFi Network class
  class WifiNetwork {
    final String ssid;
    final int signalStrength;
    final bool isSecured;

    WifiNetwork({
      required this.ssid,
      required this.signalStrength,
      required this.isSecured,
    });
  }
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

enum ConnectionState {
  scanning,
  connecting,
  waitingForCredentials,
  waitingForHeartbeat,
  connected,
  connectionSuccess, // New state for showing success message
  failed
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

  // Connection state management
  ConnectionState _connectionState = ConnectionState.scanning;
  String? _savedCameraId;
  String? _savedDeviceName; // Store ESP32 device name for reconnection
  Timer? _heartbeatTimer;
  StreamSubscription? _heartbeatSubscription;
  
  // WiFi networks
  List<WifiNetwork> _availableNetworks = [];
  bool _isLoadingNetworks = false;
  WifiNetwork? _selectedNetwork;

  // Camera settings state
  int _hours = 0;
  int _minutes = 1;
  int _seconds = 0;
  bool _motionTriggered = false;
  bool _saveImages = true;

  // Constants
  static const String _targetCharacteristicUuid = "87654321-4321-4321-4321-abcdefabcdef";
  static const Duration _scanDuration = Duration(seconds: 5);
  static const Duration _heartbeatTimeout = Duration(seconds: 60); // Wait 60 seconds for heartbeat

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatSubscription?.cancel();
    _disconnectDevice();
    super.dispose();
  }

  // Initialization methods
  Future<void> _initialize() async {
    await _loadSettings();
    _validateLoadedSettings();
    if (_savedCameraId != null) {
      setState(() => _showDeviceList = false);
      _connectionState = ConnectionState.connected;
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
        _savedDeviceName = data['espDeviceName']; // Load saved ESP32 device name
        _showDeviceList = data['connectedCameraId'] == null;
      });
    } catch (e) {
      _showError('Error loading settings: $e');
    }
  }

  // WiFi Network Scanning
  Future<void> _scanWifiNetworks() async {
    setState(() {
      _isLoadingNetworks = true;
      _availableNetworks.clear();
    });

    try {
      // TODO: Implement actual WiFi network scanning
      // This is a placeholder - actual implementation depends on platform capabilities
      // For now, we'll get the current network and add some mock networks
      final networkInfo = NetworkInfo();
      final currentSSID = await networkInfo.getWifiName();
      
      // Mock networks for demonstration
      _availableNetworks = [
        if (currentSSID != null) 
          WifiNetwork(
            ssid: currentSSID.replaceAll('"', ''), 
            signalStrength: -30, 
            isSecured: true
          ),
        WifiNetwork(ssid: "Office_WiFi", signalStrength: -45, isSecured: true),
        WifiNetwork(ssid: "Guest_Network", signalStrength: -60, isSecured: false),
        WifiNetwork(ssid: "Factory_WiFi", signalStrength: -55, isSecured: true),
      ];

      // Sort by signal strength
      _availableNetworks.sort((a, b) => b.signalStrength.compareTo(a.signalStrength));
      
    } catch (e) {
      print('Error scanning WiFi networks: $e');
      // Fallback to manual entry
    } finally {
      setState(() => _isLoadingNetworks = false);
    }
  }

  // Heartbeat monitoring
  void _startHeartbeatMonitoring() {
    print('Starting heartbeat monitoring for device ${widget.deviceId}');
    
    // Listen to heartbeat updates in Firestore
    _heartbeatSubscription = _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('devices')
        .doc(widget.deviceId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      
      final data = snapshot.data()!;
      final lastHeartbeat = data['last_heartbeat'] as String?;
      
      if (lastHeartbeat != null) {
        print('Received heartbeat: $lastHeartbeat');
        _onHeartbeatReceived();
      }
    });

    // Set timeout for heartbeat
    _heartbeatTimer = Timer(_heartbeatTimeout, () {
      if (_connectionState == ConnectionState.waitingForHeartbeat) {
        print('Heartbeat timeout - assuming WiFi credentials failed');
        _onHeartbeatTimeout();
      }
    });
  }

  void _onHeartbeatReceived() {
    print('✅ Heartbeat received - WiFi connection successful');
    _heartbeatTimer?.cancel();
    _heartbeatSubscription?.cancel();
    
    setState(() {
      _connectionState = ConnectionState.connectionSuccess;
      _showDeviceList = false;
    });
    
    // Save the successful connection
    _updateFirestore({
      'connectedCameraId': _selectedDevice?.id.toString(),
      'espDeviceName': _savedDeviceName, // Save ESP32 device name
    });
    
    // Show success message for 3 seconds, then proceed to settings
    Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _connectionState = ConnectionState.connected;
        });
      }
    });
  }

  void _onHeartbeatTimeout() {
    print('❌ Heartbeat timeout - WiFi credentials likely incorrect');
    _heartbeatTimer?.cancel();
    _heartbeatSubscription?.cancel();
    
    setState(() {
      _connectionState = ConnectionState.failed;
    });
    
    // Show reconnection dialog
    _showReconnectionDialog();
  }

  void _showReconnectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Connection Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The device could not connect to WiFi. This usually means:'),
            SizedBox(height: 8),
            Text('• Incorrect WiFi password'),
            Text('• WiFi network is out of range'),
            Text('• Network security settings'),
            SizedBox(height: 16),
            Text('Would you like to try different WiFi credentials?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateNext(context); // Skip WiFi setup
            },
            child: Text('Skip for Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _reconnectToESP32();
            },
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _reconnectToESP32() async {
    if (_savedDeviceName == null) {
      _showError('No saved device name for reconnection');
      return;
    }

    setState(() {
      _connectionState = ConnectionState.connecting;
      _isLoading = true;
    });

    print('Attempting to reconnect to ESP32: $_savedDeviceName');
    
    // Start scanning for the specific device
    await _startScanning();
    
    // Look for the saved device name
    BluetoothDevice? targetDevice;
    for (var device in _foundDevices) {
      if (device.name == _savedDeviceName) {
        targetDevice = device;
        break;
      }
    }

    if (targetDevice != null) {
      print('Found target device: $_savedDeviceName');
      await _connectToDevice(targetDevice);
    } else {
      _showError('Could not find device $_savedDeviceName. Please try scanning again.');
      setState(() {
        _connectionState = ConnectionState.scanning;
        _isLoading = false;
      });
    }
  }

  // Permission handling (existing code with minor updates)
  Future<void> _checkBluetoothPermissions() async {
    try {
      if (Platform.isIOS) {
        _startScanning();
        return;
      }
      
      bool isBtEnabled = await FlutterBluePlus.isOn;
      bool isLocationEnabled = await Permission.location.serviceStatus.isEnabled;
      
      if (!isBtEnabled || !isLocationEnabled) {
        if (!mounted) return;
        _showServicesDialog(!isBtEnabled, !isLocationEnabled);
        return;
      }
      
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
      
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
            if (needsLocation)
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
                if (Platform.isAndroid) {
                  await FlutterBluePlus.turnOn();
                } else {
                  await openAppSettings();
                }
              }
              if (needsLocation) {
                await openAppSettings();
              }
              await Future.delayed(Duration(milliseconds: 500));
              await _checkBluetoothPermissions();
            },
            child: Text(context.l10n.openSettings),
          ),
        ],
      ),
    );
  }

  Future<void> _showWiFiCredentialsDialog() async {
    // First scan for available networks
    await _scanWifiNetworks();
    
    final TextEditingController passwordController = TextEditingController();
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Check if we can enable the Connect button
            bool canConnect = _selectedNetwork != null && 
                            (!_selectedNetwork!.isSecured || passwordController.text.isNotEmpty);
            
            return AlertDialog(
              title: const Text('WiFi Configuration'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select WiFi Network:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    
                    // Network selection
                    if (_isLoadingNetworks)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_availableNetworks.isNotEmpty)
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: _availableNetworks.length,
                          itemBuilder: (context, index) {
                            final network = _availableNetworks[index];
                            final isSelected = _selectedNetwork == network;
                            
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              leading: Icon(
                                network.isSecured ? Icons.wifi_lock : Icons.wifi,
                                color: _getSignalColor(network.signalStrength),
                              ),
                              title: Text(network.ssid),
                              subtitle: Text('${network.signalStrength} dBm'),
                              trailing: _getSignalIcon(network.signalStrength),
                              onTap: () {
                                setDialogState(() {
                                  _selectedNetwork = network;
                                  // Clear password when switching networks
                                  passwordController.clear();
                                });
                              },
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.wifi_off, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No networks found'),
                            TextButton(
                              onPressed: () async {
                                setDialogState(() => _isLoadingNetworks = true);
                                await _scanWifiNetworks();
                                setDialogState(() => _isLoadingNetworks = false);
                              },
                              child: Text('Scan Again'),
                            ),
                          ],
                        ),
                      ),
                    
                    SizedBox(height: 16),
                    
                    // Manual SSID entry option
                    TextButton.icon(
                      icon: Icon(Icons.edit),
                      label: Text('Enter Network Manually'),
                      onPressed: () {
                        // Show manual entry dialog
                        _showManualNetworkDialog(setDialogState, passwordController);
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Password field (only show if network is selected and secured)
                    if (_selectedNetwork != null && _selectedNetwork!.isSecured) ...[
                      TextField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password for ${_selectedNetwork!.ssid}',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                          errorText: _selectedNetwork!.isSecured && passwordController.text.isEmpty 
                              ? 'Password required for secured network' 
                              : null,
                        ),
                        obscureText: true,
                        onChanged: (value) {
                          // Trigger rebuild to update button state
                          setDialogState(() {});
                        },
                      ),
                    ],
                    
                    // Show network selection status
                    if (_selectedNetwork != null) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedNetwork!.isSecured ? Icons.wifi_lock : Icons.wifi,
                              color: Colors.blue,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected: ${_selectedNetwork!.ssid}',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _selectedNetwork!.isSecured ? 'Secured network' : 'Open network',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text('Select WiFi network'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: canConnect ? () async {
                    Navigator.pop(context);
                    await _sendWiFiCredentials(_selectedNetwork!.ssid, passwordController.text);
                  } : null,
                  child: Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _getPasswordForNetwork(String ssid) async {
    final TextEditingController passwordController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Network: $ssid'),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showManualNetworkDialog(StateSetter setDialogState, TextEditingController passwordController) {
    final TextEditingController ssidController = TextEditingController();
    bool isSecured = true; // Default assume secured
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setManualDialogState) => AlertDialog(
          title: Text('Enter Network Manually'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ssidController,
                decoration: InputDecoration(
                  labelText: 'Network Name (SSID)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text('Secured Network'),
                subtitle: Text('Does this network require a password?'),
                value: isSecured,
                onChanged: (value) {
                  setManualDialogState(() {
                    isSecured = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (ssidController.text.isNotEmpty) {
                  setDialogState(() {
                    _selectedNetwork = WifiNetwork(
                      ssid: ssidController.text,
                      signalStrength: -50, // Default
                      isSecured: isSecured,
                    );
                    // Clear password when selecting manual network
                    passwordController.clear();
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Select'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSignalColor(int signalStrength) {
    if (signalStrength >= -50) return Colors.green;
    if (signalStrength >= -70) return Colors.orange;
    return Colors.red;
  }

  Widget _getSignalIcon(int signalStrength) {
    if (signalStrength >= -50) return Icon(Icons.signal_wifi_4_bar, color: Colors.green, size: 20);
    if (signalStrength >= -60) return Icon(Icons.network_wifi_3_bar, color: Colors.orange, size: 20);
    if (signalStrength >= -70) return Icon(Icons.network_wifi_2_bar, color: Colors.orange, size: 20);
    return Icon(Icons.signal_wifi_0_bar, color: Colors.red, size: 20);
  }

  Future<void> _sendWiFiCredentials(String ssid, String password) async {
    if (_wifiCharacteristic == null) {
      _showError('Device not properly connected');
      return;
    }

    // Validate inputs
    if (ssid.isEmpty) {
      _showError('SSID cannot be empty');
      return;
    }

    try {
      // Format: userID,deviceID,ssid,password
      final String credentials = '${widget.userId},${widget.deviceId},$ssid,$password';
      
      await _wifiCharacteristic!.write(credentials.codeUnits);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WiFi credentials sent to device: $ssid')),
      );

      // Start waiting for heartbeat
      setState(() {
        _connectionState = ConnectionState.waitingForHeartbeat;
      });
      
      _startHeartbeatMonitoring();
      
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
          : context.l10n.permissionsBluetoothMessage ?? 'This app needs Bluetooth permissions to find and connect to cameras.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel)
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              await _checkBluetoothPermissions();
            },
            child: Text(context.l10n.openSettings)
          ),
        ],
      ),
    );
  }

  // Bluetooth scanning and connection (updated)
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

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      setState(() => _isLoading = true);
      
      // Connect to the device
      await device.connect();
      setState(() => _selectedDevice = device);

      // Save device name for potential reconnection
      _savedDeviceName = device.name;

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      // Find our target characteristic
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == _targetCharacteristicUuid) {
            _wifiCharacteristic = characteristic;
            
            // Show WiFi credentials dialog with network selection
            if (mounted) {
              await _showWiFiCredentialsDialog();
            }
            
            break;
          }
        }
      }

      // Don't change state here - wait for heartbeat confirmation
      
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

  // Settings management (existing code)
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
        'espDeviceName': _savedDeviceName, // Save ESP32 device name
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

  // Time validation (existing code)
  void _updateTimeWithValidation({int? hours, int? minutes, int? seconds}) {
    int newHours = hours ?? _hours;
    int newMinutes = minutes ?? _minutes;
    int newSeconds = seconds ?? _seconds;
    
    int totalSeconds = (newHours * 3600) + (newMinutes * 60) + newSeconds;
    
    if (totalSeconds < 10) {
      newHours = 0;
      newMinutes = 0;
      newSeconds = 10;
    }
    
    setState(() {
      _hours = newHours;
      _minutes = newMinutes;
      _seconds = newSeconds;
    });
  }

  void _validateLoadedSettings() {
    int totalSeconds = (_hours * 3600) + (_minutes * 60) + _seconds;
    if (totalSeconds < 10) {
      _updateTimeWithValidation();
    }
  }

  // UI Components (existing code with updates)
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
                      if (_savedDeviceName != null)
                        Text('Device: $_savedDeviceName', 
                             style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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

        // Camera settings (existing code)
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
                      (value) => _updateTimeWithValidation(hours: value),
                      max: 23,
                    ),
                  ),
                  Expanded(
                    child: _buildNumberPicker(
                      context.l10n.minutes,
                      _minutes,
                      (value) => _updateTimeWithValidation(minutes: value),
                    ),
                  ),
                  Expanded(
                    child: _buildNumberPicker(
                      context.l10n.seconds,
                      _seconds,
                      (value) => _updateTimeWithValidation(seconds: value),
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

  // Success confirmation screen
  Widget _buildConnectionSuccess() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success checkmark animation
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Camera WiFi Connected!',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Your camera is now connected and will start sending images.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 20),
              // Progress indicator to show it's moving to next step
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  color: Colors.green,
                  backgroundColor: Colors.green.withOpacity(0.2),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Proceeding to camera settings...',
                style: TextStyle(
                  fontSize: 12, 
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Waiting for heartbeat screen
  Widget _buildWaitingForHeartbeat() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Connecting to WiFi...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Please wait while your device connects to the WiFi network.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              LinearProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'This usually takes 10-60 seconds',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  _heartbeatTimer?.cancel();
                  _heartbeatSubscription?.cancel();
                  setState(() {
                    _connectionState = ConnectionState.scanning;
                    _showDeviceList = true;
                  });
                },
                child: Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
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
            // Show different UI based on connection state
            if (_connectionState == ConnectionState.waitingForHeartbeat)
              _buildWaitingForHeartbeat()
            else if (_connectionState == ConnectionState.connectionSuccess)
              _buildConnectionSuccess()
            else if (_connectionState == ConnectionState.connected)
              _buildConnectedCamera()
            else ...[
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
              
              // Device list
              _buildDeviceList(),
            ],
          ],
        ),
      ),
      floatingActionButton: _showDeviceList ? FloatingActionButton(
        onPressed: () async {
          await _checkBluetoothPermissions();
        },
        child: const Icon(Icons.refresh),
      ) : null,
    );
  }
}