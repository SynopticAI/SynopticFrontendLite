import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

class UserSettings {
  static final UserSettings _instance = UserSettings._internal();
  factory UserSettings() => _instance;
  UserSettings._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Supported languages
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    //'es': 'Español',
    'de': 'Deutsch',
    //'fr': 'Français',
    //'zh': '中文',
    //'ja': '日本語',
  };

  // Get current user language
  Future<String> getCurrentLanguage() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'en';

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
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
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('UserSettings - setUserLanguage: No user logged in');
        return;
      }

      if (!supportedLanguages.containsKey(languageCode)) {
        print('UserSettings - setUserLanguage: Unsupported language code: $languageCode');
        return;
      }

      print('UserSettings - Setting language to: $languageCode');
      await _firestore.collection('users').doc(user.uid).set({
        'language': languageCode,
      }, SetOptions(merge: true));

    } catch (e) {
      print('UserSettings - Error setting language: $e');
    }
  }

  // Stream for language changes
  Stream<String> get languageStream {
      // Create a stream that reacts to auth state changes
      return FirebaseAuth.instance.authStateChanges().switchMap((user) {
          if (user == null) {
              print('UserSettings - languageStream: No user logged in, defaulting to en');
              return Stream.value('en');
          }

          return _firestore
              .collection('users')
              .doc(user.uid)
              .snapshots()
              .map<String>((doc) {
                  final data = doc.data();
                  final lang = data?['language'] as String? ?? 'en';
                  print('UserSettings - Language stream update: $lang');
                  return lang;
              });
      });
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