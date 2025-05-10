import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:ai_device_manager/app_initializer.dart';

class UserSettings {
  static final UserSettings _instance = UserSettings._internal();
  factory UserSettings() => _instance;

  // Use nullable FirebaseFirestore to prevent initialization errors
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  
  // Flag to check initialization status
  bool _isInitialized = false;

  // Supported languages
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    //'es': 'Español',
    'de': 'Deutsch',
    //'fr': 'Français',
    //'zh': '中文',
    //'ja': '日本語',
  };

  // Private constructor - doesn't immediately initialize Firebase
  UserSettings._internal() {
    // No initialization happens here - this prevents the race condition
    print('UserSettings instance created, awaiting initialization');
  }

  // Method to safely ensure initialization before using Firebase services
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    
    try {
      // Make sure Firebase is initialized first
      if (!AppInitializer.isInitialized) {
        print('Firebase not initialized, initializing now...');
        await AppInitializer.initialize();
      }
      
      // Now it's safe to initialize Firebase services
      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
      _isInitialized = true;
      print('UserSettings successfully initialized');
    } catch (e) {
      print('Error initializing UserSettings: $e');
      // Still mark as initialized to prevent repeated attempts that would fail
      _isInitialized = true;
      // Don't rethrow - just handle gracefully
    }
  }

  // Get current user language
  Future<String> getCurrentLanguage() async {
    // Ensure we're initialized before accessing Firebase
    await ensureInitialized();
    
    try {
      final user = _auth?.currentUser;
      if (user == null) return 'en';

      final doc = await _firestore?.collection('users').doc(user.uid).get();
      if (doc == null || !doc.exists) {
        final defaultLang = await _detectDefaultLanguage();
        await setUserLanguage(defaultLang);
        return defaultLang;
      }

      final lang = doc.data()?['language'] ?? 'en';
      print('UserSettings - getCurrentLanguage: $lang');
      return lang;
    } catch (e) {
      print('UserSettings - Error getting language: $e');
      return 'en';
    }
  }

  // Set user language
  Future<void> setUserLanguage(String languageCode) async {
    // Ensure initialization
    await ensureInitialized();
    
    try {
      final user = _auth?.currentUser;
      if (user == null) {
        print('UserSettings - setUserLanguage: No user logged in');
        return;
      }

      if (!supportedLanguages.containsKey(languageCode)) {
        print('UserSettings - setUserLanguage: Unsupported language code: $languageCode');
        return;
      }

      print('UserSettings - Setting language to: $languageCode');
      await _firestore?.collection('users').doc(user.uid).set({
        'language': languageCode,
      }, SetOptions(merge: true));

    } catch (e) {
      print('UserSettings - Error setting language: $e');
    }
  }

  // Stream for language changes
  Stream<String> get languageStream {
    // Create a stream that handles initialization first
    final controller = BehaviorSubject<String>();
    
    // Initial value while initializing
    controller.add('en');
    
    // Schedule initialization and setup
    Future<void> setup() async {
      try {
        // Ensure initialized first
        await ensureInitialized();
        
        // Now that we're initialized, set up the real stream
        FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user == null) {
            controller.add('en');
            return;
          }
          
          // Setup Firestore listener
          _firestore?.collection('users').doc(user.uid).snapshots().listen(
            (doc) {
              final data = doc.data();
              final lang = data?['language'] as String? ?? 'en';
              controller.add(lang);
            },
            onError: (e) {
              print('Error in language stream: $e');
              // Don't propagate error, just maintain last value
            }
          );
        }, onError: (e) {
          print('Auth state error: $e');
          // On auth error, default to 'en'
          controller.add('en');
        });
      } catch (e) {
        print('Setup error in languageStream: $e');
        // If setup fails, still provide default value
        controller.add('en');
      }
    }
    
    // Start the setup process
    setup();
    
    // Return the controlled stream
    return controller.stream;
  }

  // Detect default language based on system settings and location
  Future<String> _detectDefaultLanguage() async {
    try {
      print('UserSettings - Detecting default language');
      
      // First try system locale
      final systemLocale = WidgetsBinding.instance.window.locale.languageCode;
      if (supportedLanguages.containsKey(systemLocale)) {
        print('UserSettings - Using system locale: $systemLocale');
        return systemLocale;
      }

      // If system locale not supported, try IP-based detection
      try {
        final response = await http.get(Uri.parse('http://ip-api.com/json'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final countryCode = data['countryCode'].toString().toLowerCase();
          
          // Map country codes to language codes
          final Map<String, String> countryToLanguage = {
            'us': 'en', 'gb': 'en',
            'es': 'es', 'mx': 'es',
            'de': 'de', 'at': 'de', 'ch': 'de',
            'fr': 'fr', 'ca': 'fr',
            'cn': 'zh', 'tw': 'zh', 'hk': 'zh',
            'jp': 'ja'
          };

          if (countryToLanguage.containsKey(countryCode)) {
            final detectedLang = countryToLanguage[countryCode]!;
            print('UserSettings - Detected language from location: $detectedLang');
            return detectedLang;
          }
        }
      } catch (e) {
        print('UserSettings - Error in IP detection: $e');
      }

      // Default to English if detection fails
      print('UserSettings - Defaulting to English');
      return 'en';
    } catch (e) {
      print('UserSettings - Error detecting language: $e');
      return 'en';
    }
  }
}