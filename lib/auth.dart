import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_device_manager/utils/user_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Auth{
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async{
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
       password: password,
       );
  }

  // Future<void> createUserWithEmailAndPassword({
  //   required String email,
  //   required String password,
  // }) async{
  //   await _firebaseAuth.createUserWithEmailAndPassword(
  //     email: email,
  //      password: password,
  //      );
  // }

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Create the account
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get the new user's ID
      final String userId = userCredential.user!.uid;
      
      // Initialize UserSettings and detect default language
      final userSettings = UserSettings();
      final defaultLang = await userSettings.getCurrentLanguage();  // This already exists in UserSettings

      // Create the initial user document with detected language
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
            'language': defaultLang,
            'email': email,
            // Add any other initial user settings you want to set
          });
          
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }

  Future<void> signOut() async{
    await _firebaseAuth.signOut();
  }
}