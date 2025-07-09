// lib/services/notification_service.dart - With Cloud Logging
import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ai_device_manager/utils/cloud_logger.dart'; // Add this import
import 'package:flutter/services.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudLogger _cloudLogger = CloudLogger(); // Add this
  
  String? _fcmToken;
  String? _deviceIdentifier;
  StreamSubscription? _tokenRefreshSubscription;
  StreamSubscription? _messageSubscription;

  /// Initialize with cloud logging
  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      await _cloudLogger.logNotification('🔔 NotificationService initialization starting...');
      print('🔔 NotificationService initialization starting...');
      
      await _initializeDeviceIdentifier();
      
      if (Platform.isIOS) {
        await _setupiOSNotificationsWithProductionFix();
      } else {
        await _setupAndroidPermissions();
      }

      await _initializeLocalNotifications();
      await _setupFCMTokenWithEnhancedRetry();
      _setupMessageHandlers();
      
      _tokenRefreshSubscription = _fcm.onTokenRefresh.listen(_handleTokenRefresh);

      await _cloudLogger.logNotification('✅ NotificationService initialized successfully');
      print('✅ NotificationService initialized successfully');
    } catch (e) {
      await _cloudLogger.logError('❌ NotificationService initialization error', e);
      print('❌ NotificationService initialization error: $e');
    }
  }

  /// Enhanced iOS setup with cloud logging
  Future<void> _setupiOSNotificationsWithProductionFix() async {
    try {
      await _cloudLogger.logNotification('🍎 Setting up iOS notifications with production fix...');
      print('🍎 Setting up iOS notifications with production fix...');
      
      // Step 1: Check current authorization
      final initialSettings = await _fcm.getNotificationSettings();
      await _cloudLogger.logNotification('📋 Initial authorization: ${initialSettings.authorizationStatus}');
      print('📋 Initial authorization: ${initialSettings.authorizationStatus}');
      
      // Step 2: Configure FCM presentation options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await _cloudLogger.logNotification('✅ FCM foreground options configured');
      print('✅ FCM foreground options configured');
      
      // Step 3: Request permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      await _cloudLogger.logNotification('🔔 Permission result: ${settings.authorizationStatus}');
      print('🔔 Permission result: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await _cloudLogger.logError('❌ User denied notification permissions');
        return;
      }
      
      // Step 4: CRITICAL - Explicitly register for remote notifications
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _cloudLogger.logNotification('🚀 EXPLICITLY registering for remote notifications...');
        print('🚀 EXPLICITLY registering for remote notifications...');
        
        // Use method channel to call iOS registerForRemoteNotifications
        try {
          const platform = MethodChannel('flutter.io/notifications');
          await platform.invokeMethod('registerForRemoteNotifications');
          await _cloudLogger.logNotification('✅ Called iOS registerForRemoteNotifications via method channel');
          print('✅ Called iOS registerForRemoteNotifications via method channel');
        } catch (e) {
          await _cloudLogger.logError('❌ Method channel call failed', e);
          print('❌ Method channel call failed: $e');
        }
      }
      
      // Step 5: Wait longer for iOS processing
      await _cloudLogger.logNotification('⏳ Waiting for iOS to process registration...');
      await Future.delayed(const Duration(seconds: 5));
      
    } catch (e) {
      await _cloudLogger.logError('❌ iOS setup error', e);
      print('❌ iOS setup error: $e');
    }
  }

  /// Enhanced FCM token setup with cloud logging
  Future<void> _setupFCMTokenWithEnhancedRetry() async {
    const maxRetries = 8;
    const initialDelay = Duration(seconds: 2);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _cloudLogger.logNotification('🔄 FCM token attempt $attempt/$maxRetries...');
        print('🔄 FCM token attempt $attempt/$maxRetries...');
        
        if (Platform.isIOS) {
          // Check APNS token availability first
          final apnsToken = await _fcm.getAPNSToken();
          final apnsStatus = apnsToken != null ? "Available" : "Not Available";
          await _cloudLogger.logNotification('🍎 APNS Token status: $apnsStatus');
          print('🍎 APNS Token status: $apnsStatus');
          
          if (apnsToken == null) {
            if (attempt < maxRetries) {
              final delay = initialDelay * attempt;
              await _cloudLogger.logNotification('⏳ APNS token not ready, waiting ${delay.inSeconds}s for attempt ${attempt + 1}...');
              print('⏳ APNS token not ready, waiting ${delay.inSeconds}s for attempt ${attempt + 1}...');
              await Future.delayed(delay);
              continue;
            } else {
              await _cloudLogger.logError('❌ APNS token still unavailable after $maxRetries attempts');
              await _cloudLogger.logNotification('💡 This usually indicates: App ID lacks Push Notifications capability, Provisioning profile issue, Bundle ID mismatch, or Running on simulator');
              print('❌ APNS token still unavailable after $maxRetries attempts');
              break;
            }
          } else {
            await _cloudLogger.logNotification('✅ APNS token available, proceeding with FCM token...');
            print('✅ APNS token available, proceeding with FCM token...');
          }
        }
        
        // Attempt to get FCM token
        _fcmToken = await _fcm.getToken();
        
        if (_fcmToken != null && _fcmToken!.isNotEmpty) {
          await _cloudLogger.logNotification('✅ FCM token obtained successfully: ${_fcmToken!.substring(0, 20)}...');
          print('✅ FCM token obtained successfully: ${_fcmToken!.substring(0, 20)}...');
          await _addTokenToUserArray(_fcmToken!);
          return;
        } else {
          await _cloudLogger.logNotification('⚠️ FCM token is null/empty on attempt $attempt');
          print('⚠️ FCM token is null/empty on attempt $attempt');
        }
        
      } catch (e) {
        await _cloudLogger.logError('❌ FCM token attempt $attempt failed', e);
        print('❌ FCM token attempt $attempt failed: $e');
      }
      
      if (attempt < maxRetries) {
        final delay = initialDelay * attempt;
        await _cloudLogger.logNotification('⏳ Retrying in ${delay.inSeconds} seconds...');
        print('⏳ Retrying in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
    }
    
    await _cloudLogger.logError('❌ Failed to obtain FCM token after $maxRetries attempts');
    print('❌ Failed to obtain FCM token after $maxRetries attempts');
  }

  /// Enhanced status method with cloud logging
  Future<Map<String, dynamic>> getNotificationStatus() async {
    try {
      final settings = await _fcm.getNotificationSettings();
      final user = FirebaseAuth.instance.currentUser;
      
      Map<String, dynamic> firestoreInfo = {};
      if (user != null) {
        try {
          final userDoc = await _firestore.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final tokens = userData['fcmTokens'] ?? [];
            firestoreInfo = {
              'tokenCount': tokens.length,
              'hasCurrentDeviceToken': tokens.any((t) => t['deviceId'] == _deviceIdentifier),
            };
          }
        } catch (e) {
          firestoreInfo = {'error': 'Failed to fetch Firestore data: $e'};
        }
      }
      
      // Enhanced iOS debugging info
      Map<String, dynamic> result = {
        'platform': Platform.operatingSystem,
        'deviceId': _deviceIdentifier,
        'hasLocalToken': _fcmToken != null && _fcmToken!.isNotEmpty,
        'fcmTokenValue': _fcmToken ?? 'Not Available',
        'authorizationStatus': settings.authorizationStatus.toString(),
        'permissions': {
          'alert': settings.alert.toString(),
          'badge': settings.badge.toString(),
          'sound': settings.sound.toString(),
        },
        'firestore': firestoreInfo,
      };
      
      // iOS-specific debugging with cloud logging
      if (Platform.isIOS) {
        try {
          final apnsToken = await _fcm.getAPNSToken();
          result['apnsTokenStatus'] = apnsToken != null ? 'Available' : 'Not Available';
          
          // Log the current status to cloud
          await _cloudLogger.logNotification('📊 Status Check - APNS: ${result['apnsTokenStatus']}, FCM: ${result['hasLocalToken']}, Auth: ${settings.authorizationStatus}');
          
        } catch (e) {
          result['apnsTokenStatus'] = 'Error: $e';
          await _cloudLogger.logError('Error getting APNS token status', e);
        }
      }
      
      return result;
    } catch (e) {
      await _cloudLogger.logError('Error getting notification status', e);
      return {'error': e.toString()};
    }
  }

  /// Force refresh with cloud logging
  Future<void> refreshFCMToken() async {
    try {
      await _cloudLogger.logNotification('🔄 Force refreshing FCM token...');
      print('🔄 Force refreshing FCM token...');
      
      if (Platform.isIOS) {
        final settings = await _fcm.getNotificationSettings();
        await _cloudLogger.logNotification('📋 Current permissions before refresh: ${settings.authorizationStatus}');
        
        final apnsToken = await _fcm.getAPNSToken();
        await _cloudLogger.logNotification('🍎 APNS token before refresh: ${apnsToken != null ? "Available" : "Not Available"}');
      }
      
      // Delete current token
      await _fcm.deleteToken();
      await _cloudLogger.logNotification('🗑️ Deleted existing FCM token');
      print('🗑️ Deleted existing FCM token');
      
      // Wait longer on iOS
      await Future.delayed(Duration(seconds: Platform.isIOS ? 3 : 2));
      
      // Get new token with retry logic
      await _setupFCMTokenWithEnhancedRetry();
      
      await _cloudLogger.logNotification('✅ FCM token refresh attempt complete');
      print('✅ FCM token refresh attempt complete');
    } catch (e) {
      await _cloudLogger.logError('❌ Error refreshing FCM token', e);
      print('❌ Error refreshing FCM token: $e');
    }
  }

  /// Upload logs when debugging
  Future<void> uploadDebugLogs() async {
    await _cloudLogger.flushNow();
  }

  // ... rest of your existing methods (keeping them the same, just adding key logging points)
  
  Future<void> _initializeDeviceIdentifier() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceIdentifier = iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceIdentifier = androidInfo.id ?? 'android_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        _deviceIdentifier = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      await _cloudLogger.logNotification('📱 Device identifier: $_deviceIdentifier');
      print('📱 Device identifier: $_deviceIdentifier');
    } catch (e) {
      await _cloudLogger.logError('⚠️ Error getting device identifier', e);
      print('⚠️ Error getting device identifier: $e');
      _deviceIdentifier = '${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _setupAndroidPermissions() async {
    try {
      print('🤖 Setting up Android permissions...');
      
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('🔔 Android notification permission: ${settings.authorizationStatus}');
      
    } catch (e) {
      print('❌ Error setting up Android permissions: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
  }

  Future<void> _addTokenToUserArray(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await _cloudLogger.logError('❌ No authenticated user for token storage');
        print('❌ No authenticated user for token storage');
        return;
      }
      
      await _cloudLogger.logNotification('💾 Saving FCM token to Firestore...');
      print('💾 Saving FCM token to Firestore...');

      final userDocRef = _firestore.collection('users').doc(user.uid);
      
      final tokenData = {
        'token': token,
        'deviceId': _deviceIdentifier,
        'platform': Platform.operatingSystem,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        'isActive': true,
      };

      final userDoc = await userDocRef.get();
      
      if (!userDoc.exists) {
        await userDocRef.set({
          'fcmTokens': [tokenData],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final userData = userDoc.data() as Map<String, dynamic>;
        List<dynamic> existingTokens = userData['fcmTokens'] ?? [];
        
        existingTokens.removeWhere((tokenObj) => 
          tokenObj['deviceId'] == _deviceIdentifier ||
          tokenObj['token'] == token
        );
        
        existingTokens.add(tokenData);
        
        await userDocRef.update({
          'fcmTokens': existingTokens,
          'fcmTokenUpdated': FieldValue.serverTimestamp(),
        });
      }
      
      await _cloudLogger.logNotification('✅ FCM token saved to Firestore successfully');
      print('✅ FCM token saved to Firestore successfully');
      
    } catch (e) {
      await _cloudLogger.logError('❌ Error saving FCM token', e);
      print('❌ Error saving FCM token: $e');
    }
  }

  Future<void> _handleTokenRefresh(String newToken) async {
    await _cloudLogger.logNotification('🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
    print('🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
    _fcmToken = newToken;
    await _addTokenToUserArray(newToken);
  }

  void _setupMessageHandlers() {
    _messageSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
    _checkInitialMessage();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground message: ${message.messageId}');
    
    final notification = message.notification;
    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'AI Detection Alert',
        body: notification.body ?? 'Detection occurred',
        payload: message.data,
      );
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ai_detection_channel',
      'AI Detection Alerts',
      channelDescription: 'Notifications for AI detection events',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload?.toString(),
    );
  }

  void _handleNotificationTap(NotificationResponse response) {
    print('👆 Notification tapped: ${response.payload}');
  }

  void _handleBackgroundMessageTap(RemoteMessage message) {
    print('👆 Background notification tapped: ${message.data}');
  }

  Future<void> _checkInitialMessage() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('🚀 App opened from notification: ${initialMessage.data}');
    }
  }

  /// Check if current device is enabled for notifications for a specific camera device
  Future<bool> isDeviceNotificationEnabled(String deviceId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _fcmToken == null) return false;

      final deviceDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .get();

      if (!deviceDoc.exists) return false;

      final deviceData = deviceDoc.data() as Map<String, dynamic>;
      final enabledTokens = List<String>.from(deviceData['enabledFCMTokens'] ?? []);
      
      return enabledTokens.contains(_fcmToken);
    } catch (e) {
      await _cloudLogger.logError('Error checking device notification status', e);
      return false;
    }
  }

  /// Toggle notification for current device for a specific camera device
  Future<bool> toggleDeviceNotification(String deviceId, bool enable) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _fcmToken == null) {
        await _cloudLogger.logError('No user or FCM token for device notification toggle');
        return false;
      }

      await _cloudLogger.logNotification('🔔 Toggling device notification: $deviceId = $enable');

      final deviceRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId);

      await _firestore.runTransaction((transaction) async {
        final deviceDoc = await transaction.get(deviceRef);
        
        if (!deviceDoc.exists) {
          throw Exception('Device not found');
        }

        final deviceData = deviceDoc.data() as Map<String, dynamic>;
        List<String> enabledTokens = List<String>.from(deviceData['enabledFCMTokens'] ?? []);

        if (enable) {
          // Add token if not already present
          if (!enabledTokens.contains(_fcmToken)) {
            enabledTokens.add(_fcmToken!);
          }
        } else {
          // Remove token
          enabledTokens.removeWhere((token) => token == _fcmToken);
        }

        transaction.update(deviceRef, {
          'enabledFCMTokens': enabledTokens,
          'lastNotificationUpdate': FieldValue.serverTimestamp(),
        });
      });

      await _cloudLogger.logNotification('✅ Device notification toggled successfully');
      return true;

    } catch (e) {
      await _cloudLogger.logError('Error toggling device notification', e);
      return false;
    }
  }

  /// Get notification status for multiple devices at once
  Future<Map<String, bool>> getDeviceNotificationStatuses(List<String> deviceIds) async {
    final Map<String, bool> statusMap = {};
    
    if (_fcmToken == null) {
      // Return all false if no token
      for (final deviceId in deviceIds) {
        statusMap[deviceId] = false;
      }
      return statusMap;
    }
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return statusMap;

      // Get all devices in one query if possible, otherwise individual queries
      for (final deviceId in deviceIds) {
        final deviceDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc(deviceId)
            .get();

        if (deviceDoc.exists) {
          final deviceData = deviceDoc.data() as Map<String, dynamic>;
          final enabledTokens = List<String>.from(deviceData['enabledFCMTokens'] ?? []);
          statusMap[deviceId] = enabledTokens.contains(_fcmToken);
        } else {
          statusMap[deviceId] = false;
        }
      }
    } catch (e) {
      await _cloudLogger.logError('Error getting device notification statuses', e);
      // Return all false on error
      for (final deviceId in deviceIds) {
        statusMap[deviceId] = false;
      }
    }
    
    return statusMap;
  }

  Future<bool> optOutFromNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDocRef = _firestore.collection('users').doc(user.uid);
      
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userDocRef);
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          List<dynamic> existingTokens = userData['fcmTokens'] ?? [];
          
          existingTokens.removeWhere((tokenObj) => 
            tokenObj['deviceId'] == _deviceIdentifier
          );
          
          transaction.update(userDocRef, {
            'fcmTokens': existingTokens,
            'fcmTokenUpdated': FieldValue.serverTimestamp(),
          });
        }
      });
      
      print('✅ Opted out from notifications');
      return true;
      
    } catch (e) {
      print('❌ Error opting out: $e');
      return false;
    }
  }

  Future<bool> optInToNotifications() async {
    if (_fcmToken != null) {
      await _addTokenToUserArray(_fcmToken!);
      return true;
    } else {
      await _setupFCMTokenWithEnhancedRetry();
      return _fcmToken != null;
    }
  }

  Future<void> debugFCMToken() async {
    try {
      await _cloudLogger.logNotification('=== 🔍 Enhanced FCM Debug ===');
      print('=== 🔍 Enhanced FCM Debug ===');
      await _cloudLogger.logNotification('📱 Device: $_deviceIdentifier');
      await _cloudLogger.logNotification('🖥️ Platform: ${Platform.operatingSystem}');
      print('📱 Device: $_deviceIdentifier');
      print('🖥️ Platform: ${Platform.operatingSystem}');
      
      if (Platform.isIOS) {
        final apnsToken = await _fcm.getAPNSToken();
        final apnsStatus = apnsToken != null ? "✅ Available (${apnsToken.length} chars)" : "❌ Not Available";
        await _cloudLogger.logNotification('🍎 APNS Token: $apnsStatus');
        print('🍎 APNS Token: $apnsStatus');
      }
      
      final fcmToken = await _fcm.getToken();
      final fcmStatus = fcmToken != null ? "✅ Available (${fcmToken.length} chars)" : "❌ Not Available";
      await _cloudLogger.logNotification('🔑 FCM Token: $fcmStatus');
      print('🔑 FCM Token: $fcmStatus');
      
      final settings = await _fcm.getNotificationSettings();
      await _cloudLogger.logNotification('🔔 Authorization: ${settings.authorizationStatus}');
      await _cloudLogger.logNotification('🚨 Alert: ${settings.alert}');
      await _cloudLogger.logNotification('🔢 Badge: ${settings.badge}');
      await _cloudLogger.logNotification('🔊 Sound: ${settings.sound}');
      
      print('🔔 Authorization: ${settings.authorizationStatus}');
      print('🚨 Alert: ${settings.alert}');
      print('🔢 Badge: ${settings.badge}');
      print('🔊 Sound: ${settings.sound}');
      
      // Upload logs immediately after debug
      await _cloudLogger.flushNow();
      
      print('=== End Enhanced Debug ===');
    } catch (e) {
      await _cloudLogger.logError('❌ Debug error', e);
      print('❌ Debug error: $e');
    }
  }

  String? get fcmToken => _fcmToken;
  String? get deviceIdentifier => _deviceIdentifier;

  Future<bool> isNotificationSetupComplete() async {
    if (kIsWeb) return false;
    
    try {
      final settings = await _fcm.getNotificationSettings();
      final hasPermission = settings.authorizationStatus == AuthorizationStatus.authorized ||
                           settings.authorizationStatus == AuthorizationStatus.provisional;
      final hasToken = _fcmToken != null && _fcmToken!.isNotEmpty;
      
      return hasPermission && hasToken;
    } catch (e) {
      print('❌ Error checking setup: $e');
      return false;
    }
  }

  void dispose() {
    // Upload any remaining logs before disposing
    _cloudLogger.uploadOnAppPause();
    _tokenRefreshSubscription?.cancel();
    _messageSubscription?.cancel();
  }
}