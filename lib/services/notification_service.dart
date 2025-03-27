import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Data classes for different notification types
class UploadProgress {
  final String title;
  final int totalFiles;
  final double progress;
  final String notificationId;

  UploadProgress({
    required this.title,
    required this.totalFiles,
    required this.progress,
    required this.notificationId,
  });
}

class ImageGenerationProgress {
  final String deviceId;
  final int totalImages;
  final int completedImages;

  ImageGenerationProgress({
    required this.deviceId,
    required this.totalImages,
    required this.completedImages,
  });
}

class TrainingStatus {
  final String deviceId;
  final String status;
  final double? accuracy;
  final String? error;

  TrainingStatus({
    required this.deviceId,
    required this.status,
    this.accuracy,
    this.error,
  });
}

class ClassAction {
  final String className;
  final double confidence;
  final String actionType;
  final String deviceId;

  ClassAction({
    required this.className,
    required this.confidence,
    required this.actionType,
    required this.deviceId,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Stream controllers for different notification types
  final _uploadProgressController = StreamController<UploadProgress>.broadcast();
  final _trainingStatusController = StreamController<TrainingStatus>.broadcast();
  final _classActionController = StreamController<ClassAction>.broadcast();
  final _imageGenerationProgressController = StreamController<ImageGenerationProgress>.broadcast();

  
  // Stream getters
  Stream<UploadProgress> get uploadProgress => _uploadProgressController.stream;
  Stream<TrainingStatus> get trainingStatus => _trainingStatusController.stream;
  Stream<ClassAction> get classActions => _classActionController.stream;
  Stream<ImageGenerationProgress> get imageGenerationProgress => _imageGenerationProgressController.stream;

  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();

  Future<void> initialize() async {
    if (kIsWeb) return; // Skip initialization on web
    // Request notification permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token for this device
    String? token = await _fcm.getToken();
    print('FCM Token: $token');

    // Initialize local notifications
    const initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleLocalNotificationTap(response);
      },
    );

    // Handle FCM messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundNotificationTap);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final notificationType = data['type'];

    switch (notificationType) {
      // Add this case
      case 'image_generation_progress':
        _imageGenerationProgressController.add(ImageGenerationProgress(
          deviceId: data['device_id'],
          totalImages: int.parse(data['total']),
          completedImages: int.parse(data['completed']),
        ));
        
        // Show progress notification
        await showUploadProgress(
          title: 'Generating Training Images',
          totalFiles: int.parse(data['total']),
          notificationId: 'gen_${data['device_id']}',
          progress: int.parse(data['completed']) / int.parse(data['total']),
        );
        
        // Show completion notification if done
        if (data['completed'] == data['total']) {
          await completeUploadNotification(
            notificationId: 'gen_${data['device_id']}',
            success: true,
            message: 'Successfully generated training images'
          );
        }
        break;
      case 'class_action':
        _classActionController.add(ClassAction(
          className: data['className'],
          confidence: double.parse(data['confidence']),
          actionType: data['actionType'],
          deviceId: data['deviceId'],
        ));
        break;
      case 'training_complete':
        _trainingStatusController.add(TrainingStatus(
          deviceId: data['deviceId'],
          status: 'complete',
          accuracy: double.parse(data['accuracy']),
        ));
        break;
      default:
        // Show generic notification
        await showNotification(
          title: message.notification?.title ?? 'New Notification',
          body: message.notification?.body ?? '',
          payload: message.data.toString(),
        );
    }
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    print('Local notification tapped: ${response.payload}');
  }

  void _handleBackgroundNotificationTap(RemoteMessage message) {
    print('Background notification tapped: ${message.messageId}');
  }

  // Show basic notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ai_device_manager_channel',
      'AI Device Manager Notifications',
      channelDescription: 'Notifications from AI Device Manager',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Upload progress notifications
  Future<void> showUploadProgress({
    required String title,
    required int totalFiles,
    required String notificationId,
    double progress = 0.0,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'upload_progress_channel',
      'Upload Progress',
      channelDescription: 'Shows progress of file uploads',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: (progress * 100).toInt(),
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      channelShowBadge: false,
    );

    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      int.parse(notificationId) % 100000,
      title,
      '${(progress * 100).toInt()}% complete',
      details,
    );
  }

  Future<void> updateUploadProgress({
    required String notificationId,
    required double progress,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'upload_progress_channel',
      'Upload Progress',
      channelDescription: 'Shows progress of file uploads',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: (progress * 100).toInt(),
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      channelShowBadge: false,
    );

    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      int.parse(notificationId) % 100000,
      'Uploading Files',
      '${(progress * 100).toInt()}% complete',
      details,
    );
  }

  Future<void> completeUploadNotification({
    required String notificationId,
    required bool success,
    String? message,
  }) async {
    // Cancel the progress notification
    await _localNotifications.cancel(int.parse(notificationId) % 100000);
    
    // Show completion notification
    await showNotification(
      title: success ? 'Upload Complete' : 'Upload Failed',
      body: message ?? (success ? 'Files uploaded successfully' : 'Failed to upload files'),
    );
  }

  // Training notifications
  Future<void> showTrainingProgress({
    required String deviceId,
    required String status,
    int? estimatedSeconds,
  }) async {
    _trainingStatusController.add(TrainingStatus(
      deviceId: deviceId,
      status: status,
    ));

    await showNotification(
      title: 'Training Progress',
      body: status,
      payload: 'training_$deviceId',
    );
  }

  Future<void> completeTraining({
    required String deviceId,
    required double accuracy,
  }) async {
    final status = TrainingStatus(
      deviceId: deviceId,
      status: 'complete',
      accuracy: accuracy,
    );
    _trainingStatusController.add(status);

    await showNotification(
      title: 'Training Complete',
      body: 'Model achieved ${(accuracy * 100).toStringAsFixed(1)}% accuracy',
      payload: 'training_complete_$deviceId',
    );
  }

  Future<void> trainingError({
    required String deviceId,
    required String error,
  }) async {
    final status = TrainingStatus(
      deviceId: deviceId,
      status: 'error',
      error: error,
    );
    _trainingStatusController.add(status);

    await showNotification(
      title: 'Training Error',
      body: 'Error during training: $error',
      payload: 'training_error_$deviceId',
    );
  }

  // Class action notifications
  Future<void> showClassActionNotification({
    required String className,
    required double confidence,
    required String actionType,
    required String deviceId,
  }) async {
    final action = ClassAction(
      className: className,
      confidence: confidence,
      actionType: actionType,
      deviceId: deviceId,
    );
    
    _classActionController.add(action);

    await showNotification(
      title: 'Action Required',
      body: 'Class $className detected with ${(confidence * 100).toStringAsFixed(1)}% confidence',
      payload: 'class_action_${deviceId}_$className',
    );
  }

  void dispose() {
    _uploadProgressController.close();
    _trainingStatusController.close();
    _classActionController.close();
    _imageGenerationProgressController.close();
  }
}