import 'package:flutter/material.dart';
import 'package:ai_device_manager/widget_tree.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/cached_image_frame.dart';
import 'package:ai_device_manager/services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ai_device_manager/l10n/app_localizations.dart';
import 'package:ai_device_manager/l10n/context_extensions.dart';
import 'package:ai_device_manager/utils/user_settings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ai_device_manager/utils/app_theme.dart';

import 'package:ai_device_manager/app_initializer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase first
    await AppInitializer.initialize();
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Then clean up cache
    if (!kIsWeb) {
      await ImageCacheManager.cleanupOldCache();
    }
    
    // Initialize notifications after Firebase
    if (!kIsWeb) {
      await NotificationService().initialize();
    }
  } catch (e) {
    print("Error during app initialization: $e");
    // Continue anyway, the app should handle errors gracefully
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Flag to track if we came from background
  bool _forceRebuildAfterNextBuild = false;
  bool _wasInBackground = false;
  
  @override
  void initState() {
    super.initState();
    // Register for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Unregister when the app is disposed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App is going to background
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      // App is coming from background (not just an overlay or notification)
      _wasInBackground = false;
      
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: UserSettings().languageStream,
      builder: (context, snapshot) {
        // Show loading instead of empty screen while initializing
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            title: 'Synoptic',
            theme: AppTheme.getTheme(),
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
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
            home: const WidgetTree(),
          );
        }

        final locale = snapshot.data;
        print('Current language from stream: $locale'); // Debug print
        
        return MaterialApp(
          title: 'Synoptic',
          theme: AppTheme.getTheme(), // Use our custom theme
          locale: locale != null ? Locale(locale) : null,
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
          home: const WidgetTree(),
        );
      },
    );
  }
}

// The rest of your original MyHomePage and _MyHomePageState classes remain unchanged
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}