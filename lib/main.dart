import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:ai_device_manager/widget_tree.dart';
import 'package:ai_device_manager/pages/splash_screen.dart'; // Add this import
import 'package:flutter_native_splash/flutter_native_splash.dart'; // Add this import
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/cached_image_frame.dart';
import 'package:ai_device_manager/services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ai_device_manager/l10n/app_localizations.dart';
import 'package:ai_device_manager/l10n/context_extensions.dart';
import 'package:ai_device_manager/utils/user_settings.dart';
import 'package:ai_device_manager/utils/app_theme.dart';
import 'package:ai_device_manager/app_initializer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Add this debug import - you'll need to create this file or comment out if not using
import 'package:ai_device_manager/pages/notification_debug_page.dart';
import 'package:ai_device_manager/utils/cloud_logger.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message received: ${message.messageId}');
  // Handle background message if needed
}

Future<void> main() async {
  // Preserve the native splash screen
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Initialize your app in the background while native splash is showing
  try {
    // Initialize Firebase first
    await AppInitializer.initialize();
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Then clean up cache
    if (!kIsWeb) {
      await ImageCacheManager.cleanupOldCache();
    }
    
    // Initialize enhanced notifications after Firebase with delay for iOS
    if (!kIsWeb) {
      print('🔔 Initializing NotificationService...');
      
      // Add delay for iOS to ensure proper initialization order
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      await NotificationService().initialize();
    }
    
    print('✅ App initialization complete');
  } catch (e) {
    print('❌ Initialization error: $e');
  }

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  bool _wasInBackground = false;
  bool _showAnimatedSplash = true; // Show our beautiful animated splash
  bool _initializationComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // TODO: Later, replace this with actual initialization checking
    // For now, just wait 3 seconds as requested
    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    // Wait a brief moment to ensure native splash is visible
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Remove the native splash screen to show our animated splash
    FlutterNativeSplash.remove();
    
    // TODO: Replace this placeholder with actual initialization status checking
    // For now, just wait 3 seconds as requested
    await Future.delayed(const Duration(seconds: 3));
    
    // Mark initialization as complete (placeholder)
    if (mounted) {
      setState(() {
        _initializationComplete = true;
        _showAnimatedSplash = false;
      });
    }
  }

  // This method will be used later for proper initialization tracking
  Future<void> _waitForInitialization() async {
    // TODO: Later, implement proper checking like:
    // - Firebase initialization complete
    // - User settings loaded
    // - Notification service ready
    // - Device scanning initialized
    // etc.
    
    // For now, just the placeholder timer
    await Future.delayed(const Duration(seconds: 3));
    
    setState(() {
      _initializationComplete = true;
      _showAnimatedSplash = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App is going to background - upload logs
      _wasInBackground = true;
      
      // Upload cloud logs when app goes to background
      if (!kIsWeb) {
        CloudLogger().uploadOnAppPause();
        NotificationService().dispose(); // This also triggers log upload
      }
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      // App is coming from background
      _wasInBackground = false;
      
      // Check notification setup when coming back from background
      if (!kIsWeb) {
        Future.delayed(const Duration(milliseconds: 100), () {
          NotificationService().isNotificationSetupComplete().then((isComplete) {
            if (!isComplete) {
              print('🔄 App resumed, refreshing notification setup...');
              NotificationService().refreshFCMToken();
            }
          });
        });
      }
      
      // Schedule a rebuild, but do it gently with a short delay
      // This prevents jittery behavior during normal app interactions
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          // Clear the GPU cache/force a texture refresh without rebuilding the whole tree
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          
          // This is a gentler approach than recreating the entire widget tree
          setState(() {});
        }
      });
    }
  }

  void _onAnimatedSplashComplete() {
    if (mounted) {
      setState(() {
        _showAnimatedSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show our beautiful animated splash screen after native splash
    if (_showAnimatedSplash) {
      return MaterialApp(
        title: 'Synoptic',
        theme: AppTheme.getTheme(),
        home: SplashScreen(
          onAnimationComplete: _onAnimatedSplashComplete,
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    // After both splash screens, show main app
    return StreamBuilder<String>(
      stream: UserSettings().languageStream,
      builder: (context, snapshot) {
        // Show loading instead of empty screen while initializing
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            title: 'Synoptic',
            theme: AppTheme.getTheme(),
            home: const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing...'),
                  ],
                ),
              ),
            ),
          );
        }
        
        // Handle errors gracefully
        if (snapshot.hasError) {
          print("Error in language stream: ${snapshot.error}");
          // Fall back to default language
          return MaterialApp(
            title: 'Synoptic',
            theme: AppTheme.getTheme(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('de'),
              Locale('es'),
              Locale('fr'),
              Locale('zh'),
              Locale('ja'),
            ],
            // Uncomment if you create the debug page
            routes: {
              '/notification-debug': (context) => const NotificationDebugPage(),
            },
            home: const WidgetTree(),
          );
        }

        final locale = snapshot.data;
        print('Current language from stream: $locale'); // Debug print
        
        return MaterialApp(
          title: 'Synoptic',
          theme: AppTheme.getTheme(), // Use our custom theme
          locale: locale != null ? Locale(locale) : const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('de'),
            Locale('es'),
            Locale('fr'),
            Locale('zh'),
            Locale('ja'),
          ],
          // Uncomment if you create the debug page
          routes: {
            '/notification-debug': (context) => const NotificationDebugPage(),
          },
          home: const WidgetTree(),
        );
      },
    );
  }
}