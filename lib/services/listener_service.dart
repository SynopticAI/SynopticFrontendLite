import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A service to manage Firestore listeners for various action types
class ListenerService {
  // Singleton pattern
  static final ListenerService _instance = ListenerService._internal();
  factory ListenerService() => _instance;
  ListenerService._internal();

  // Store active subscriptions
  final Map<String, StreamSubscription<DocumentSnapshot>> _subscriptions = {};
  
  // Store callback handlers
  final Map<String, Function(Map<String, dynamic>)> _handlers = {};

  // Action-specific descriptions
  static String getActionDescription(String action) {
    switch (action) {
      case 'generateData':
        return 'Generating images';
      case 'train':
        return 'Training started';
      case 'changeModelType':
        return 'Model adjusted';
      case 'createDeviceIcon':
        return 'Icon generated';
      default:
        return 'Processing';
    }
  }

  /// Start listening to a specific action's progress
  void startListener({
    required String userId,
    required String deviceId,
    required String messageTimestamp,
    required String action,
    required Function(Map<String, dynamic>) onUpdate,
    required Function() onComplete,
  }) {
    // Extract the base timestamp without any suffix (e.g., "12345_2" -> "12345")
    final baseTimestamp = messageTimestamp.split('_').first;
    
    // The full document path for this action
    //final docPath = "users/$userId/devices/$deviceId/assistant/$baseTimestamp";
    // Use the full messageTimestamp for the document path
final docPath = "users/$userId/devices/$deviceId/assistant/$messageTimestamp";
    
    // Use the original messageTimestamp as the key to allow multiple listeners with different suffixes
    _handlers[messageTimestamp] = onUpdate;

    final stream = FirebaseFirestore.instance.doc(docPath).snapshots();
    final subscription = stream.listen((DocumentSnapshot snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'processing';

      // Build base update data
      Map<String, dynamic> updateData = {
        'status': status,
        'action': action,
        'actionDescription': getActionDescription(action),
        'timestamp': messageTimestamp,
        if (data.containsKey('progress')) 'progress': data['progress'],
        if (data.containsKey('error')) 'error': data['error'],
      };

      // Add action-specific fields
      switch (action) {
        case 'generateData':
          if (data.containsKey('imageUrls')) {
            updateData['imageUrls'] = data['imageUrls'];
          }
          break;
        case 'createDeviceIcon':  // Add this case
          if (data.containsKey('imageUrls')) {
            updateData['imageUrls'] = data['imageUrls'];
          }
          break;
        case 'train':
          if (data.containsKey('accuracy')) {
            updateData['accuracy'] = data['accuracy'];
          }
          if (data.containsKey('loss')) {
            updateData['loss'] = data['loss'];
          }
          break;
        case 'changeModelType':
          if (data.containsKey('textArray')) {
            updateData['textArray'] = data['textArray'];
          }
          break;
        // Add more action-specific field handling
      }

      // Always include textArray if it exists
      if (data.containsKey('textArray')) {
        updateData['textArray'] = data['textArray'];
      }

      onUpdate(updateData);

      if (status == 'actionComplete' || status == 'error') {
        onComplete();
        stopListener(messageTimestamp);
      }
    });

    _subscriptions[messageTimestamp] = subscription;
  }

  /// Stop and cleanup a specific listener
  void stopListener(String messageTimestamp) {
    if (_subscriptions.containsKey(messageTimestamp)) {
      _subscriptions[messageTimestamp]?.cancel();
      _subscriptions.remove(messageTimestamp);
      _handlers.remove(messageTimestamp);
    }
  }

  /// Stop all active listeners
  void dispose() {
    for (var subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _handlers.clear();
  }

  /// Calculate progress value (0.0 to 1.0)
  static double calculateProgressValue(String? progress) {
    if (progress == null) return 0.0;
    try {
      final parts = progress.split('/');
      if (parts.length == 2) {
        final current = int.parse(parts[0]);
        final total = int.parse(parts[1]);
        if (total > 0) {
          return current / total;
        }
      }
    } catch (e) {
      print('Error parsing progress: $e');
    }
    return 0.0;
  }
}