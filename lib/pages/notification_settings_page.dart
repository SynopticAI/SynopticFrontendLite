// lib/pages/notification_settings_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ai_device_manager/device.dart';
import 'package:ai_device_manager/utils/app_theme.dart';
import 'package:ai_device_manager/l10n/app_localizations.dart';
import 'package:ai_device_manager/pages/notification_settings_page.dart';

class NotificationSettingsPage extends StatefulWidget {
  final Device device;
  final String userId;

  const NotificationSettingsPage({
    Key? key,
    required this.device,
    required this.userId,
  }) : super(key: key);

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Currently expanded class section
  String? _expandedClass;
  
  // Store notification settings
  Map<String, Map<String, dynamic>> _notificationSettings = {};
  
  // List of classes for this device
  List<String> _deviceClasses = [];
  
  // Loading state
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadNotificationSettings();
  }

  // Load classes configured for this device
  Future<void> _loadClasses() async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('devices')
          .doc(widget.device.id)
          .get();
      
      if (!doc.exists) return;
      
      final data = doc.data()!;
      
      // Get classes from device data
      // This assumes there's a 'classes' field in the device document
      // Adjust this based on your actual data structure
      List<String> classes = [];
      if (data.containsKey('classes')) {
        classes = List<String>.from(data['classes'] ?? []);
      }
      
      // If no classes are defined yet, add some default ones for testing
      if (classes.isEmpty) {
        classes = ['Cat', 'Dog', 'Goat']; // Default classes from your sketch
      }
      
      setState(() {
        _deviceClasses = classes;
        _expandedClass = classes.isNotEmpty ? classes[0] : null;
      });
    } catch (e) {
      print('Error loading classes: $e');
    }
  }

  // Load notification settings for this device
  Future<void> _loadNotificationSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('devices')
          .doc(widget.device.id)
          .get();
      
      if (!doc.exists) {
        setState(() => _isLoading = false);
        return;
      }
      
      final data = doc.data()!;
      
      // Get notification settings or initialize defaults
      Map<String, Map<String, dynamic>> settings = {};
      
      if (data.containsKey('notificationSettings')) {
        final rawSettings = data['notificationSettings'] as Map<String, dynamic>;
        rawSettings.forEach((className, value) {
          settings[className] = Map<String, dynamic>.from(value);
        });
      }
      
      setState(() {
        _notificationSettings = settings;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notification settings: $e');
      setState(() => _isLoading = false);
    }
  }

  // Initialize default settings for a class
  Map<String, dynamic> _getClassSettings(String className) {
    if (_notificationSettings.containsKey(className)) {
      return _notificationSettings[className]!;
    }
    
    // Default settings
    return {
      'triggerType': 'count',
      'threshold': 1,
      'regionImagePath': null,
    };
  }

  // Save notification settings
  Future<void> _saveSettings() async {
    try {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('devices')
          .doc(widget.device.id)
          .update({
        'notificationSettings': _notificationSettings,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification settings saved')),
      );
    } catch (e) {
      print('Error saving notification settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    }
  }

  // Update settings for a specific class
  void _updateClassSettings(String className, Map<String, dynamic> settings) {
    setState(() {
      _notificationSettings[className] = settings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notification Configuration',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Configure when to receive notifications for each detected class. ' +
                            'You can set notifications based on count or location.',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Class sections
                  ..._deviceClasses.map((className) => _buildClassSection(className)),
                  
                  // Save button
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Settings'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: _saveSettings,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildClassSection(String className) {
    final isExpanded = _expandedClass == className;
    final settings = _getClassSettings(className);
    final triggerType = settings['triggerType'] as String? ?? 'count';
    final threshold = settings['threshold'] as int? ?? 1;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: () {
              setState(() {
                _expandedClass = isExpanded ? null : className;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 16),
                  Text(
                    className,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Show a summary of the current setting
                  Text(
                    triggerType == 'count'
                        ? 'Threshold: $threshold'
                        : 'Location trigger',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded content
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trigger type dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Notification Trigger',
                      border: OutlineInputBorder(),
                    ),
                    value: triggerType,
                    items: const [
                      DropdownMenuItem(value: 'count', child: Text('Count Threshold')),
                      DropdownMenuItem(value: 'location', child: Text('Location')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        final newSettings = Map<String, dynamic>.from(settings);
                        newSettings['triggerType'] = value;
                        _updateClassSettings(className, newSettings);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Settings specific to the trigger type
                  if (triggerType == 'count')
                    _buildCountThresholdSettings(className, settings)
                  else
                    _buildLocationTriggerSettings(className, settings),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCountThresholdSettings(String className, Map<String, dynamic> settings) {
    final threshold = settings['threshold'] as int? ?? 1;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notify when count exceeds threshold:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        Slider(
          value: threshold.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: threshold.toString(),
          onChanged: (value) {
            final newSettings = Map<String, dynamic>.from(settings);
            newSettings['threshold'] = value.round();
            _updateClassSettings(className, newSettings);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            10,
            (index) => Text('${index + 1}', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationTriggerSettings(String className, Map<String, dynamic> settings) {
    // This would be replaced with actual camera feed or a placeholder
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Draw region to trigger notification:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 8),
                Text(
                  'Camera feed placeholder',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Draw Region'),
                  onPressed: () {
                    // This would open a drawing interface
                    // For now, just show a message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Drawing functionality coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}