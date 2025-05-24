// lib/pages/notification_settings_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ai_device_manager/device.dart';
import 'package:ai_device_manager/utils/app_theme.dart';
import 'package:ai_device_manager/l10n/app_localizations.dart';
import '../models/region_selector_data.dart';
import '../widgets/region_selector.dart';

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
      List<String> classes = [];
      if (data.containsKey('classes')) {
        classes = List<String>.from(data['classes'] ?? []);
      }
      
      // If no classes are defined yet, add some default ones for testing
      if (classes.isEmpty) {
        classes = ['Cat', 'Dog', 'Person']; // Default classes
      }
      
      setState(() {
        _deviceClasses = classes;
        _expandedClass = classes.isNotEmpty ? classes[0] : null;
      });
    } catch (e) {
      print('Error loading classes: $e');
    }
  }

  Future<List<String>> _getRecentDeviceImages() async {
    try {
      final storageRef = FirebaseStorage.instance.ref()
        .child('users/${widget.userId}/devices/${widget.device.id}/receiving');
        
      final result = await storageRef.listAll();
      
      // Get download URLs for the most recent images (up to 5)
      final urls = <String>[];
      final sortedItems = result.items.toList()
        ..sort((a, b) => b.name.compareTo(a.name)); // Sort by name (timestamp) descending
      
      for (var item in sortedItems.take(5)) {
        try {
          urls.add(await item.getDownloadURL());
        } catch (e) {
          print('Error getting download URL for ${item.name}: $e');
        }
      }
      
      return urls;
    } catch (e) {
      print('Error loading device images: $e');
      return [];
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
    
    // Default settings - "none" is the new default
    return {
      'triggerType': 'none',
      'threshold': 1,
      'regionData': null,
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
        'notificationSettingsUpdated': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notification settings saved successfully')),
        );
      }
    } catch (e) {
      print('Error saving notification settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }

  // Update settings for a specific class
  void _updateClassSettings(String className, Map<String, dynamic> settings) {
    setState(() {
      _notificationSettings[className] = settings;
    });
  }

  // Get summary text for a class setting
  String _getSettingSummary(String className) {
    final settings = _getClassSettings(className);
    final triggerType = settings['triggerType'] as String? ?? 'none';
    
    switch (triggerType) {
      case 'count':
        final threshold = settings['threshold'] as int? ?? 1;
        return 'Threshold: $threshold';
      case 'location':
        final hasRegion = settings['regionData'] != null;
        return hasRegion ? 'Region defined' : 'No region set';
      case 'none':
      default:
        return 'No notifications';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Notification Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Settings'),
      ),
      // Prevent overscroll glow effect
      body: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (overscroll) {
          overscroll.disallowIndicator();
          return true;
        },
        child: SingleChildScrollView(
          // Use less aggressive physics
          physics: const ClampingScrollPhysics(),
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
                        'You can disable notifications, set count thresholds, or define location-based triggers.',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Class sections
              if (_deviceClasses.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No classes configured yet. Set up your device first.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                )
              else
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
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _saveSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassSection(String className) {
    final isExpanded = _expandedClass == className;
    final settings = _getClassSettings(className);
    final triggerType = settings['triggerType'] as String? ?? 'none';
    
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
                  // Show notification status with color coding
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTriggerTypeColor(triggerType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTriggerTypeIcon(triggerType),
                          size: 14,
                          color: _getTriggerTypeColor(triggerType),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getSettingSummary(className),
                          style: TextStyle(
                            color: _getTriggerTypeColor(triggerType),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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
                      DropdownMenuItem(value: 'none', child: Text('No Notifications')),
                      DropdownMenuItem(value: 'count', child: Text('Count Threshold')),
                      DropdownMenuItem(value: 'location', child: Text('Location-Based')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        final newSettings = Map<String, dynamic>.from(settings);
                        newSettings['triggerType'] = value;
                        
                        // Clear region data when switching away from location
                        if (value != 'location') {
                          newSettings['regionData'] = null;
                        }
                        
                        _updateClassSettings(className, newSettings);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Settings specific to the trigger type
                  if (triggerType == 'count')
                    _buildCountThresholdSettings(className, settings)
                  else if (triggerType == 'location')
                    _buildLocationTriggerSettings(className, settings)
                  else if (triggerType == 'none')
                    _buildNoNotificationSettings(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getTriggerTypeColor(String triggerType) {
    switch (triggerType) {
      case 'count':
        return Colors.orange;
      case 'location':
        return Colors.blue;
      case 'none':
      default:
        return Colors.grey;
    }
  }

  IconData _getTriggerTypeIcon(String triggerType) {
    switch (triggerType) {
      case 'count':
        return Icons.numbers;
      case 'location':
        return Icons.location_on;
      case 'none':
      default:
        return Icons.notifications_off;
    }
  }

  Widget _buildNoNotificationSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_off, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No notifications will be sent for this class.',
              style: TextStyle(
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
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
        Row(
          children: [
            Icon(Icons.numbers, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Notify when count reaches or exceeds:',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[800]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Threshold value display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$threshold detection${threshold == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange[700],
            ),
          ),
        ),
        const SizedBox(height: 8),
        
        // Slider
        Slider(
          value: threshold.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: threshold.toString(),
          activeColor: Colors.orange,
          onChanged: (value) {
            final newSettings = Map<String, dynamic>.from(settings);
            newSettings['threshold'] = value.round();
            _updateClassSettings(className, newSettings);
          },
        ),
        
        // Min/Max labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text('5', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationTriggerSettings(String className, Map<String, dynamic> settings) {
    // Get existing region data or create new
    final regionData = RegionSelectorData();
    
    // If we have existing data, deserialize it
    if (settings.containsKey('regionData') && settings['regionData'] != null) {
      try {
        regionData.fromMap(settings['regionData']);
      } catch (e) {
        print('Error loading region data: $e');
      }
    }
    
    return FutureBuilder<List<String>>(
      future: _getRecentDeviceImages(),
      builder: (context, snapshot) {
        // Default placeholder image URL
        String imageUrl = 'https://via.placeholder.com/400x300/e0e0e0/666666?text=No+Camera+Feed';
        
        // Use the first real image if available
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          imageUrl = snapshot.data!.first;
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(  // ← ADD THIS Expanded widget
                  child: Text(
                    'Draw trigger region:',
                    style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[800]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Notifications will be sent when detections occur within the drawn area.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            
            // Region selector
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 400,
                  child: RegionSelector(
                    imageUrl: imageUrl,
                    data: regionData,
                    onRegionChanged: (data) {
                      final newSettings = Map<String, dynamic>.from(settings);
                      newSettings['regionData'] = data.toMap();
                      _updateClassSettings(className, newSettings);
                    },
                  ),
                ),
              ),
            ),
            
            // Status indicator
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: regionData.hasRegions 
                    ? Colors.blue.withOpacity(0.1) 
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    regionData.hasRegions ? Icons.check_circle : Icons.info,
                    color: regionData.hasRegions ? Colors.blue : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      regionData.hasRegions 
                          ? 'Trigger region defined. Notifications will be sent when $className is detected in this area.'
                          : 'No trigger region defined yet. Draw an area above to set up location-based notifications.',
                      style: TextStyle(
                        color: regionData.hasRegions ? Colors.blue[700] : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}