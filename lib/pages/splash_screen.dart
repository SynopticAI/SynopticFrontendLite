import 'package:flutter/material.dart';
import 'package:ai_device_manager/utils/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onAnimationComplete;
  
  const SplashScreen({
    Key? key,
    this.onAnimationComplete,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _pulseController;
  late AnimationController _sweepController; // Add sweep animation controller
  
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulse;
  late Animation<double> _sweepPosition; // Add sweep position animation

  @override
  void initState() {
    super.initState();
    
    // Logo animation controller (appears first)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Text animation controller (appears after logo)
    _textController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Pulse animation controller (continuous subtle pulse)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Sweep animation controller (repeating sweep across text)
    _sweepController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Logo animations
    _logoScale = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    // Text animations
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));

    // Subtle pulse animation
    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Sweep animation (moves from left to right)
    _sweepPosition = Tween<double>(
      begin: -0.5,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _sweepController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  void _startAnimations() async {
    // Start logo animation
    await _logoController.forward();
    
    // Wait a bit, then start text animation
    await Future.delayed(const Duration(milliseconds: 200));
    await _textController.forward();
    
    // Start subtle pulse animation
    _pulseController.repeat(reverse: true);
    
    // Start sweep animation with a delay, then repeat
    await Future.delayed(const Duration(milliseconds: 800));
    _sweepController.repeat();
    
    // Wait for animations to complete, then callback
    await Future.delayed(const Duration(milliseconds: 1200));
    
    if (widget.onAnimationComplete != null) {
      widget.onAnimationComplete!();
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    _sweepController.dispose(); // Dispose sweep controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we're in dark mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode 
          ? AppTheme.primaryColor.withOpacity(0.95)
          : AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with animations
            AnimatedBuilder(
              animation: Listenable.merge([_logoController, _pulseController]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoScale.value * _pulse.value,
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback if image doesn't exist yet
                            return Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.secondaryColor,
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.visibility,
                                size: 60,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Text logo with slide, fade, and sweep animations
            AnimatedBuilder(
              animation: Listenable.merge([_textController, _sweepController]),
              builder: (context, child) {
                return SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Text logo
                        Image.asset(
                          'assets/splashscreen/splash_logo_text.png',
                          height: 40,
                          fit: BoxFit.fitHeight,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback text if image doesn't exist yet
                            return Text(
                              'Synoptic',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w300,
                                color: isDarkMode 
                                    ? Colors.white
                                    : AppTheme.primaryColor,
                                letterSpacing: 2.0,
                              ),
                            );
                          },
                        ),
                        
                        // Sweeping animation overlay
                        Positioned.fill(
                          child: ClipRect(
                            child: AnimatedBuilder(
                              animation: _sweepController,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(_sweepPosition.value * 200, 0),
                                  child: Transform.rotate(
                                    angle: 0.785398, // 45 degrees in radians
                                    child: Container(
                                      width: 30,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.0),
                                            Colors.white.withOpacity(0.4),
                                            Colors.white.withOpacity(0.0),
                                          ],
                                          stops: const [0.0, 0.5, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}