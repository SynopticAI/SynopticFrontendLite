// lib/utils/cloud_logger.dart
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudLogger {
  static final CloudLogger _instance = CloudLogger._internal();
  factory CloudLogger() => _instance;
  CloudLogger._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final List<String> _logBuffer = [];
  
  static const int _maxBufferSize = 100;
  static const String _logFolder = 'debug_logs';

  /// Log a message to cloud storage
  Future<void> log(String message, {String level = 'INFO'}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '$timestamp [$level] $message';
      
      // Add to buffer
      _logBuffer.add(logEntry);
      
      // Also print to console for local debugging
      print('CLOUD_LOG: $logEntry');
      
      // Flush buffer if it gets too large
      if (_logBuffer.length >= _maxBufferSize) {
        await _flushLogs();
      }
    } catch (e) {
      print('CloudLogger error: $e');
    }
  }

  /// Log specifically for notification debugging
  Future<void> logNotification(String message) async {
    await log(message, level: 'NOTIFICATION');
  }

  /// Log error messages
  Future<void> logError(String message, [dynamic error]) async {
    final errorMsg = error != null ? '$message: $error' : message;
    await log(errorMsg, level: 'ERROR');
  }

  /// Force flush all buffered logs to cloud storage
  Future<void> _flushLogs() async {
    if (_logBuffer.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final fileName = 'log_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.txt';
      
      final logContent = _logBuffer.join('\n');
      final bytes = utf8.encode(logContent);
      
      final ref = _storage.ref().child('$_logFolder/${user.uid}/$fileName');
      
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'text/plain',
          customMetadata: {
            'device_id': await _getDeviceId(),
            'app_version': '1.0.3+18', // Your current version
            'log_count': _logBuffer.length.toString(),
          },
        ),
      );

      print('📤 Uploaded ${_logBuffer.length} log entries to: $_logFolder/${user.uid}/$fileName');
      _logBuffer.clear();
      
    } catch (e) {
      print('Error flushing logs: $e');
    }
  }

  /// Manual flush - call this when you want to upload logs immediately
  Future<void> flushNow() async {
    await _flushLogs();
  }

  /// Upload logs when app goes to background or closes
  Future<void> uploadOnAppPause() async {
    if (_logBuffer.isNotEmpty) {
      await _flushLogs();
    }
  }

  /// Get device identifier for logging
  Future<String> _getDeviceId() async {
    try {
      // Use the same device ID logic as NotificationService
      // You can import device_info_plus or just use a simple fallback
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'unknown_device';
    }
  }

  /// Clear all logs for current user (optional cleanup method)
  Future<void> clearUserLogs() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = _storage.ref().child('$_logFolder/${user.uid}');
      final listResult = await ref.listAll();
      
      for (final item in listResult.items) {
        await item.delete();
      }
      
      _logBuffer.clear();
      print('🗑️ Cleared all logs for user');
    } catch (e) {
      print('Error clearing logs: $e');
    }
  }
}