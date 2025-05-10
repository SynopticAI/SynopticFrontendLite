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

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = Auth().currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Group management state
  List<DeviceGroup> _groups = [];
  bool _isEditingGroups = false;
  Device? _draggedDevice;
  
  // Expanded groups tracking
  Set<String> _expandedGroups = {};
  
  @override
  void initState() {
    super.initState();
    _loadGroups();
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
    if (user == null || newName.trim().isEmpty) return;
    
    await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('deviceGroups')
        .doc(group.id)
        .update({'name': newName});
        
    setState(() {
      final idx = _groups.indexWhere((g) => g.id == group.id);
      if (idx >= 0) {
        _groups[idx].name = newName;
      }
    });
  }
  
  Future<void> _deleteGroup(DeviceGroup group) async {
    if (user == null || group.id == 'default') return;
    
    // Find default group
    final defaultGroup = _groups.firstWhere(
      (g) => g.id == 'default',
      orElse: () => _groups.first
    );
    
    // Move devices to default group
    for (final deviceId in group.deviceIds) {
      await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('devices')
          .doc(deviceId)
          .update({'groupId': defaultGroup.id});
    }
    
    // Add devices to default group's list
    if (group.deviceIds.isNotEmpty) {
      await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('deviceGroups')
          .doc(defaultGroup.id)
          .update({
            'deviceIds': FieldValue.arrayUnion(group.deviceIds)
          });
    }
    
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
    
    // Update device's groupId
    await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('devices')
        .doc(device.id)
        .update({'groupId': newGroupId});
    
    // Update source group's deviceIds list
    if (device.groupId != null) {
      await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('deviceGroups')
          .doc(device.groupId)
          .update({
            'deviceIds': FieldValue.arrayRemove([device.id])
          });
    }
    
    // Update target group's deviceIds list
    await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('deviceGroups')
        .doc(newGroupId)
        .update({
          'deviceIds': FieldValue.arrayUnion([device.id])
        });
        
    // Force refresh
    setState(() {});
  }
  
Stream<List<Device>> _getDevices() {
  if (user == null) {
    return Stream.value([]);
  }
  
  return _firestore
      .collection('users')
      .doc(user?.uid)
      .collection('devices')
      .snapshots()
      .map((snapshot) {
        final devices = snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          data['id'] = doc.id;  // Ensure ID is set
          return Device.fromMap(data);
        }).toList();
        
        // Improved filter to remove devices that are being deleted or have null names
        devices.removeWhere((device) => 
          device.name == null || 
          device.status == 'Being Deleted'
        );
        
        // Assign unassigned devices to default group
        _assignUnassignedDevices(devices);
        
        return devices;
      });
}


  Future<void> _assignUnassignedDevices(List<Device> devices) async {
    if (user == null) return;
    
    // Find devices with null groupId
    final unassignedDevices = devices.where((d) => d.groupId == null).toList();
    if (unassignedDevices.isEmpty) return;
    
    // Find default group, create if needed
    DeviceGroup defaultGroup;
    final defaultIdx = _groups.indexWhere((g) => g.id == 'default');
    
    if (defaultIdx >= 0) {
      defaultGroup = _groups[defaultIdx];
    } else {
      defaultGroup = DeviceGroup(id: 'default', name: 'Default Group');
      await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('deviceGroups')
          .doc('default')
          .set(defaultGroup.toMap());
          
      setState(() {
        _groups.add(defaultGroup);
        _expandedGroups.add('default');
      });
    }
    
    // Update devices to assign to default group
    final batch = _firestore.batch();
    for (final device in unassignedDevices) {
      final deviceRef = _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('devices')
          .doc(device.id);
      batch.update(deviceRef, {'groupId': 'default'});
    }
    
    // Update default group's deviceIds
    final deviceIds = unassignedDevices.map((d) => d.id).toList();
    final groupRef = _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('deviceGroups')
        .doc('default');
        
    batch.update(groupRef, {
      'deviceIds': FieldValue.arrayUnion(deviceIds)
    });
    
    await batch.commit();
  }

  Future<void> signOut() async {
    await Auth().signOut();
  }

  void _addNewDevice() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newDeviceName = '';
        String? selectedGroupId = _groups.isNotEmpty ? _groups.first.id : null;
        
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
                tooltip: _isEditingGroups ? 'Done editing' : 'Manage groups',
              ),
              const LanguageSelector(),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => _showLogoutConfirmation(context),
              ),
            ],
          ),
          body: Column(
            children: [
              // Group management bar (visible when editing)
              if (_isEditingGroups)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: Row(
                    children: [
                      const Text(
                        'Manage Groups', 
                        style: TextStyle(fontWeight: FontWeight.bold)
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addGroup,
                        tooltip: 'Add Group',
                      ),
                    ],
                  ),
                ),
                
              // Device list with groups
              Expanded(
                child: StreamBuilder<List<Device>>(
                  stream: _getDevices(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final devices = snapshot.data ?? [];
                    
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
                      ? TextField(
                          controller: TextEditingController(text: group.name),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          onSubmitted: (value) => _renameGroup(group, value),
                        )
                      : Text(
                          group.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                  ),
                  // Device count
                  Text(
                    '${devices.length} device${devices.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete group button (only when editing)
                  if (_isEditingGroups && group.id != 'default')
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      color: Colors.red[400],
                      onPressed: () => _deleteGroup(group),
                      tooltip: 'Delete group',
                    ),
                ],
              ),
            ),
          ),
          
          // Divider
          if (isExpanded)
            const Divider(height: 1, thickness: 1),
          
          // Devices in this group
          if (isExpanded)
            Column(
              children: [
                // Device list with reordering capability
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
            ),
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
                color: isHighlighted ? Colors.blue : Colors.transparent,
                width: isHighlighted ? 2 : 0,
              ),
              borderRadius: BorderRadius.circular(8),
              color: isHighlighted ? Colors.blue.withOpacity(0.1) : null,
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

                  // Main content
                  Expanded(
                    child: ListTile(
                      leading: Container(
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
                        setState(() {});  // Trigger a rebuild
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