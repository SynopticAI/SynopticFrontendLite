// lib/widgets/region_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/region_selector_data.dart';

class RegionSelector extends StatefulWidget {
  final String imageUrl;
  final RegionSelectorData data;
  final Function(RegionSelectorData) onRegionChanged;
  
  const RegionSelector({
    Key? key,
    required this.imageUrl,
    required this.data,
    required this.onRegionChanged,
  }) : super(key: key);
  
  @override
  State<RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends State<RegionSelector> {
  late RegionSelectorData _data;
  bool _isDrawing = false;
  Size _canvasSize = Size.zero;
  
  @override
  void initState() {
    super.initState();
    _data = widget.data;
  }
  
  void _startDrawing(Offset position) {
    setState(() {
      _isDrawing = true;
      _data.addPoint(position);
    });
  }
  
  void _continueDrawing(Offset position) {
    if (!_isDrawing) return;
    
    setState(() {
      _data.addPoint(position);
    });
  }
  
  void _endDrawing() {
    if (!_isDrawing) return;
    
    setState(() {
      _isDrawing = false;
      _data.finishPath();
      widget.onRegionChanged(_data);
    });
  }
  
  Widget _buildModeIndicator() {
    return AnimatedOpacity(
      opacity: _isDrawing ? 1.0 : 0.7,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _data.isAddMode ? Icons.add : Icons.remove,
              color: _data.isAddMode ? Colors.red : Colors.blue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _data.isAddMode ? 'Adding Region' : 'Removing Region',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mode toggle and control buttons
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Add/Remove toggle
              ToggleButtons(
                isSelected: [_data.isAddMode, !_data.isAddMode],
                onPressed: (index) {
                  setState(() {
                    _data.isAddMode = index == 0;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: _data.isAddMode ? Colors.red : Colors.blue,
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.add),
                        SizedBox(width: 8),
                        Text('Add'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.remove),
                        SizedBox(width: 8),
                        Text('Remove'),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Undo button
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Undo Last',
                onPressed: _data.paths.isEmpty ? null : () {
                  setState(() {
                    _data.undoLastPath();
                    widget.onRegionChanged(_data);
                  });
                },
              ),
              
              // Clear button
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Clear All',
                onPressed: _data.isEmpty ? null : () {
                  setState(() {
                    _data.clear();
                    widget.onRegionChanged(_data);
                  });
                },
              ),
            ],
          ),
        ),
        
        // Drawing area
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[300],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                      ),
                    ),
                  ),
                  
                  // Drawing layer with fixed scroll issue
                  LayoutBuilder(
                    builder: (context, constraints) {
                      _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                      
                      // Use a simpler approach with GestureDetector and behavior parameter
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque, // This is key to prevent scrolling
                        onPanStart: (details) {
                          _startDrawing(details.localPosition);
                        },
                        onPanUpdate: (details) {
                          _continueDrawing(details.localPosition);
                        },
                        onPanEnd: (details) {
                          _endDrawing();
                        },
                        // Add vertical drag handlers explicitly
                        onVerticalDragStart: (details) {
                          _startDrawing(details.localPosition);
                        },
                        onVerticalDragUpdate: (details) {
                          _continueDrawing(details.localPosition);
                        },
                        onVerticalDragEnd: (details) {
                          _endDrawing();
                        },
                        child: CustomPaint(
                          painter: RegionPainter(_data, _canvasSize),
                          size: Size.infinite,
                        ),
                      );
                    },
                  ),
                  
                  // Mode indicator (positioned at the top)
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildModeIndicator(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Helper text
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Draw on the image to define areas where notifications should be triggered.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RegionPainter extends CustomPainter {
  final RegionSelectorData data;
  final Size canvasSize;
  
  RegionPainter(this.data, this.canvasSize);
  
  @override
  void paint(Canvas canvas, Size size) {
    // Paint for the final region
    final Paint regionPaint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    // Paint for the current path being drawn
    final Paint currentPathPaint = Paint()
      ..color = data.isAddMode 
          ? Colors.red.withOpacity(0.7) 
          : Colors.blue.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    
    // Draw the combined region
    if (data.paths.isNotEmpty) {
      canvas.drawPath(data.getFinalRegion(canvasSize), regionPaint);
    }
    
    // Draw the current path with a different style
    if (data.currentPath != null) {
      canvas.drawPath(data.currentPath!, currentPathPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant RegionPainter oldDelegate) {
    return true; // Always repaint when redrawing
  }
}