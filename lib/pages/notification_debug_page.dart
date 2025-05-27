// lib/pages/notification_debug_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_device_manager/services/notification_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationDebugPage extends StatefulWidget {
  const NotificationDebugPage({Key? key}) : super(key: key);

  @override
  State<NotificationDebugPage> createState() => _NotificationDebugPageState();
}

class _NotificationDebugPageState extends State<NotificationDebugPage> {
  Map<String, dynamic>? _notificationStatus;
  bool _isLoading = false;
  String _debugLog = '';

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  Future<void> _loadNotificationStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await NotificationService().getNotificationStatus();
      setState(() {
        _notificationStatus = status;
      });
    } catch (e) {
      _addToLog('Error loading status: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _addToLog(String message) {
    setState(() {
      _debugLog += '${DateTime.now().toString().substring(11, 19)} - $message\n';
    });
  }

  Future<void> _refreshFCMToken() async {
    _addToLog('🔄 Refreshing FCM token...');
    try {
      await NotificationService().refreshFCMToken();
      _addToLog('✅ FCM token refresh completed');
      await _loadNotificationStatus();
    } catch (e) {
      _addToLog('❌ Error refreshing token: $e');
    }
  }

  Future<void> _debugFCMToken() async {
    _addToLog('🔍 Running FCM token debug...');
    try {
      await NotificationService().debugFCMToken();
      _addToLog('✅ Debug completed - check console for details');
    } catch (e) {
      _addToLog('❌ Error in debug: $e');
    }
  }

  Future<void> _testNotification() async {
    _addToLog('📨 Sending test notification...');
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _addToLog('❌ No authenticated user');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://europe-west4-aimanagerfirebasebackend.cloudfunctions.net/test_notification'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': user.uid,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success']) {
          _addToLog('✅ Test notification sent successfully');
        } else {
          _addToLog('❌ Test notification failed: ${result['message']}');
        }
      } else {
        _addToLog('❌ HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      _addToLog('❌ Error sending test notification: $e');
    }
  }

  Future<void> _optOutFromNotifications() async {
    _addToLog('🚫 Opting out from notifications...');
    try {
      final success = await NotificationService().optOutFromNotifications();
      if (success) {
        _addToLog('✅ Successfully opted out from notifications');
        await _loadNotificationStatus();
      } else {
        _addToLog('❌ Failed to opt out from notifications');
      }
    } catch (e) {
      _addToLog('❌ Error opting out: $e');
    }
  }

  Future<void> _optInToNotifications() async {
    _addToLog('✅ Opting in to notifications...');
    try {
      final success = await NotificationService().optInToNotifications();
      if (success) {
        _addToLog('✅ Successfully opted in to notifications');
        await _loadNotificationStatus();
      } else {
        _addToLog('❌ Failed to opt in to notifications');
      }
    } catch (e) {
      _addToLog('❌ Error opting in: $e');
    }
  }

  Widget _buildStatusCard(String title, dynamic value, {Color? color}) {
    return Card(
      color: color?.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                value.toString(),
                style: TextStyle(
                  color: color,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 Notification Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotificationStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Section
                  const Text(
                    '📊 Current Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  if (_notificationStatus != null) ...[
                    _buildStatusCard(
                      'Platform', 
                      _notificationStatus!['platform'] ?? 'Unknown',
                    ),
                    _buildStatusCard(
                      'Device ID', 
                      _notificationStatus!['deviceId'] ?? 'Unknown',
                    ),
                    _buildStatusCard(
                      'Has Local Token', 
                      _notificationStatus!['hasLocalToken'] ?? false,
                      color: _notificationStatus!['hasLocalToken'] == true 
                          ? Colors.green : Colors.red,
                    ),
                    _buildStatusCard(
                      'Authorization', 
                      _notificationStatus!['authorizationStatus'] ?? 'Unknown',
                      color: _notificationStatus!['authorizationStatus']?.contains('authorized') == true
                          ? Colors.green : Colors.orange,
                    ),
                    
                    // Permissions
                    if (_notificationStatus!['permissions'] != null) ...[
                      const SizedBox(height: 8),
                      const Text('🔐 Permissions:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._notificationStatus!['permissions'].entries.map(
                        (entry) => _buildStatusCard(
                          '  ${entry.key}',
                          entry.value,
                          color: entry.value.toString().contains('enabled') ? Colors.green : Colors.orange,
                        ),
                      ).toList(),
                    ],
                    
                    // Firestore info
                    if (_notificationStatus!['firestore'] != null) ...[
                      const SizedBox(height: 8),
                      const Text('🗄️ Firestore:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._notificationStatus!['firestore'].entries.map(
                        (entry) => _buildStatusCard(
                          '  ${entry.key}',
                          entry.value,
                          color: entry.key == 'hasCurrentDeviceToken' && entry.value == true
                              ? Colors.green : null,
                        ),
                      ).toList(),
                    ],
                  ] else ...[
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('❌ Failed to load notification status'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action Buttons
                  const Text(
                    '🔧 Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _refreshFCMToken,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Token'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _debugFCMToken,
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Debug FCM'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _testNotification,
                        icon: const Icon(Icons.send),
                        label: const Text('Test Notification'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _optOutFromNotifications,
                        icon: const Icon(Icons.notifications_off),
                        label: const Text('Opt Out'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      ),
                      ElevatedButton.icon(
                        onPressed: _optInToNotifications,
                        icon: const Icon(Icons.notifications_active),
                        label: const Text('Opt In'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Debug Log
                  const Text(
                    '📝 Debug Log',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _debugLog.isEmpty ? 'No debug messages yet.' : _debugLog,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _debugLog = '';
                            });
                          },
                          child: const Text('Clear Log'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}