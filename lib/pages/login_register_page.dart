import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth.dart';
import 'package:ai_device_manager/utils/background_fade.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? errorMessage = '';
  bool isLogin = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> signInWithEmailAndPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        // Check for reviewer bypass code
        String emailToUse = _emailController.text;
        String passwordToUse = _passwordController.text;
        
        if (_emailController.text.trim() == "REVIEW756488") {
          // Use reviewer test account credentials
          emailToUse = "test@gmail.com";
          passwordToUse = "756488";
        }
        
        await Auth().signInWithEmailAndPassword(
          email: emailToUse,
          password: passwordToUse,
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          errorMessage = e.message;
        });
      }
    }
  }

  Future<void> createUserWithEmailAndPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        await Auth().createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          errorMessage = e.message;
        });
      }
    }
  }

  // Widget _backgroundAnimation() {
  //   // Placeholder for the Gabor filter animation
  //   return Container(
  //     decoration: BoxDecoration(
  //       gradient: LinearGradient(
  //         begin: Alignment.topLeft,
  //         end: Alignment.bottomRight,
  //         colors: [
  //           Colors.deepPurple.shade900,
  //           Colors.deepPurple.shade700,
  //           Colors.deepPurple.shade500,
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _backgroundAnimation() {
    return const AnimatedBackground(
      maxOpacity: 0.02,//0.01,  // Adjust this value to control intensity
      transitionDuration: Duration(seconds: 30),
      pauseDuration: Duration(seconds: 4),
    );
  }

  Widget _authForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isLogin ? 'Login' : 'Register',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 51, 73, 152)  ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                // Allow reviewer bypass code
                if (value.trim() == "REVIEW756488") {
                  return null; // Valid for reviewer
                }
                // Normal email validation for regular users
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              obscureText: true,
              validator: (value) {
                // Check if reviewer bypass code is being used
                if (_emailController.text.trim() == "REVIEW756488") {
                  return null; // Allow any password (or no password) for reviewer
                }
                
                // Normal password validation for regular users
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            if (errorMessage?.isNotEmpty ?? false) ...[
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLogin 
                  ? signInWithEmailAndPassword 
                  : createUserWithEmailAndPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 51, 73, 152),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isLogin ? 'Login' : 'Register',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // TEMPORARILY COMMENTED OUT - more extensive register functionality moved to homepage 
            // const SizedBox(height: 16),
            // TextButton(
            //   onPressed: () {
            //     setState(() {
            //       isLogin = !isLogin;
            //       errorMessage = '';
            //     });
            //   },
            //   child: Text(
            //     isLogin
            //         ? 'Need an account? Sign up'
            //         : 'Already have an account? Login',
            //     style: const TextStyle(color: Color.fromARGB(255, 51, 73, 152)),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background animation layer
          _backgroundAnimation(),
          
          // Content layer
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App logo or title
                    SvgPicture.asset(
                      'assets/loginPage/logo.svg',
                      width: 240,
                      height: 200,
                      colorFilter: const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                    ),
                    // const SizedBox(height: 16),
                    // const Text(
                    //   'Synoptic',
                    //   style: TextStyle(
                    //     fontSize: 32,
                    //     fontWeight: FontWeight.bold,
                    //     color: Colors.white,
                    //   ),
                    // ),
                    const SizedBox(height: 48),
                    // Auth form
                    _authForm(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}