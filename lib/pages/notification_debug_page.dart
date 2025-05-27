// lib/pages/notification_debug_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_device_manager/services/notification_service.dart';
import 'dart:convert'; // For json.encode
import 'package:http/http.dart' as http; // For test notification
import 'dart:math' show min; // For truncating token display

class NotificationDebugPage extends StatefulWidget {
  const NotificationDebugPage({Key? key}) : super(key: key);

  @override
  State<NotificationDebugPage> createState() => _NotificationDebugPageState();
}

class _NotificationDebugPageState extends State<NotificationDebugPage> {
  Map<String, dynamic>? _notificationStatus;
  bool _isLoading = true; // Start with loading true
  String _debugLog = '';
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  Future<void> _loadNotificationStatus({bool showLoading = true}) async {
    if (mounted) {
      setState(() {
        if (showLoading) _isLoading = true;
        _addToLog('🔄 Loading notification status...');
      });
    }

    try {
      final status = await _notificationService.getNotificationStatus();
      if (mounted) {
        setState(() {
          _notificationStatus = status;
          _addToLog('✅ Notification status loaded.');
          if (status['error'] != null) {
            _addToLog('❌ Error in status: ${status['error']}');
          }
          // Specifically log token status
          _addToLog('📱 Device ID: ${status['deviceId']}');
          _addToLog('🍎 APNS Token Status (iOS only): ${status['apnsTokenStatus']}');
          _addToLog('🔑 Local FCM Token: ${status['fcmTokenValue']}');
          _addToLog('🔔 Has Local Token: ${status['hasLocalToken']}');

        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notificationStatus = {'error': e.toString()};
          _addToLog('❌ Error loading status: $e');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _addToLog(String message) {
    if (mounted) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 23);
      setState(() {
        _debugLog = "$timestamp - $message\n$_debugLog"; // Prepend new logs
      });
      print("DEBUG_PAGE_LOG: $message"); // Also print to console if available
    }
  }

  Future<void> _reinitializeNotifications() async {
    _addToLog('🔄 Re-initializing NotificationService...');
    setState(() => _isLoading = true);
    try {
      // This will call NotificationService().initialize() again
      // Assuming NotificationService().initialize() is idempotent or handles re-initialization
      await _notificationService.initialize(); 
      _addToLog('✅ NotificationService re-initialization attempted.');
    } catch (e) {
      _addToLog('❌ Error re-initializing NotificationService: $e');
    } finally {
      await _loadNotificationStatus(showLoading: false); // Reload status after attempt
    }
  }

  Future<void> _refreshFCMToken() async {
    _addToLog('🔄 Refreshing FCM token (deletes and re-fetches)...');
    setState(() => _isLoading = true);
    try {
      await _notificationService.refreshFCMToken();
      _addToLog('✅ FCM token refresh attempt completed.');
    } catch (e) {
      _addToLog('❌ Error refreshing token: $e');
    } finally {
      await _loadNotificationStatus(showLoading: false);
    }
  }

  Future<void> _getAndLogCurrentToken() async {
    _addToLog('🔍 Getting current FCM token from NotificationService...');
    final token = _notificationService.fcmToken;
    if (token != null) {
      _addToLog('🔑 Current FCM Token (from getter): ${token.substring(0, min(token.length, 15))}...');
    } else {
      _addToLog('🔑 Current FCM Token (from getter): Not Available');
    }
    // Also update the main status display
    await _loadNotificationStatus(showLoading: false);
  }


  Future<void> _testNotification() async {
    _addToLog('📨 Sending test notification...');
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _addToLog('❌ No authenticated user. Cannot send test notification.');
      return;
    }

    final localFcmToken = _notificationStatus?['fcmTokenValue'] ?? "Not Available";
    if (localFcmToken == "Not Available" || localFcmToken == "Error") {
        _addToLog('❌ Cannot send test notification: Local FCM token is not available.');
        return;
    }

    _addToLog('ℹ️ Test notification will be sent to current user: ${user.uid}');
    _addToLog('ℹ️ Using FCM tokens stored in Firestore for this user.');

    try {
      final response = await http.post(
        Uri.parse('https://europe-west4-aimanagerfirebasebackend.cloudfunctions.net/test_notification'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': user.uid,
          // Optionally, send a specific token if you want to test one
          // 'target_token': _notificationService.fcmToken, // Example
        }),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          if (result['success']) {
            _addToLog('✅ Test notification sent successfully. Tokens targeted: ${result['tokensTargetedCount']}. Success: ${result['successCount']}. Failure: ${result['failureCount']}.');
             if (result['failureCount'] > 0 && result['results'] != null) {
                _addToLog('ℹ️ Failures: ${json.encode(result['results'])}');
            }
          } else {
            _addToLog('❌ Test notification failed via function: ${result['message']}. Error: ${result['error']}');
          }
        } else {
          _addToLog('❌ HTTP error sending test notification: ${response.statusCode}. Body: ${response.body}');
        }
      }
    } catch (e) {
      _addToLog('❌ Exception sending test notification: $e');
    }
  }

  Future<void> _optOutFromNotifications() async {
    _addToLog('🚫 Opting out from notifications for this device...');
    setState(() => _isLoading = true);
    try {
      final success = await _notificationService.optOutFromNotifications();
      if (success) {
        _addToLog('✅ Successfully opted out from notifications.');
      } else {
        _addToLog('❌ Failed to opt out from notifications.');
      }
    } catch (e) {
      _addToLog('❌ Error opting out: $e');
    } finally {
      await _loadNotificationStatus(showLoading: false);
    }
  }

  Future<void> _optInToNotifications() async {
    _addToLog('✅ Opting in to notifications for this device...');
    setState(() => _isLoading = true);
    try {
      final success = await _notificationService.optInToNotifications();
      if (success) {
        _addToLog('✅ Successfully opted in to notifications.');
      } else {
        _addToLog('❌ Failed to opt in to notifications (likely token issue).');
      }
    } catch (e) {
      _addToLog('❌ Error opting in: $e');
    } finally {
      await _loadNotificationStatus(showLoading: false);
    }
  }

  Widget _buildStatusCard(String title, dynamic value, {Color? color, String? details}) {
    String displayValue = value?.toString() ?? 'N/A';
    if (value is String && value.isEmpty) displayValue = 'Empty';
    if (value is Map && value.isEmpty) displayValue = 'Empty Map';
    if (value is List && value.isEmpty) displayValue = 'Empty List';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: color?.withOpacity(0.1) ?? Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    displayValue,
                    style: TextStyle(
                      color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            if (details != null && details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                details,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasLocalToken = _notificationStatus?['hasLocalToken'] == true;
    bool isIOS = _notificationStatus?['platform'] == 'ios';

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 Notification Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _isLoading ? null : () => _loadNotificationStatus(),
          ),
        ],
      ),
      body: _isLoading && _notificationStatus == null // Show loading only on initial load
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadNotificationStatus(),
              child: ListView( // Changed to ListView for better scrolling with lots of info
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildSectionTitle('📊 Current Status'),
                  if (_notificationStatus != null) ...[
                    _buildStatusCard(
                      'Platform', 
                      _notificationStatus!['platform'],
                    ),
                    _buildStatusCard(
                      'Device ID', 
                      _notificationStatus!['deviceId'],
                      details: "Unique ID for this app installation."
                    ),
                    if (isIOS)
                      _buildStatusCard(
                        'APNS Token Status', 
                        _notificationStatus!['apnsTokenStatus'],
                        color: _notificationStatus!['apnsTokenStatus'] == 'Available' 
                            ? Colors.green 
                            : (_notificationStatus!['apnsTokenStatus'] == 'Not Available' ? Colors.orange : Colors.red),
                        details: "Apple Push Notification service token. Required for FCM on iOS."
                      ),
                    _buildStatusCard(
                      'Local FCM Token', 
                      _notificationStatus!['fcmTokenValue'],
                      color: hasLocalToken ? Colors.green : Colors.red,
                      details: "Firebase Cloud Messaging token obtained by the app."
                    ),
                    _buildStatusCard(
                      'Has Local Token?', 
                      _notificationStatus!['hasLocalToken'],
                      color: hasLocalToken ? Colors.green : Colors.red,
                      details: "Indicates if NotificationService has an FCM token."
                    ),
                    _buildStatusCard(
                      'Notification Auth', 
                      _notificationStatus!['authorizationStatus'],
                      color: _notificationStatus!['authorizationStatus']?.contains('authorized') == true
                          ? Colors.green 
                          : (_notificationStatus!['authorizationStatus']?.contains('denied') == true ? Colors.red : Colors.orange),
                      details: "User's permission level for notifications."
                    ),
                    
                    if (_notificationStatus!['permissions'] is Map) ...[
                       Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4.0, bottom: 4.0),
                        child: Text('Granted Permissions:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      ),
                      ...(Map<String,dynamic>.from(_notificationStatus!['permissions'])).entries.map(
                        (entry) => _buildStatusCard(
                          '  ${entry.key.toUpperCase()}',
                          entry.value,
                          color: entry.value.toString().contains('enabled') ? Colors.green : Colors.orange,
                        ),
                      ).toList(),
                    ],
                    
                    if (_notificationStatus!['firestore'] is Map && (Map<String,dynamic>.from(_notificationStatus!['firestore'])).isNotEmpty) ...[
                       Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4.0, bottom: 4.0),
                        child: Text('Firestore Token Info:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      ),
                      ...(Map<String,dynamic>.from(_notificationStatus!['firestore'])).entries.map(
                        (entry) => _buildStatusCard(
                          '  ${entry.key}',
                          entry.value,
                          color: entry.key == 'hasCurrentDeviceToken' && entry.value == true
                              ? Colors.green 
                              : (entry.key == 'hasCurrentDeviceToken' && entry.value == false ? Colors.red : null),
                           details: entry.key == 'hasCurrentDeviceToken' 
                            ? "Is this device's FCM token in Firestore?"
                            : (entry.key == 'tokenCount' ? "Total tokens for this user in Firestore." : null),
                        ),
                      ).toList(),
                    ] else if (_notificationStatus!['firestore'] != null) ... [
                         _buildStatusCard(
                          'Firestore Info',
                          _notificationStatus!['firestore'].toString(),
                          details: "Details about tokens stored in Firestore for this user."
                        ),
                    ],
                     if (_notificationStatus!['error'] != null)
                      _buildStatusCard(
                        'Status Error', 
                        _notificationStatus!['error'],
                        color: Colors.red,
                        details: "An error occurred while fetching status."
                      ),
                  ] else ...[
                    Card(
                      elevation: 2,
                      color: Colors.red[50],
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(child: Text('Failed to load notification status. Check logs or try refreshing.')),
                          ],
                        ),
                      ),
                    ),
                  ],

                  _buildSectionTitle('🔧 Actions'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _reinitializeNotifications,
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text('Re-init Service'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _refreshFCMToken,
                        icon: const Icon(Icons.sync),
                        label: const Text('Refresh FCM Token'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      ),
                       ElevatedButton.icon(
                        onPressed: _isLoading ? null : _getAndLogCurrentToken,
                        icon: const Icon(Icons.token),
                        label: const Text('Get Local Token'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testNotification,
                        icon: const Icon(Icons.send_to_mobile),
                        label: const Text('Send Test Push'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _optOutFromNotifications,
                        icon: const Icon(Icons.notifications_off_outlined),
                        label: const Text('Opt Out (This Device)'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _optInToNotifications,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Opt In (This Device)'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                      ),
                    ],
                  ),

                  _buildSectionTitle('📝 Debug Log'),
                  Container(
                    width: double.infinity,
                    height: 300, // Increased height for more log visibility
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Scrollbar( // Added Scrollbar
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        reverse: true, // To keep latest logs at the bottom and visible
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          _debugLog.isEmpty ? 'No debug messages yet. Perform actions to see logs.' : _debugLog,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.black87
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.clear_all),
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _debugLog = '';
                              });
                            }
                          },
                          label: const Text('Clear Log'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
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
