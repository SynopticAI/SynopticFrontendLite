import 'package:flutter/material.dart';
import 'dart:async';
import 'package:ai_device_manager/device.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A utility class for managing the simplified 3-stage setup process
class SetupStageManager {
  static final SetupStageManager _instance = SetupStageManager._internal();
  factory SetupStageManager() => _instance;
  SetupStageManager._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Define the stages with simplified flow
  // Task Definition -> Testing -> Complete
  
  // Stage 0: Task Definition
  static const double TASK_DEFINITION_NOT_STARTED = 0.0;
  static const double TASK_DEFINITION_IN_PROGRESS = 0.5;
  static const double TASK_DEFINITION_COMPLETE = 1.0;
  
  // Stage 1: Testing
  static const double TESTING_NOT_STARTED = 1.0;
  static const double TESTING_IN_PROGRESS = 1.5;
  static const double TESTING_COMPLETE = 2.0;
  
  // Stage 2: Complete
  static const double SETUP_COMPLETE = 2.0;
  
  // Store callbacks for stage changes
  final Map<String, List<Function(double)>> _stageChangeCallbacks = {};

  /// Listen for changes in the setup stage
  Stream<double> getSetupStageStream(String userId, String deviceId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return 0.0;
          final data = snapshot.data();
          return (data?['setupStage'] as num?)?.toDouble() ?? 0.0;
        });
  }

  /// Register a callback for when the setup stage changes
  void registerStageChangeCallback(String deviceId, Function(double) callback) {
    if (!_stageChangeCallbacks.containsKey(deviceId)) {
      _stageChangeCallbacks[deviceId] = [];
    }
    _stageChangeCallbacks[deviceId]!.add(callback);
  }

  /// Unregister a callback
  void unregisterStageChangeCallback(String deviceId, Function(double) callback) {
    if (_stageChangeCallbacks.containsKey(deviceId)) {
      _stageChangeCallbacks[deviceId]!.remove(callback);
      if (_stageChangeCallbacks[deviceId]!.isEmpty) {
        _stageChangeCallbacks.remove(deviceId);
      }
    }
  }

  /// Notify all registered callbacks about a stage change
  void _notifyStageChange(String deviceId, double newStage) {
    if (_stageChangeCallbacks.containsKey(deviceId)) {
      for (final callback in _stageChangeCallbacks[deviceId]!) {
        callback(newStage);
      }
    }
  }
  
  /// Update the setup stage for a device
  Future<bool> updateSetupStage(String userId, String deviceId, double newStage) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .update({'setupStage': newStage});
      
      // Notify callbacks
      _notifyStageChange(deviceId, newStage);
      return true;
    } catch (e) {
      debugPrint('Error updating setup stage: $e');
      return false;
    }
  }
  
  /// Advance to the next full stage
  Future<bool> advanceToNextStage(String userId, String deviceId, double currentStage) async {
    // Calculate the next full stage (e.g., 0.5 -> 1.0, 1.0 -> 2.0)
    double nextStage = (currentStage.ceil()).toDouble();
    
    // If already at a full stage, advance to the next one
    if (currentStage == nextStage) {
      nextStage = currentStage + 1.0;
    }
    
    return await updateSetupStage(userId, deviceId, nextStage);
  }
  
  /// Set the stage to "in progress"
  Future<bool> setStageInProgress(String userId, String deviceId, double currentStage) async {
    // Only set to in-progress if at a full stage
    if (currentStage == currentStage.floorToDouble()) {
      return await updateSetupStage(userId, deviceId, currentStage + 0.5);
    }
    return true; // Already in progress
  }
  
  /// Check if task definition is complete
  bool isTaskDefinitionComplete(Device device) {
    return device.name.isNotEmpty && 
           device.taskDescription != null && 
           device.taskDescription!.isNotEmpty &&
           device.promptTemplate.isNotEmpty;
  }
  
  /// Initialize setupStage to 0 for a new device
  Future<void> initializeSetupStage(String userId, String deviceId) async {
    try {
      final deviceDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .get();
      
      // Only set if the document exists and setupStage is not set
      if (deviceDoc.exists) {
        final data = deviceDoc.data();
        if (data != null && !data.containsKey('setupStage')) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('devices')
              .doc(deviceId)
              .update({'setupStage': 0.0});
        }
      }
    } catch (e) {
      debugPrint('Error initializing setup stage: $e');
    }
  }
}