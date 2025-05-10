import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// lib/app_initializer.dart
class AppInitializer {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;
  
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      print("Firebase successfully initialized");
    } catch (e) {
      print("Error initializing Firebase: $e");
      // Still mark as initialized to prevent repeated attempts
      _initialized = true;
      rethrow;
    }
  }
}