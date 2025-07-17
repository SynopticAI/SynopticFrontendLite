import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ai_device_manager/auth.dart';
import 'package:ai_device_manager/device.dart';
import 'package:ai_device_manager/device_group.dart';
import 'package:ai_device_manager/pages/device_config_page.dart';
import 'package:ai_device_manager/pages/device_dashboard_page.dart';
import 'package:ai_device_manager/utils/user_settings.dart';
import 'package:ai_device_manager/widgets/language_selector.dart';
import 'package:ai_device_manager/l10n/app_localizations.dart';
import 'package:ai_device_manager/pages/esp_config_page.dart';
import 'package:ai_device_manager/services/notification_service.dart';
import 'package:ai_device_manager/utils/app_theme.dart';

import 'package:ai_device_manager/l10n/context_extensions.dart';
import 'package:ai_device_manager/widgets/credit_usage_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = Auth().currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, bool> _notificationStatus = {}; // Track notification status per device
  
  // Group management state
  List<DeviceGroup> _groups = [];
  bool _isEditingGroups = false;
  Device? _draggedDevice;
  
  // Expanded groups tracking
  Set<String> _expandedGroups = {};
  
  @override
  void initState() {
    super.initState();
    _loadGroups().then((_) => _loadNotificationStatuses());
    Future.delayed(const Duration(seconds: 3), () {
      NotificationService().debugFCMToken();
    });
  }
  
  Future<void> _loadNotificationStatuses() async {
    try {
      final List<String> deviceIds = [];
      
      // Collect all device IDs from all groups
      for (final group in _groups) {
        final devicesSnapshot = await _firestore
            .collection('users')
            .doc(user!.uid)
            .collection('devices')
            .where('groupId', isEqualTo: group.id)
            .get();
        
        deviceIds.addAll(devicesSnapshot.docs.map((doc) => doc.id));
      }
      
      // Get notification statuses for all devices
      final statuses = await NotificationService().getDeviceNotificationStatuses(deviceIds);
      
      if (mounted) {
        setState(() {
          _notificationStatus = statuses;
        });
      }
    } catch (e) {
      print('Error loading notification statuses: $e');
    }
  }

  Future<void> _toggleDeviceNotification(String deviceId, bool currentStatus) async {
    try {
      final success = await NotificationService().toggleDeviceNotification(deviceId, !currentStatus);
      
      if (success && mounted) {
        setState(() {
          _notificationStatus[deviceId] = !currentStatus;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentStatus 
                ? 'Notifications enabled for this device' 
                : 'Notifications disabled for this device'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update notification settings'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error toggling notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating notification settings'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadGroups() async {
    if (user == null) return;
    
    final groupsSnapshot = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('deviceGroups')
        .get();
        
    List<DeviceGroup> groups = groupsSnapshot.docs
        .map((doc) => DeviceGroup.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
        
    // If no groups exist, create a default group
    if (groups.isEmpty) {
      final defaultGroup = DeviceGroup(
        id: 'default',
        name: 'Default Group',
      );
      
      await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('deviceGroups')
          .doc(defaultGroup.id)
          .set(defaultGroup.toMap());
          
      groups.add(defaultGroup);
    }
    
    setState(() {
      _groups = groups;
      // Start with all groups expanded
      _expandedGroups = groups.map((g) => g.id).toSet();
    });
  }
  
  Future<void> _addGroup() async {
    if (user == null) return;
    
    final String groupId = DateTime.now().millisecondsSinceEpoch.toString();
    final newGroup = DeviceGroup(
      id: groupId,
      name: 'New Group',
    );
    
    await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('deviceGroups')
        .doc(groupId)
        .set(newGroup.toMap());
        
    setState(() {
      _groups.add(newGroup);
      _expandedGroups.add(groupId);
    });
  }
  
  Future<void> _renameGroup(DeviceGroup group, String newName) async {
    if (user == null) return;
    
    await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('deviceGroups')
        .doc(group.id)
        .update({'name': newName});
        
    setState(() {
      group.name = newName;
    });
  }
  
  Future<void> _deleteGroup(DeviceGroup group) async {
    if (user == null) return;
    
    // Move devices to default group first
    final defaultGroup = _groups.firstWhere((g) => g.id == 'default', orElse: () => _groups.first);
    await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('devices')
        .where('groupId', isEqualTo: group.id)
        .get()
        .then((snapshot) async {
          for (var doc in snapshot.docs) {
            await doc.reference.update({'groupId': defaultGroup.id});
          }
        });
    
    // Delete the group
    await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('deviceGroups')
        .doc(group.id)
        .delete();
        
    setState(() {
      _groups.removeWhere((g) => g.id == group.id);
      _expandedGroups.remove(group.id);
    });
  }
  
  Future<void> _moveDeviceToGroup(Device device, String newGroupId) async {
    if (user == null) return;
    
    await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('devices')
        .doc(device.id)
        .update({'groupId': newGroupId});
  }

  Future<void> signOut() async {
    await Auth().signOut();
  }

  Future<void> _addNewDevice() async {
    String newDeviceName = '';
    String? selectedGroupId = _groups.isNotEmpty ? _groups.first.id : null;
    
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.addDeviceTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) {
                  newDeviceName = value;
                },
                decoration: InputDecoration(
                  hintText: context.l10n.addDeviceEnterName),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedGroupId,
                decoration: const InputDecoration(
                  labelText: 'Group',
                ),
                items: _groups.map((group) => DropdownMenuItem(
                  value: group.id,
                  child: Text(group.name),
                )).toList(),
                onChanged: (value) {
                  selectedGroupId = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(context.l10n.cancel),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text(context.l10n.add),
              onPressed: () async {
                if (newDeviceName.isNotEmpty) {
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.userNotLoggedIn)),
                    );
                    return;
                  }

                  final deviceId = DateTime.now().millisecondsSinceEpoch.toString();
                  
                  final device = Device(
                    id: deviceId,
                    name: newDeviceName,
                    groupId: selectedGroupId,
                    setupStage: 0.0,
                  );

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('devices')
                      .doc(device.id)
                      .set(device.toMap());

                  // Add device to selected group
                  if (selectedGroupId != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('deviceGroups')
                        .doc(selectedGroupId)
                        .update({
                          'deviceIds': FieldValue.arrayUnion([deviceId])
                        });
                  }

                  Navigator.pop(context);

                  // Navigate directly to camera setup instead of device configuration
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ESPConfigPage(
                          deviceId: device.id,
                          userId: userId,
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // WiFi Signal Strength Helper Methods
  bool _isDeviceConnected(Device device) {
    if (device.lastHeartbeat == null) return false;
    
    try {
      final lastHeartbeatTime = int.parse(device.lastHeartbeat!);
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final timeDifference = currentTime - lastHeartbeatTime;
      
      // Device is considered disconnected if last heartbeat was more than 2 minutes ago
      // return timeDifference <= 120000; // 2 minutes in milliseconds
      return timeDifference <= 30000; // 30 seconds in milliseconds
    } catch (e) {
      return false;
    }
  }

  IconData _getWifiSignalIcon(int? signalStrength,bool isConnected) {
    if (!isConnected) return Icons.wifi_off_rounded;
    if (signalStrength == null) return Icons.wifi_off_rounded;
    
    // RSSI ranges for WiFi signal quality
    if (signalStrength >= -50) {
      return Icons.wifi_rounded; // 4 bars (excellent)
    } else if (signalStrength >= -60) {
      return Icons.network_wifi_3_bar_rounded; // 3 bars (good)
    } else if (signalStrength >= -70) {
      return Icons.network_wifi_2_bar_rounded; // 2 bars (fair)
    } else if (signalStrength >= -80) {
      return Icons.network_wifi_1_bar_rounded; // 1 bar (weak/poor)
    } else {
      return Icons.signal_wifi_0_bar_rounded; // Very weak/no signal
    }
  }

  Color _getWifiIconColor(int? signalStrength, bool isConnected) {
    if (!isConnected) return Colors.red;
    if (signalStrength == null) return Colors.red;
    
    // Color coding for signal strength
    if (signalStrength >= -50) {
      return Colors.green; // Excellent signal: green
    } else if (signalStrength >= -70) {
      return Colors.white; // Good signal: white
    } else if (signalStrength >= -80) {
      return Colors.orange; // Poor signal: orange
    } else {
      return Colors.red; // Very poor signal: red
    }
  }

  Widget _buildWifiIcon(Device device) {
    final isConnected = _isDeviceConnected(device);
    final signalStrength = device.wifiSignalStrength;
    final icon = _getWifiSignalIcon(isConnected ? signalStrength : null, isConnected);
    final color = _getWifiIconColor(signalStrength, isConnected);

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 14,
        color: color,
      ),
    );
  }

  Widget _buildGroupSection(DeviceGroup group, List<Device> devices) {
    final isExpanded = _expandedGroups.contains(group.id);

    devices = devices.where((device) => device.name != null && device.name.isNotEmpty).toList();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          // Group header/title
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedGroups.remove(group.id);
                } else {
                  _expandedGroups.add(group.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 8),
                  // Group name (editable when in edit mode)
                  Expanded(
                    child: _isEditingGroups 
                      ? TextFormField(
                          initialValue: group.name,
                          onFieldSubmitted: (value) {
                            if (value.isNotEmpty) {
                              _renameGroup(group, value);
                            }
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        )
                      : Text(
                          group.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  ),
                  Text(
                    '${devices.length} device${devices.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (_isEditingGroups && group.id != 'default') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _deleteGroup(group),
                      color: Colors.red[300],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Devices list
          if (isExpanded) ...[
            if (devices.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  return _buildDeviceTile(devices[index], group, key: ValueKey(devices[index].id));
                },
                onReorder: (oldIndex, newIndex) {
                  // Handle reordering within the same group
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  
                  // Update device order in this group
                  final deviceIds = devices.map((d) => d.id).toList();
                  final movedId = deviceIds.removeAt(oldIndex);
                  deviceIds.insert(newIndex, movedId);
                  
                  // Update group's deviceIds in Firestore
                  _firestore
                      .collection('users')
                      .doc(user!.uid)
                      .collection('deviceGroups')
                      .doc(group.id)
                      .update({'deviceIds': deviceIds});
                },
              ),
            
            // Empty group drop target
            if (devices.isEmpty)
              DragTarget<Device>(
                onWillAccept: (device) => device != null && device.groupId != group.id,
                onAccept: (device) => _moveDeviceToGroup(device, group.id),
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;
                  return Container(
                    height: 80,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHovering ? Colors.blue : Colors.grey.withOpacity(0.3),
                        width: isHovering ? 2 : 1,
                        style: BorderStyle.solid,
                      ),
                      color: isHovering ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        isHovering ? 'Drop here to add to this group' : 'No devices in this group',
                        style: TextStyle(
                          color: isHovering ? Colors.blue : Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
  
Widget _buildDeviceTile(Device device, DeviceGroup group, {Key? key}) {
  // Enhanced device tile that supports both reordering and dragging to other groups

  if (device.name == null) {
    // Skip devices with null name (being deleted)
    return SizedBox.shrink(key: key);
  }
  
  final isNotificationEnabled = _notificationStatus[device.id] ?? false;
  
  return LongPressDraggable<Device>(
    key: key,
    data: device,
    delay: const Duration(milliseconds: 150), // Short delay to differentiate from taps
    onDragStarted: () {
      setState(() {
        _draggedDevice = device;
      });
    },
    onDragEnd: (_) {
      setState(() {
        _draggedDevice = null;
      });
    },
    // What shows while dragging
    feedback: Material(
      elevation: 4.0,
      color: Colors.transparent,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.devices, size: 24),
            SizedBox(width: 8),
            Expanded(child: Text(device.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    ),
    childWhenDragging: Container(
      key: ValueKey('dragging_${device.id}'),
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.withOpacity(0.1),
      ),
    ),
    // The device card
    child: DragTarget<Device>(
      onWillAccept: (incomingDevice) {
        // Accept if it's not this device and not in this group already
        return incomingDevice != null && 
               incomingDevice.id != device.id &&
               incomingDevice.groupId != group.id;
      },
      onAccept: (incomingDevice) {
        // Move the incoming device to this group (will be inserted next to this device)
        _moveDeviceToGroup(incomingDevice, group.id);
      },
      builder: (context, candidateData, rejectedData) {
        // Highlight when a dragged device is hovering
        final isHighlighted = candidateData.isNotEmpty;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: isHighlighted ? AppTheme.primaryColor : Colors.transparent,
              width: isHighlighted ? 2 : 0,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isHighlighted ? AppTheme.primaryColor.withOpacity(0.1) : null,
          ),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            child: Row(
              children: [
                // Drag handle for reordering
                _isEditingGroups ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: const Icon(
                    Icons.drag_handle,
                    color: Colors.grey,
                    size: 20,
                  ),
                ) : const SizedBox.shrink(),

                // Main content with image and device info
                Expanded(
                  child: ListTile(
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FutureBuilder<String>(
                              key: ValueKey("${device.id}_image"),
                              future: FirebaseStorage.instance
                                  .ref('users/${user!.uid}/devices/${device.id}/icon.png')
                                  .getDownloadURL()
                                  .catchError((e) => ""),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                  return Image.network(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.devices,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                                return const Icon(
                                  Icons.devices,
                                  color: Colors.grey,
                                );
                              },
                            ),
                          ),
                        ),
                        // WiFi Signal Icon positioned at top-right corner
                        Positioned(
                          top: -3,
                          right: -3,
                          child: _buildWifiIcon(device),
                        ),
                      ],
                    ),
                    title: Text(device.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.taskDescription ?? 'No description', 
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Status: ${device.status}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DeviceDashboardPage(
                            device: device,
                            userId: user!.uid,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // NEW: Notification toggle button (using company colors)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _toggleDeviceNotification(device.id, isNotificationEnabled),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isNotificationEnabled 
                              ? AppTheme.primaryColor.withOpacity(0.1) 
                              : AppTheme.primaryGray.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isNotificationEnabled 
                                ? AppTheme.primaryColor.withOpacity(0.3) 
                                : AppTheme.primaryGray.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isNotificationEnabled 
                              ? Icons.notifications_active 
                              : Icons.notifications_off_outlined,
                          size: 18,
                          color: isNotificationEnabled 
                              ? AppTheme.primaryColor 
                              : AppTheme.primaryGray,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Existing settings button
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () async {
                    final shouldRefresh = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeviceConfigPage(
                          device: device,
                          userId: user!.uid,
                        ),
                      ),
                    );
                    
                    if (shouldRefresh == true) {
                      setState(() {});
                      _loadNotificationStatuses(); // Refresh notification statuses
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: UserSettings().languageStream,
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.appTitle),
            actions: [
              // Group management button
              IconButton(
                icon: Icon(_isEditingGroups ? Icons.done : Icons.view_list_rounded),
                onPressed: () {
                  setState(() {
                    _isEditingGroups = !_isEditingGroups;
                  });
                },
                tooltip: _isEditingGroups ? 'Done' : 'Manage Groups',
              ),
              
              // Add group button (only visible when editing)
              if (_isEditingGroups)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addGroup,
                  tooltip: 'Add Group',
                ),
              
              // Language selector
              const LanguageSelector(),
              
              // Logout button
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => _showLogoutConfirmation(context),
                tooltip: context.l10n.logout,
              ),
            ],
          ),
          body: Column(
            children: [
              CreditUsageWidget(
                showIcon: true,
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(user!.uid)
                      .collection('devices')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final devices = snapshot.data!.docs
                        .map((doc) => Device.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
                        .where((device) => device.name != null)
                        .toList();

                    if (devices.isEmpty && _groups.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.devices_other,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.l10n.noDevicesFound,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.addYourFirstDevice,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // If we have groups but they're loading
                    if (_groups.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    return ListView.builder(
                      itemCount: _groups.length,
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        
                        // Get devices for this group
                        final groupDevices = devices.where(
                          (device) => device.groupId == group.id
                        ).toList();
                        
                        return _buildGroupSection(group, groupDevices);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _addNewDevice,
            child: const Icon(Icons.add),
            tooltip: 'Add Device',
          ),
        );
      },
    );
  }
  
  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logoutConfirmTitle),
        content: Text(context.l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(context.l10n.logout),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await signOut();
    }
  }
}