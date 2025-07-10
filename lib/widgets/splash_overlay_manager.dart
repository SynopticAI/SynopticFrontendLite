import 'package:flutter/material.dart';
import 'package:ai_device_manager/pages/splash_screen.dart';

class SplashOverlayManager extends StatefulWidget {
  final Widget child;
  final Duration splashDuration;
  final int splashTriggerCount; // Use counter instead of boolean for more reliable triggering
  
  const SplashOverlayManager({
    Key? key,
    required this.child,
    this.splashDuration = const Duration(seconds: 3),
    this.splashTriggerCount = 0, // Default to 0
  }) : super(key: key);

  @override
  State<SplashOverlayManager> createState() => _SplashOverlayManagerState();
}

class _SplashOverlayManagerState extends State<SplashOverlayManager> {
  bool _showSplash = true;
  late DateTime _splashStartTime;
  bool _hasBeenHidden = false;
  int _lastTriggerCount = 0;

  @override
  void initState() {
    super.initState();
    _lastTriggerCount = widget.splashTriggerCount;
    _initializeSplash();
  }

  @override
  void didUpdateWidget(SplashOverlayManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If trigger count changed, reinitialize splash
    if (widget.splashTriggerCount != _lastTriggerCount) {
      _lastTriggerCount = widget.splashTriggerCount;
      _initializeSplash();
    }
  }

  void _initializeSplash() {
    // Reset all splash state
    _splashStartTime = DateTime.now();
    _hasBeenHidden = false;
    
    setState(() {
      _showSplash = true;
    });
    
    print('🎬 Splash started at: $_splashStartTime (trigger count: ${widget.splashTriggerCount})');
    
    // Start the timer to hide splash after specified duration
    Future.delayed(widget.splashDuration, () {
      _hideSplashWithMinimumDuration();
    });
  }

  void _hideSplash() {
    _hideSplashWithMinimumDuration();
  }

  void _hideSplashWithMinimumDuration() async {
    if (!mounted || _hasBeenHidden) return;
    
    // Calculate how long the splash has been showing
    final elapsed = DateTime.now().difference(_splashStartTime);
    const minimumDuration = Duration(milliseconds: 1000); // 2 seconds minimum
    
    print('🕒 Elapsed time: ${elapsed.inMilliseconds}ms, Minimum: ${minimumDuration.inMilliseconds}ms');
    
    // If we haven't shown the splash for at least 2 seconds, wait
    if (elapsed < minimumDuration) {
      final remainingTime = minimumDuration - elapsed;
      print('⏳ Waiting additional ${remainingTime.inMilliseconds}ms');
      await Future.delayed(remainingTime);
    }
    
    // Now hide the splash
    if (mounted && !_hasBeenHidden) {
      print('✅ Hiding splash now');
      _hasBeenHidden = true;
      setState(() {
        _showSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Now we're inside MaterialApp, so Stack has proper Directionality context
    return Stack(
      children: [
        // Main app content - this loads immediately in the background
        widget.child,
        
        // Splash overlay - shows on top until timer expires
        if (_showSplash)
          SplashScreen(
            onAnimationComplete: _hideSplash,
          ),
      ],
    );
  }
}