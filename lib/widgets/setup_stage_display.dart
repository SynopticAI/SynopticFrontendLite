import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import '../device.dart';
import '../utils/setup_stage_manager.dart';
import 'package:ai_device_manager/l10n/app_localizations.dart';
import 'package:ai_device_manager/utils/app_theme.dart';

class SetupStageInfo {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  SetupStageInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class SetupStageDisplay extends StatefulWidget {
  final Device device;
  final String userId;
  final VoidCallback? onStageChanged;
  final double width;
  final bool startExpanded;

  const SetupStageDisplay({
    Key? key,
    required this.device,
    required this.userId,
    this.onStageChanged,
    this.width = 60,
    this.startExpanded = false,
  }) : super(key: key);

  @override
  State<SetupStageDisplay> createState() => _SetupStageDisplayState();
}

class _SetupStageDisplayState extends State<SetupStageDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;
  double _currentStage = 0.0;
  int _lastCompletedStageFloor = -1; // Track the last stage we completed (as floor int)
  final SetupStageManager _setupStageManager = SetupStageManager();
  Stream<double>? _stageStream;
  
  // Keep track of which stage animations have already been shown
  final Set<int> _animationShownForStages = {};

  // Define setup stages (simplified to 3 stages)
  final List<SetupStageInfo> _setupStages = [
    SetupStageInfo(
      title: 'Task Definition',
      description: 'Define task, inference mode, and prompt template',
      icon: Icons.description,
      color: const Color.fromARGB(255, 51, 73, 152),
    ),
    SetupStageInfo(
      title: 'Testing',
      description: 'Test inference with sample images and refine settings',
      icon: Icons.check_circle_outline,
      color: const Color.fromARGB(255, 55, 133, 181),
    ),
    SetupStageInfo(
      title: 'Complete',
      description: 'Device is fully configured and operational',
      icon: Icons.check_circle,
      color: const Color.fromARGB(255, 58, 193, 209),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.startExpanded;
    _currentStage = widget.device.setupStage;
    
    // Initially mark the current stage floor as having shown animation
    if (_currentStage > 0) {
      _lastCompletedStageFloor = _currentStage.floor();
      _animationShownForStages.add(_lastCompletedStageFloor);
    }
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _expandAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
    
    // Initialize the stage stream
    _stageStream = _setupStageManager.getSetupStageStream(widget.userId, widget.device.id);
    
    // Register for notifications
    _setupStageManager.registerStageChangeCallback(
      widget.device.id, 
      _handleStageChange
    );
  }

  /// Handle stage changes with robust animation trigger logic
  void _handleStageChange(double newStage) {
    int newStageFloor = newStage.floor();
    
    // Only show animation when crossing to a new floor value AND we haven't shown for this stage before
    if (newStageFloor > _lastCompletedStageFloor && !_animationShownForStages.contains(newStageFloor)) {
      if (mounted && context != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showLottieCompletionOverlay(context);
        });
      }
      // Mark this stage as having shown the animation
      _animationShownForStages.add(newStageFloor);
      _lastCompletedStageFloor = newStageFloor;
    } else if (newStageFloor > _lastCompletedStageFloor) {
      // Just update the last completed stage without showing animation
      _lastCompletedStageFloor = newStageFloor;
    }
    
    if (mounted) {
      setState(() {
        _currentStage = newStage;
      });
    }
    
    if (widget.onStageChanged != null) {
      widget.onStageChanged!();
    }
  }

  // Method to show Lottie animation overlay
  void _showLottieCompletionOverlay(BuildContext context) {
    // Get the overlay state
    final overlay = Overlay.of(context);
    if (overlay == null) return;
    
    // Create an overlay entry
    OverlayEntry? entry;
    
    entry = OverlayEntry(
      builder: (context) => LottieCompletionAnimation(
        onComplete: () {
          // Auto-dismiss when animation completes
          entry?.remove();
        },
      ),
    );
    
    // Add to overlay
    overlay.insert(entry);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _setupStageManager.unregisterStageChangeCallback(
      widget.device.id, 
      _handleStageChange
    );
    super.dispose();
  }

  @override
  void didUpdateWidget(SetupStageDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if the stage changed from external updates
    if (widget.device.setupStage != _currentStage) {
      int newStageFloor = widget.device.setupStage.floor();
      
      // Only show animation for new stages we haven't shown animation for
      bool shouldShowAnimation = newStageFloor > _currentStage.floor() && 
                                !_animationShownForStages.contains(newStageFloor);
      
      // Update the stage value
      setState(() {
        _currentStage = widget.device.setupStage;
      });
      
      // Only show animation if needed and not already shown
      if (shouldShowAnimation) {
        _animationShownForStages.add(newStageFloor);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showLottieCompletionOverlay(context);
        });
      }
      
      // Always update last completed stage
      if (newStageFloor > _lastCompletedStageFloor) {
        _lastCompletedStageFloor = newStageFloor;
      }
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: _stageStream,
      initialData: _currentStage,
      builder: (context, snapshot) {
        // Handle stream updates with animation logic
        if (snapshot.hasData && snapshot.data != _currentStage) {
          double newStage = snapshot.data!;
          int newStageFloor = newStage.floor();
          
          // Update in the next frame to avoid build errors
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleStageChange(newStage);
          });
        }

        return InkWell(
          onTap: _toggleExpanded,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isExpanded ? 280 : widget.width,
            child: Card(
              margin: const EdgeInsets.all(8),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: _isExpanded ? AppTheme.backgroundColor : AppTheme.backgroundColor.withOpacity(0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon
                  SizedBox(
                    height: 48,
                    child: Stack(
                      children: [
                        // Construction icon with adjusted position
                        Positioned(
                          left: 4,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Icon(
                              Icons.settings,
                              size: 24,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        // Only show text when expanded
                        if (_isExpanded)
                          Positioned(
                            left: 50,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Text("Setup Progress"),
                            ),
                          ),
                        // Only show chevron when expanded
                        if (_isExpanded)
                          Positioned(
                            right: 16,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Icon(Icons.chevron_right),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Progress Stages
                  AnimatedBuilder(
                    animation: _expandAnimation,
                    builder: (context, child) {
                      return SizedBox(
                        height: _isExpanded ? (_setupStages.length * 70.0) : 200,
                        child: Stack(
                          children: [
                            // Vertical progress line
                            Positioned(
                              left: 15,
                              top: 26,
                              bottom: 26,
                              width: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGray.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            
                            // Progress line fill
                            Positioned(
                              left: 15,
                              top: 26,
                              width: 4,
                              height: (snapshot.data! / (_setupStages.length-1)) * 148,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color.fromARGB(255, 51, 73, 152),
                                      const Color.fromARGB(255, 58, 193, 209)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            
                            // Stage indicators
                            ...List.generate(_setupStages.length, (index) {
                              final stage = _setupStages[index];
                              bool isCompleted = snapshot.data! >= index + 1;
                              bool isCurrent = snapshot.data!.floor() == index;
                              
                              return Positioned(
                                left: 3,
                                top: 14 + (index * 70.0),
                                child: Row(
                                  children: [
                                    // Stage icon
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: isCompleted 
                                            ? stage.color 
                                            : (isCurrent ? stage.color.withOpacity(0.5) : Colors.grey[400]),
                                        shape: BoxShape.circle,
                                        boxShadow: isCompleted || isCurrent 
                                            ? [BoxShadow(color: stage.color.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)]
                                            : null,
                                      ),
                                      child: Icon(
                                        isCompleted ? Icons.check : stage.icon,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    
                                    // Stage info (visible only when expanded)
                                    if (_isExpanded)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 12),
                                        child: SizedBox(
                                          width: 180,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stage.title,
                                                style: TextStyle(
                                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                                  color: isCurrent ? stage.color : null,
                                                ),
                                              ),
                                              if (isCurrent)
                                                Text(
                                                  stage.description,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A Lottie animation overlay for stage completion
class LottieCompletionAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  
  const LottieCompletionAnimation({
    Key? key,
    required this.onComplete,
  }) : super(key: key);
  
  @override
  State<LottieCompletionAnimation> createState() => _LottieCompletionAnimationState();
}

class _LottieCompletionAnimationState extends State<LottieCompletionAnimation> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    
    // Create animation controller for the Lottie animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    // Start animation and dismiss when complete
    _controller.forward().then((_) => widget.onComplete());
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency, // Using Material to prevent rendering issues
      child: Container(
        color: Colors.black.withOpacity(0.2), // More subtle background darkening
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min, // Prevent column from taking full height
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie animation
              SizedBox(
                width: 180,
                height: 180,
                child: Lottie.asset(
                  'assets/animations/completion_success.json',
                  controller: _controller,
                  onLoaded: (composition) {
                    // Optional: adjust the controller duration to match the composition
                    _controller.duration = composition.duration;
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small floating button that expands to show the setup stage display
class SetupStageButton extends StatelessWidget {
  final Device device;
  final String userId;
  final VoidCallback? onStageChanged;

  const SetupStageButton({
    Key? key,
    required this.device,
    required this.userId,
    this.onStageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate current stage index and get stage info
    final int currentStageIndex = device.setupStage.floor();
    final stageColor = currentStageIndex < 2 
        ? Color.lerp(const Color.fromARGB(255, 51, 73, 152), const Color.fromARGB(255, 58, 193, 209), currentStageIndex / 2)! 
        : const Color.fromARGB(255, 58, 193, 209);
    
    return InkWell(
      onTap: () {
        // Show the full setup stage display as a modal bottom sheet
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            builder: (_, controller) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: ListView(
                controller: controller,
                padding: EdgeInsets.zero,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  // Setup stage display
                  SetupStageDisplay(
                    device: device,
                    userId: userId,
                    onStageChanged: onStageChanged,
                    startExpanded: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: stageColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: stageColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              'Setup: ${((device.setupStage / 2) * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}