// lib/services/notification_service.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _fcmToken;
  StreamSubscription? _tokenRefreshSubscription;
  StreamSubscription? _messageSubscription;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (kIsWeb) return; // Skip for web platform

    try {
      // iOS-specific: Request provisional authorization first
      if (Platform.isIOS) {
        final provisionalSettings = await _fcm.requestPermission(
          provisional: true,
        );
        print('iOS provisional authorization status: ${provisionalSettings.authorizationStatus}');
      }
      
      // Then request full permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        if (settings.authorizationStatus == AuthorizationStatus.provisional) {
          print('User granted provisional permission');
        } else {
          print('User declined or has not accepted permission');
          return;
        }
      }

      // iOS-specific: Set foreground notification presentation options
      if (Platform.isIOS) {
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Initialize local notifications
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

      // Get and save FCM token - add delay for iOS
      if (Platform.isIOS) {
        await Future.delayed(const Duration(seconds: 1));
      }
      
      await _setupFCMToken();

      // Set up message handlers
      _setupMessageHandlers();

      // Listen for token refresh
      _tokenRefreshSubscription = _fcm.onTokenRefresh.listen(_updateFCMToken);

      print('NotificationService initialized successfully');
    } catch (e) {
      print('Error initializing NotificationService: $e');
    }
  }

  /// Setup FCM token and save to Firestore
  Future<void> _setupFCMToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      if (_fcmToken != null) {
        await _updateFCMToken(_fcmToken!);
      } else {
        print('FCM token is null - this might be a simulator or token generation issue');
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  /// Update FCM token in Firestore
  Future<void> _updateFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'fcmTokenUpdated': FieldValue.serverTimestamp(),
          'platform': Platform.isIOS ? 'ios' : 'android',
        }, SetOptions(merge: true));
        
        _fcmToken = token;
        print('FCM token updated: ${token.substring(0, 10)}...');
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
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
    print('Foreground message received: ${message.messageId}');
    
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
    print('Notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen based on payload
    // Example: Navigator.pushNamed(context, '/device_dashboard', arguments: deviceId);
  }

  /// Handle background message tap
  void _handleBackgroundMessageTap(RemoteMessage message) {
    print('Background notification tapped: ${message.data}');
    // TODO: Navigate to appropriate screen
  }

  /// Check if app was opened from notification
  Future<void> _checkInitialMessage() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('App opened from notification: ${initialMessage.data}');
      // TODO: Navigate to appropriate screen
    }
  }

  /// Debug FCM token generation
  Future<void> debugFCMToken() async {
    try {
      print('=== FCM Token Debug ===');
      
      // Check APNS token (iOS only)
      if (Platform.isIOS) {
        final apnsToken = await _fcm.getAPNSToken();
        print('APNS Token: ${apnsToken ?? "null"}');
      }
      
      // Get FCM token
      final fcmToken = await _fcm.getToken();
      print('FCM Token: ${fcmToken ?? "null"}');
      
      // Check notification settings
      final settings = await _fcm.getNotificationSettings();
      print('Authorization Status: ${settings.authorizationStatus}');
      print('Alert: ${settings.alert}');
      print('Badge: ${settings.badge}');
      print('Sound: ${settings.sound}');
      
      // Check if we're on a simulator
      if (Platform.isIOS) {
        final isSimulator = await _checkIfSimulator();
        print('Is Simulator: $isSimulator');
      }
      
      print('=== End Debug ===');
    } catch (e) {
      print('Error in debugFCMToken: $e');
    }
  }

  /// Check if running on iOS simulator
  Future<bool> _checkIfSimulator() async {
    // On iOS simulator, certain features like push notifications won't work
    // This is a simple check - FCM token will be null on simulator
    return Platform.isIOS && _fcmToken == null;
  }

  /// Manually refresh FCM token
  Future<void> refreshFCMToken() async {
    try {
      print('Manually refreshing FCM token...');
      
      // Delete current token to force refresh
      await _fcm.deleteToken();
      
      // Wait a bit
      await Future.delayed(const Duration(seconds: 1));
      
      // Get new token
      await _setupFCMToken();
      
      print('FCM token refresh complete');
    } catch (e) {
      print('Error refreshing FCM token: $e');
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

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
      print('Error checking notification setup: $e');
      return false;
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
  print('Background message received: ${message.messageId}');
  // Handle background message if needed
}