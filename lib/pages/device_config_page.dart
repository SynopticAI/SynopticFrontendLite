import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ai_device_manager/device.dart';
import 'package:ai_device_manager/pages/assistant_page.dart';
import 'package:ai_device_manager/pages/esp_config_page.dart';
import 'package:ai_device_manager/pages/camera_testing_page.dart';
import 'package:ai_device_manager/utils/app_theme.dart';
import 'package:ai_device_manager/l10n/app_localizations.dart';
import 'package:ai_device_manager/pages/notification_settings_page.dart';

import 'package:ai_device_manager/l10n/context_extensions.dart';
import 'package:ai_device_manager/widgets/credit_usage_widget.dart';

class DeviceConfigPage extends StatefulWidget {
  final Device device;
  final String userId;

  const DeviceConfigPage({
    Key? key,
    required this.device,
    required this.userId,
  }) : super(key: key);

  @override
  State<DeviceConfigPage> createState() => _DeviceConfigPageState();
}

class _DeviceConfigPageState extends State<DeviceConfigPage> {
  late TextEditingController _nameController;
  late TextEditingController _taskDescriptionController;
  late String _selectedInferenceMode;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isAssistantExpanded = false;
  bool _isCameraSettingsExpanded = false;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device.name);
    _taskDescriptionController = TextEditingController(
      text: widget.device.taskDescription ?? ''
    );
    _selectedInferenceMode = widget.device.inferenceMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taskDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateDevice() async {
    await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('devices')
        .doc(widget.device.id)
        .update({
      'name': _nameController.text,
      'taskDescription': _taskDescriptionController.text,
      'inferenceMode': _selectedInferenceMode,
    });
  }

  // Show dialog to edit device name and description
  void _editDeviceInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.deviceConfigPageEditDeviceInfo ?? 'Edit Device Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.deviceConfigPageDeviceName ?? 'Device Name',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _updateDevice(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _taskDescriptionController,
                decoration: InputDecoration(
                  labelText: context.l10n.deviceConfigPageTaskDescription ?? 'Task Description',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _updateDevice(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Inference Mode',
                  border: OutlineInputBorder(),
                ),
                value: _selectedInferenceMode,
                items: const [
                  DropdownMenuItem(value: 'Point', child: Text('Point Detection')),
                  DropdownMenuItem(value: 'Detect', child: Text('Object Detection')),
                  // DropdownMenuItem(value: 'VQA', child: Text('Visual Q&A')), // diabled for now
                  // DropdownMenuItem(value: 'Caption', child: Text('Image Captioning')), // diabled for now
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedInferenceMode = value;
                    });
                    _updateDevice();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.done ?? 'Done'),
            ),
          ],
        );
      },
    );
  }

Future<void> _backgroundDelete() async {
  try {
    // Step 1: First remove the device from its group
    // This ensures the group doesn't have references to a device that will be deleted
    if (widget.device.groupId != null) {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('deviceGroups')
          .doc(widget.device.groupId)
          .update({
            'deviceIds': FieldValue.arrayRemove([widget.device.id])
          });
    }
    
    // Step 2: Delete the document from Firestore
    await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('devices')
        .doc(widget.device.id)
        .delete();
    
    // Step 3: Clean up storage data recursively
    final storageRef = FirebaseStorage.instance.ref()
        .child('users/${widget.userId}/devices/${widget.device.id}');
    
    try {
      final ListResult result = await storageRef.listAll();
      
      await Future.wait([
        ...result.items.map((ref) => ref.delete()),
        ...result.prefixes.map((prefix) async {
          final subResult = await prefix.listAll();
          return Future.wait([
            ...subResult.items.map((ref) => ref.delete()),
            ...subResult.prefixes.map((prefix) async {
              final subSubResult = await prefix.listAll();
              return Future.wait(subSubResult.items.map((ref) => ref.delete()));
            }),
          ]);
        }),
      ]);
    } catch (e) {
      print('Error deleting storage: $e');
    }
  } catch (e) {
    print('Error in background deletion: $e');
  }
}

Future<void> _deleteDevice() async {
  try {
    // First, mark the device as being deleted in Firestore
    await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('devices')
        .doc(widget.device.id)
        .update({
      'status': 'Being Deleted',
      'deletionStarted': FieldValue.serverTimestamp(),
      'name': null, // Set name to null to help filter out in queries
    });

    // Return to home page immediately
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // Start background deletion
    _backgroundDelete();
  } catch (e) {
    print('Error initiating device deletion: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting device: $e')),
      );
    }
  }
}



  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text(context.l10n.deviceConfigPageDeleteConfirmationContent ?? 
                      'Are you sure you want to delete this device? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context, true);  // Close dialog
              _deleteDevice();         // Start deletion process
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.deviceConfigPageTitle ?? 'Device Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true);  // Pop with refresh flag
          },
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('devices')
            .doc(widget.device.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final deviceData = snapshot.data!.data() as Map<String, dynamic>;
          final updatedDevice = Device.fromMap({...deviceData, 'id': widget.device.id});

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CreditUsageWidget(
                  deviceId: widget.device.id,
                  showIcon: true,
                ),
                // Device Header Card (tappable to edit name/description)
                InkWell(
                  onTap: _editDeviceInfo,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FutureBuilder<String>(
                                future: FirebaseStorage.instance
                                    .ref('users/${widget.userId}/devices/${updatedDevice.id}/icon.png')
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(updatedDevice.name, 
                                  style: Theme.of(context).textTheme.titleLarge),
                                Text(updatedDevice.taskDescription ?? 'No description',
                                  style: Theme.of(context).textTheme.bodyMedium),
                                Text('Status: ${updatedDevice.status}',
                                  style: Theme.of(context).textTheme.bodySmall),
                                Text('Inference Mode: ${_getInferenceModeLabel(updatedDevice.inferenceMode)}',
                                  style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

                // AI Assistant Widget
                Card(
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isAssistantExpanded = !_isAssistantExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                color: AppTheme.secondaryAccentColor,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.deviceConfigPageAiAssistant ?? 'AI Assistant',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Icon(_isAssistantExpanded 
                                ? Icons.expand_less 
                                : Icons.expand_more
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isAssistantExpanded)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.deviceConfigPageAiAssistantHelp ?? 
                                'Get help setting up your device with our AI assistant.',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              ...[
                                context.l10n.deviceConfigPageCameraParams ?? 'Camera parameters',
                                context.l10n.deviceConfigPageInferenceMode ?? 'Inference mode',
                                context.l10n.deviceConfigPageActionsNotifications ?? 'Actions and notifications',
                              ].map((text) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, 
                                      size: 16, 
                                      color: Colors.grey
                                    ),
                                    const SizedBox(width: 8),
                                    Text(text, style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.chat,
                                    color: AppTheme.surfaceColor,),
                                  label: Text(context.l10n.deviceConfigPageStartChat ?? 'Start Chat'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AssistantPage(
                                          userId: widget.userId,
                                          deviceId: widget.device.id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Camera Testing Card
                Card(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CameraTestingPage(
                            device: updatedDevice,
                            userId: widget.userId,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryAccentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: AppTheme.secondaryAccentColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.testCamera ?? 'Camera Testing',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  context.l10n.testCameraDescription ?? 
                                  'Test device camera and inference',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Camera Setup Card
                Card(
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isCameraSettingsExpanded = !_isCameraSettingsExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.linked_camera,
                                  color: AppTheme.primaryColor,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.deviceConfigPageCameraSetup ?? 'Camera Setup',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      updatedDevice.connectedCameraId != null ?
                                        'Camera connected' : 'No camera connected',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(_isCameraSettingsExpanded 
                                ? Icons.expand_less 
                                : Icons.expand_more
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isCameraSettingsExpanded)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (updatedDevice.connectedCameraId != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Camera ID: ${updatedDevice.connectedCameraId}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Capture Interval: ${updatedDevice.captureIntervalHours}h ${updatedDevice.captureIntervalMinutes}m ${updatedDevice.captureIntervalSeconds}s'),
                                    Text('Motion Triggered: ${updatedDevice.motionTriggered ? 'Yes' : 'No'}'),
                                    Text('Save Images: ${updatedDevice.saveImages ? 'Yes' : 'No'}'),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.settings),
                                  label: Text(updatedDevice.connectedCameraId != null ? 
                                    'Modify Camera Settings' : 'Connect Camera'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ESPConfigPage(
                                          userId: widget.userId,
                                          deviceId: widget.device.id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationSettingsPage(
                            device: updatedDevice,
                            userId: widget.userId,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.notifications_active,
                              color: AppTheme.accentColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.notificationSettings ?? 'Notification Settings',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  context.l10n.notificationSettingsDescription ?? 
                                  'Configure when to receive notifications',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Delete Device Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showDeleteConfirmation(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      context.l10n.deviceConfigPageDeleteDevice ?? 'Delete Device',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  String _getInferenceModeLabel(String mode) {
    switch (mode) {
      case 'Point':
        return 'Point Detection';
      case 'Detect':
        return 'Object Detection';
      case 'VQA':
        return 'Visual Q&A';
      case 'Caption':
        return 'Image Captioning';
      default:
        return mode;
    }
  }
}