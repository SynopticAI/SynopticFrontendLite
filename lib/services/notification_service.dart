// lib/services/notification_service.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _fcmToken;
  String? _deviceIdentifier;
  StreamSubscription? _tokenRefreshSubscription;
  StreamSubscription? _messageSubscription;

  /// Initialize the notification service with enhanced iOS support
  Future<void> initialize() async {
    if (kIsWeb) return; // Skip for web platform

    try {
      print('🔔 Starting NotificationService initialization...');
      
      // Get device identifier first
      await _initializeDeviceIdentifier();
      
      // iOS-specific: Request permissions with proper flow
      if (Platform.isIOS) {
        await _setupiOSPermissions();
      } else {
        await _setupAndroidPermissions();
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Setup FCM token with platform-specific handling
      await _setupFCMTokenWithRetry();

      // Set up message handlers
      _setupMessageHandlers();

      // Listen for token refresh
      _tokenRefreshSubscription = _fcm.onTokenRefresh.listen(_handleTokenRefresh);

      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ Error initializing NotificationService: $e');
    }
  }

  /// Initialize device identifier for token management
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
      
      print('📱 Device identifier: $_deviceIdentifier');
    } catch (e) {
      print('⚠️ Error getting device identifier: $e');
      _deviceIdentifier = '${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Setup iOS-specific permissions with proper timing
  Future<void> _setupiOSPermissions() async {
    try {
      print('🍎 Setting up iOS permissions...');
      
      // Step 1: Configure Firebase Messaging for iOS
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // Step 2: Request provisional permission first (iOS 12+)
      NotificationSettings provisionalSettings;
      try {
        provisionalSettings = await _fcm.requestPermission(
          provisional: true,
          alert: false,
          badge: false,
          sound: false,
        );
        print('📋 iOS provisional permission: ${provisionalSettings.authorizationStatus}');
      } catch (e) {
        print('⚠️ Provisional permission failed: $e');
        provisionalSettings = await _fcm.getNotificationSettings();
      }
      
      // Step 3: Wait a moment for iOS to process
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Step 4: Request full permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      print('🔔 iOS notification permission: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('❌ User denied notification permissions');
        return;
      }
      
      // Step 5: Additional delay for APNS token generation
      await Future.delayed(const Duration(seconds: 1));
      
    } catch (e) {
      print('❌ Error setting up iOS permissions: $e');
    }
  }

  /// Setup Android permissions
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

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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

  /// Setup FCM token with retry logic for iOS
  Future<void> _setupFCMTokenWithRetry() async {
    const maxRetries = 5;
    const baseDelay = Duration(seconds: 2);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🔄 FCM token attempt $attempt/$maxRetries...');
        
        // For iOS, check APNS token first
        if (Platform.isIOS) {
          final apnsToken = await _fcm.getAPNSToken();
          print('📱 APNS Token available: ${apnsToken != null}');
          
          if (apnsToken == null && attempt < maxRetries) {
            print('⏳ APNS token not ready, waiting...');
            await Future.delayed(baseDelay * attempt);
            continue;
          }
        }
        
        // Get FCM token
        _fcmToken = await _fcm.getToken();
        
        if (_fcmToken != null) {
          print('✅ FCM token obtained: ${_fcmToken!.substring(0, 20)}...');
          await _addTokenToUserArray(_fcmToken!);
          return;
        } else {
          print('⚠️ FCM token is null on attempt $attempt');
        }
        
      } catch (e) {
        print('❌ FCM token attempt $attempt failed: $e');
      }
      
      if (attempt < maxRetries) {
        final delay = baseDelay * attempt;
        print('⏳ Retrying in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
    }
    
    print('❌ Failed to get FCM token after $maxRetries attempts');
  }

  /// Add FCM token to user's token array in Firestore
  Future<void> _addTokenToUserArray(String token) async {
    print('🔄 Attempting to save FCM token to Firestore...');
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user for token storage');
        return;
      }
      
      print('✅ User authenticated: ${user.uid}');
      print('🔑 Token to save: ${token.substring(0, 20)}...');
      print('📱 Device ID: $_deviceIdentifier');

      final userDocRef = _firestore.collection('users').doc(user.uid);
      
      // Create token object with metadata
      final tokenData = {
        'token': token,
        'deviceId': _deviceIdentifier,
        'platform': Platform.operatingSystem,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        'isActive': true,
      };

      print('💾 Saving token data: $tokenData');

      // Use simple set instead of transaction for debugging
      final userDoc = await userDocRef.get();
      
      if (!userDoc.exists) {
        print('📝 Creating new user document');
        await userDocRef.set({
          'fcmTokens': [tokenData],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        print('📝 Updating existing user document');
        final userData = userDoc.data() as Map<String, dynamic>;
        List<dynamic> existingTokens = userData['fcmTokens'] ?? [];
        
        // Remove existing tokens for this device
        existingTokens.removeWhere((tokenObj) => 
          tokenObj['deviceId'] == _deviceIdentifier ||
          tokenObj['token'] == token
        );
        
        // Add the new token
        existingTokens.add(tokenData);
        
        await userDocRef.update({
          'fcmTokens': existingTokens,
          'fcmTokenUpdated': FieldValue.serverTimestamp(),
        });
      }
      
      print('✅ FCM token successfully saved to Firestore');
      
    } catch (e) {
      print('❌ DETAILED ERROR saving FCM token: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('❌ Firebase error code: ${e.code}');
        print('❌ Firebase error message: ${e.message}');
      }
    }
  }

  /// Handle token refresh
  Future<void> _handleTokenRefresh(String newToken) async {
    print('🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
    _fcmToken = newToken;
    await _addTokenToUserArray(newToken);
  }

  /// Setup message handlers for foreground and background
  void _setupMessageHandlers() {
    // Foreground messages
    _messageSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
    
    // Check if app was opened from a terminated state
    _checkInitialMessage();
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground message received: ${message.messageId}');
    
    // Extract notification data
    final notification = message.notification;
    final data = message.data;
    
    if (notification != null) {
      // Show local notification for foreground messages
      await _showLocalNotification(
        title: notification.title ?? 'AI Detection Alert',
        body: notification.body ?? 'Detection occurred',
        payload: data,
      );
    }
  }

  /// Show local notification
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
      payload: payload != null ? payload.toString() : null,
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(NotificationResponse response) {
    print('👆 Notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen based on payload
  }

  /// Handle background message tap
  void _handleBackgroundMessageTap(RemoteMessage message) {
    print('👆 Background notification tapped: ${message.data}');
    // TODO: Navigate to appropriate screen
  }

  /// Check if app was opened from notification
  Future<void> _checkInitialMessage() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('🚀 App opened from notification: ${initialMessage.data}');
      // TODO: Navigate to appropriate screen
    }
  }

  /// Remove current device's FCM token from user's array (opt-out functionality)
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
          
          // Remove tokens for this device
          existingTokens.removeWhere((tokenObj) => 
            tokenObj['deviceId'] == _deviceIdentifier
          );
          
          transaction.update(userDocRef, {
            'fcmTokens': existingTokens,
            'fcmTokenUpdated': FieldValue.serverTimestamp(),
          });
        }
      });
      
      print('✅ Opted out from notifications for device: $_deviceIdentifier');
      return true;
      
    } catch (e) {
      print('❌ Error opting out from notifications: $e');
      return false;
    }
  }

  /// Re-enable notifications for this device (opt-in functionality)
  Future<bool> optInToNotifications() async {
    if (_fcmToken != null) {
      await _addTokenToUserArray(_fcmToken!);
      return true;
    } else {
      // Try to get token again
      await _setupFCMTokenWithRetry();
      return _fcmToken != null;
    }
  }

  /// Debug FCM token generation with enhanced iOS info
  Future<void> debugFCMToken() async {
    try {
      print('=== 🔍 FCM Token Debug ===');
      
      // Check device info
      print('📱 Device ID: $_deviceIdentifier');
      print('🖥️ Platform: ${Platform.operatingSystem}');
      
      // Check APNS token (iOS only)
      if (Platform.isIOS) {
        final apnsToken = await _fcm.getAPNSToken();
        print('📱 APNS Token: ${apnsToken != null ? "${apnsToken.substring(0, 20)}..." : "null"}');
      }
      
      // Get FCM token
      final fcmToken = await _fcm.getToken();
      print('🔑 FCM Token: ${fcmToken != null ? "${fcmToken.substring(0, 20)}..." : "null"}');
      
      // Check notification settings
      final settings = await _fcm.getNotificationSettings();
      print('🔔 Authorization Status: ${settings.authorizationStatus}');
      print('🚨 Alert: ${settings.alert}');
      print('🔢 Badge: ${settings.badge}');
      print('🔊 Sound: ${settings.sound}');
      
      // Check user's token array in Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final tokens = userData['fcmTokens'] ?? [];
          print('🗄️ Tokens in Firestore: ${tokens.length}');
          for (int i = 0; i < tokens.length; i++) {
            final token = tokens[i];
            print('  Token $i: Device ${token['deviceId']}, Platform ${token['platform']}');
          }
        } else {
          print('📄 No user document found in Firestore');
        }
      }
      
      print('=== End Debug ===');
    } catch (e) {
      print('❌ Error in debugFCMToken: $e');
    }
  }

  /// Manually refresh FCM token
  Future<void> refreshFCMToken() async {
    try {
      print('🔄 Manually refreshing FCM token...');
      
      // Delete current token to force refresh
      await _fcm.deleteToken();
      
      // Wait a bit
      await Future.delayed(const Duration(seconds: 2));
      
      // Get new token with retry logic
      await _setupFCMTokenWithRetry();
      
      print('✅ FCM token refresh complete');
    } catch (e) {
      print('❌ Error refreshing FCM token: $e');
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Get current device identifier
  String? get deviceIdentifier => _deviceIdentifier;

  /// Check if notifications are properly set up
  Future<bool> isNotificationSetupComplete() async {
    if (kIsWeb) return false;
    
    try {
      final settings = await _fcm.getNotificationSettings();
      final hasPermission = settings.authorizationStatus == AuthorizationStatus.authorized ||
                           settings.authorizationStatus == AuthorizationStatus.provisional;
      final hasToken = _fcmToken != null;
      
      return hasPermission && hasToken;
    } catch (e) {
      print('❌ Error checking notification setup: $e');
      return false;
    }
  }

  /// Get notification setup status for debugging
  Future<Map<String, dynamic>> getNotificationStatus() async {
    try {
      final settings = await _fcm.getNotificationSettings();
      final user = FirebaseAuth.instance.currentUser;
      
      Map<String, dynamic> firestoreInfo = {};
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final tokens = userData['fcmTokens'] ?? [];
          firestoreInfo = {
            'tokenCount': tokens.length,
            'hasCurrentDeviceToken': tokens.any((t) => t['deviceId'] == _deviceIdentifier),
          };
        }
      }
      
      return {
        'platform': Platform.operatingSystem,
        'deviceId': _deviceIdentifier,
        'hasLocalToken': _fcmToken != null,
        'authorizationStatus': settings.authorizationStatus.toString(),
        'permissions': {
          'alert': settings.alert.toString(),
          'badge': settings.badge.toString(),
          'sound': settings.sound.toString(),
        },
        'firestore': firestoreInfo,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Dispose of resources
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _messageSubscription?.cancel();
  }
}

/// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message received: ${message.messageId}');
  // Handle background message if needed
}