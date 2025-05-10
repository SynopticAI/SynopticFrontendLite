import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

class AppInitializer {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;
  
  static Future<void> initialize() async {
    if (_initialized) return;
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    _initialized = true;
  }
}