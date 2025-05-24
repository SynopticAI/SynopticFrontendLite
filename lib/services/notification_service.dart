// lib/services/notification_service.dart
import 'dart:async';
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
      // Request notification permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('User declined or has not accepted permission');
        return;
      }

      // Initialize local notifications for Android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationTap,
      );

      // Get and save FCM token
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

    const iosDetails = DarwinNotificationDetails();
    
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

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

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