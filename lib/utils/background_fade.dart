import 'package:flutter/material.dart';
import 'dart:math' as math;

// Define gradient colors as constants
//const Color kGradientStartColor = Color.fromARGB(255, 255, 153, 51);
//const Color kGradientEndColor = Color.fromARGB(255, 255, 203, 24);
// const Color kGradientStartColor = Color.fromARGB(160, 51, 73, 152);
// const Color kGradientEndColor = Color.fromARGB(160, 58, 193, 209);
const Color kGradientStartColor = Color.fromARGB(33, 51, 73, 152);
// const Color kGradientEndColor = Color.fromARGB(160, 58, 193, 209);
const Color kGradientEndColor = Color.fromARGB(160, 51, 73, 152);
class AnimatedBackground extends StatefulWidget {
  final double maxOpacity;
  final Duration transitionDuration;
  final Duration pauseDuration;

  const AnimatedBackground({
    Key? key,
    this.maxOpacity = 0.3,
    this.transitionDuration = const Duration(seconds: 4),
    this.pauseDuration = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;
  final int numImages = 5;
  
  // Keep track of current and upcoming image indices
  final List<int> _imageIndices = [0, 1, 2]; // Show 3 images simultaneously
  
  // Store the opacity values for each image
  late List<double> _imageOpacities;

  @override
  void initState() {
    super.initState();

    // Initialize opacity values with random values within the max opacity range
    final random = math.Random();
    _imageOpacities = List.generate(
      _imageIndices.length,
      (_) => random.nextDouble() * widget.maxOpacity,
    );
    
    // Create controllers for cross-fade animations
    _controllers = List.generate(
      _imageIndices.length,
      (index) => AnimationController(
        duration: widget.transitionDuration,
        vsync: this,
      ),
    );

    // Create curved animations
    _animations = _controllers.map((controller) =>
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ),
    ).toList();

    // Stagger the animation starts
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 700), () {
        if (mounted) {
          _startAnimation(i);
        }
      });
    }
  }

  void _startAnimation(int index) async {
    if (!mounted) return;

    // Reset controller
    _controllers[index].reset();
    
    // Run animation forward
    await _controllers[index].forward();

    if (!mounted) return;

    // Update image index and opacity
    setState(() {
      // Update to next image
      _imageIndices[index] = (_imageIndices[index] + _imageIndices.length) % numImages;
      
      // Generate new random opacity
      final random = math.Random();
      _imageOpacities[index] = (random.nextDouble() * 0.6 + 0.4) * widget.maxOpacity;
    });

    // Add pause between transitions
    await Future.delayed(widget.pauseDuration);
    
    // Start next transition if still mounted
    if (mounted) {
      _startAnimation(index);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kGradientStartColor, kGradientEndColor],
            ),
          ),
        ),
        
        // Overlay multiple animated images with different opacities
        for (int i = 0; i < _imageIndices.length; i++)
          FadeTransition(
            opacity: _animations[i],
            child: Image.asset(
              'assets/loginPage/gabor_${_imageIndices[i]}.png',
              fit: BoxFit.cover,
              opacity: AlwaysStoppedAnimation(_imageOpacities[i]),
            ),
          ),
      ],
    );
  }
}