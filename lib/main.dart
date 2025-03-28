import 'package:flutter/material.dart';
import 'package:ai_device_manager/widget_tree.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/cached_image_frame.dart';
import 'package:ai_device_manager/services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ai_device_manager/utils/user_settings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ai_device_manager/utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Only run cache cleanup on non-web platforms
  if (!kIsWeb) {
    await ImageCacheManager.cleanupOldCache();
  }

  // Initialize notifications only on non-web platforms
  if (!kIsWeb) {
    await NotificationService().initialize();
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Create a key that will be used to force UI refresh
  Key _appKey = UniqueKey();
  
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
    // When app is resumed from background
    if (state == AppLifecycleState.resumed) {
      // Force rebuild of the entire UI by creating a new key
      setState(() {
        _appKey = UniqueKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: UserSettings().languageStream,
      builder: (context, snapshot) {
        final locale = snapshot.data;
        print('Current language from stream: $locale'); // Debug print
        
        return MaterialApp(
          key: _appKey, // Apply the key here to force rebuild on resume
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