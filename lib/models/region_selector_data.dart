// lib/models/region_selector_data.dart
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';

class RegionSelectorData {
  // Store the points as a collection of paths
  final List<PathOperation> operations = [];
  final List<Path> paths = [];
  
  // Current path being drawn
  Path? currentPath;
  bool isAddMode = true;
  
  // Temporary storage for current drawing points
  final List<Offset> _currentPoints = [];
  
  // Add a point to the current path
  void addPoint(Offset point) {
    _currentPoints.add(point);
    
    // Create or update currentPath
    if (currentPath == null) {
      currentPath = Path()..moveTo(point.dx, point.dy);
    } else {
      currentPath!.lineTo(point.dx, point.dy);
    }
  }
  
  // Finish the current path and add it to the appropriate collection
  void finishPath() {
    if (currentPath != null && _currentPoints.length > 1) {
      // Close the path if it has enough points
      if (_currentPoints.length > 2) {
        currentPath!.close();
      }
      
      // Add to appropriate collection
      paths.add(currentPath!);
      operations.add(isAddMode ? PathOperation.union : PathOperation.difference);
      
      // Reset current path
      currentPath = null;
      _currentPoints.clear();
    }
  }
  
  // Calculate the final region by combining all paths with their operations
  Path getFinalRegion(Size canvasSize) {
    // Start with an empty path
    Path finalPath = Path();
    
    if (paths.isEmpty) {
      // If no paths, return empty path
      return finalPath;
    }
    
    // Initialize with the first path (depending on operation)
    if (operations.isNotEmpty && operations[0] == PathOperation.union) {
      finalPath = Path.from(paths[0]);
    } else if (operations.isNotEmpty) {
      // If first operation is difference, start with full canvas
      finalPath.addRect(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height));
    }
    
    // Apply all subsequent paths with their operations
    for (int i = operations[0] == PathOperation.union ? 1 : 0; i < paths.length; i++) {
      try {
        finalPath = Path.combine(operations[i], finalPath, paths[i]);
      } catch (e) {
        print('Error combining paths: $e');
        // Fallback: Just add the path if combining fails
        if (operations[i] == PathOperation.union) {
          finalPath.addPath(paths[i], Offset.zero);
        }
      }
    }
    
    return finalPath;
  }
  
  // Convert path points to a serializable format
  Map<String, dynamic> toMap() {
    List<Map<String, dynamic>> serializedPaths = [];
    
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final operation = operations[i];
      
      // Convert path to a list of points
      final List<Map<String, double>> points = [];
      path.computeMetrics().forEach((metric) {
        for (double t = 0.0; t <= 1.0; t += 0.01) {
          final tangent = metric.getTangentForOffset(metric.length * t);
          if (tangent != null) {
            points.add({
              'x': tangent.position.dx,
              'y': tangent.position.dy
            });
          }
        }
      });
      
      serializedPaths.add({
        'operation': operation == PathOperation.union ? 'add' : 'remove',
        'points': points
      });
    }
    
    return {
      'paths': serializedPaths,
      'version': 1, // For future compatibility
    };
  }
  
  // Load from serialized data
  void fromMap(Map<String, dynamic> map) {
    clear();
    
    if (map.containsKey('paths')) {
      final List<dynamic> pathsData = map['paths'];
      
      for (final pathData in pathsData) {
        final String operation = pathData['operation'];
        final List<dynamic> pointsData = pathData['points'];
        
        if (pointsData.isNotEmpty) {
          final path = Path();
          
          // First point
          final firstPoint = pointsData[0];
          path.moveTo(firstPoint['x'], firstPoint['y']);
          
          // Remaining points
          for (int i = 1; i < pointsData.length; i++) {
            final point = pointsData[i];
            path.lineTo(point['x'], point['y']);
          }
          
          // Close the path
          path.close();
          
          // Add to collections
          paths.add(path);
          operations.add(operation == 'add' ? PathOperation.union : PathOperation.difference);
        }
      }
    }
  }
  
  // Check if the region data is empty
  bool get isEmpty => paths.isEmpty && currentPath == null;
  
  // Check if the region data contains actual regions
  bool get hasRegions => paths.isNotEmpty;
  
  // Clear all paths
  void clear() {
    paths.clear();
    operations.clear();
    currentPath = null;
    _currentPoints.clear();
  }
  
  // Undo the last path
  void undoLastPath() {
    if (paths.isNotEmpty) {
      paths.removeLast();
      operations.removeLast();
    }
  }
}