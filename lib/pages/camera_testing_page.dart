import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ai_device_manager/device.dart';
import 'package:ai_device_manager/utils/app_theme.dart';
import 'package:ai_device_manager/l10n/app_localizations.dart';
//import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:ai_device_manager/l10n/context_extensions.dart';

class CameraTestingPage extends StatefulWidget {
  final Device device;
  final String userId;

  const CameraTestingPage({
    Key? key,
    required this.device,
    required this.userId,
  }) : super(key: key);

  @override
  State<CameraTestingPage> createState() => _CameraTestingPageState();
}



class _CameraTestingPageState extends State<CameraTestingPage> with TickerProviderStateMixin {
  // Camera controller
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isFrontCamera = false;

  // Captured image and processing states
  File? _capturedImage;
  bool _isProcessing = false;
  bool _isUploading = false;
  String _processingStatus = '';
  Uint8List? _imageBytes;
  
  // Inference results
  Map<String, dynamic>? _inferenceResults;
  
  // Animation controllers for result highlighting
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Text controllers for editing device info
  late TextEditingController _nameController;
  late TextEditingController _taskDescriptionController;
  late String _selectedInferenceMode;

  // Constants
  static const String _inferenceApiUrl = 
      "https://europe-west4-aimanagerfirebasebackend.cloudfunctions.net/perform_inference";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _checkCameraPermission();
    
    // Initialize device info controllers
    _nameController = TextEditingController(text: widget.device.name);
    _taskDescriptionController = TextEditingController(
      text: widget.device.taskDescription ?? ''
    );
    _selectedInferenceMode = widget.device.inferenceMode;
    
    // Initialize animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _pulseController.dispose();
    _nameController.dispose();
    _taskDescriptionController.dispose();
    super.dispose();
  }

Future<void> _setupCameraForWeb(int cameraIndex) async {
  if (_cameraController != null) {
    await _cameraController!.dispose();
  }

  if (_cameras.isEmpty || cameraIndex >= _cameras.length) {
    return;
  }

  // For web, use more compatible settings
  _cameraController = CameraController(
    _cameras[cameraIndex],
    ResolutionPreset.medium, // Lower resolution for better compatibility
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.jpeg,
  );

  try {
    await _cameraController!.initialize();
    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
        _isFrontCamera = _cameras[cameraIndex].lensDirection == CameraLensDirection.front;
      });
    }
  } catch (e) {
    print('Error initializing web camera: $e');
    // Log detailed error for debugging
    if (e is CameraException) {
      print('Camera error: ${e.code} - ${e.description}');
    }
  }
}
  
  Future<void> _updateDevice() async {
    try {
      await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('devices')
        .doc(widget.device.id)
        .update({
          'name': _nameController.text,
          'taskDescription': _taskDescriptionController.text,
          'inferenceMode': _selectedInferenceMode,
        });
    } catch (e) {
      print('Error updating device: $e');
    }
  }

  Future<void> _checkCameraPermission() async {
    try {
      final cameraPermission = await Permission.camera.request();
      if (cameraPermission != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.cameraPermissionDenied ?? 'Camera permission denied')),
          );
        }
      } else if (!_isCameraInitialized) {
        // If permissions are granted but camera isn't initialized, start retry mechanism
        _startCameraInitRetry();
      }
    } catch (e) {
      print('Error checking camera permission: $e');
    }
  }

  void _startCameraInitRetry() {
    // Check every 1 second if camera is still not initialized
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !_isCameraInitialized) {
        print('Retrying camera initialization...');
        _initializeCamera().then((_) {
          if (!_isCameraInitialized && mounted) {
            // If still not initialized, try again
            _startCameraInitRetry();
          }
        });
      }
    });
  }

Future<void> _initializeCamera() async {
  try {
    _cameras = await availableCameras();
    
    if (_cameras.isEmpty) {
      setState(() {
        _isCameraInitialized = false;
      });
      return;
    }

    // Log available cameras for debugging
    print('Available cameras:');
    for (int i = 0; i < _cameras.length; i++) {
      print('Camera $i: ${_cameras[i].lensDirection}, ${_cameras[i].name}');
    }

    // Find the back camera for initial use
    int backCameraIndex = _cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back
    );
    
    // If no back camera, use the first available camera
    int initialCameraIndex = backCameraIndex >= 0 ? backCameraIndex : 0;
    
    if (kIsWeb) {
      // Web-specific camera setup
      setState(() {
        _isFrontCamera = _cameras[initialCameraIndex].lensDirection == CameraLensDirection.front;
      });
      await _setupCameraForWeb(initialCameraIndex);
    } else {
      // Mobile camera setup
      await _setupCamera(initialCameraIndex);
    }
    
    // If initialization was successful, no need to retry
    if (_isCameraInitialized) {
      print('Camera initialized successfully');
    }
  } catch (e) {
    print('Error initializing camera: $e');
  }
}

  Future<void> _setupCamera(int cameraIndex) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    if (_cameras.isEmpty || cameraIndex >= _cameras.length) {
      return;
    }

    // Create new controller
    _cameraController = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isFrontCamera = cameraIndex == (_cameras.length > 1 ? 1 : 0);
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

Future<void> _switchCamera() async {
  if (_cameras.length <= 1) return;

  // Keep track of which camera index we're currently using and which we want to switch to
  int currentIndex = _cameras.indexWhere((camera) => 
      (_isFrontCamera && camera.lensDirection == CameraLensDirection.front) ||
      (!_isFrontCamera && camera.lensDirection == CameraLensDirection.back));
  
  if (currentIndex < 0) currentIndex = 0;
  
  // Find the index of a camera with the opposite direction
  int targetIndex = -1;
  for (int i = 0; i < _cameras.length; i++) {
    if (i != currentIndex) {
      if (_isFrontCamera && _cameras[i].lensDirection == CameraLensDirection.back) {
        targetIndex = i;
        break;
      } else if (!_isFrontCamera && _cameras[i].lensDirection == CameraLensDirection.front) {
        targetIndex = i;
        break;
      }
    }
  }
  
  // If we didn't find an opposite camera, just try the next camera
  if (targetIndex < 0) {
    targetIndex = (currentIndex + 1) % _cameras.length;
  }
  
  // Log what we're doing
  print('Switching from camera $currentIndex (${_cameras[currentIndex].lensDirection}) to camera $targetIndex (${_cameras[targetIndex].lensDirection})');
  
  setState(() {
    _isCameraInitialized = false;
  });
  
  if (kIsWeb) {
    await _setupCameraForWeb(targetIndex);
  } else {
    await _setupCamera(targetIndex);
  }
}

Future<void> _takePicture() async {
  if (!_isCameraInitialized || _isProcessing || _cameraController == null) {
    print('Cannot take picture: Camera not initialized or already processing');
    return;
  }

  setState(() {
    _isProcessing = true;
    _inferenceResults = null;
    _processingStatus = 'Capturing image...';
  });

  try {
    print('[WEB DEBUG] Starting to take picture...');
    
    // Take the picture
    final XFile photo = await _cameraController!.takePicture();
    print('[WEB DEBUG] Picture taken, path: ${photo.path}');
    
    if (kIsWeb) {
      print('[WEB DEBUG] Processing for web platform');
      
      try {
        // For web, use XFile directly
        final Uint8List imageBytes = await photo.readAsBytes();
        print('[WEB DEBUG] Successfully read ${imageBytes.length} bytes from XFile');
        
        setState(() {
          _imageBytes = imageBytes;
          _capturedImage = null;
          _processingStatus = 'Image captured for web';
        });
        
        print('[WEB DEBUG] About to call _processInference()');
        await _processInference();
      } catch (webError) {
        print('[WEB DEBUG] Error in web-specific image processing: $webError');
        throw webError; // Re-throw to be caught by outer catch
      }
    } else {
      // Mobile-specific code (unchanged)
      final File originalFile = File(photo.path);
      final File resizedFile = await _resizeImage(originalFile, 1036);
      
      setState(() {
        _capturedImage = resizedFile;
        _imageBytes = null;
        _processingStatus = 'Image captured and optimized';
      });
      
      await _processInference();
    }
  } catch (e) {
    print('[WEB DEBUG] Error in _takePicture: $e');
    setState(() {
      _isProcessing = false;
      _processingStatus = 'Error: ${e.toString()}';
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
    }
  }
}

Future<File> _resizeImage(File inputFile, int targetSize) async {
  try {
    
    final Uint8List bytes = await inputFile.readAsBytes();
    final img.Image? originalImage = img.decodeImage(bytes);
    
    if (originalImage == null) {
      return inputFile; // Return original if decode fails
    }
    
    // Calculate dimensions while maintaining aspect ratio
    int width, height;
    if (originalImage.width > originalImage.height) {
      // Landscape image
      width = targetSize;
      height = (originalImage.height * targetSize / originalImage.width).round();
    } else {
      // Portrait or square image
      height = targetSize;
      width = (originalImage.width * targetSize / originalImage.height).round();
    }
    
    // Resize the image
    final img.Image resizedImage = img.copyResize(
      originalImage,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear
    );
    
    // Center crop to square if needed
    img.Image squareImage;
    if (width != height) {
      final cropSize = min(width, height);
      final x = (width - cropSize) ~/ 2;
      final y = (height - cropSize) ~/ 2;
      squareImage = img.copyCrop(
        resizedImage,
        x: x,
        y: y,
        width: cropSize,
        height: cropSize,
      );
    } else {
      squareImage = resizedImage;
    }
    
    // Encode as JPEG
    final Uint8List outputBytes = Uint8List.fromList(
      img.encodeJpg(squareImage, quality: 90)
    );
    
    // Create a temporary file with the resized image
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/resized_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File outputFile = File(tempPath);
    await outputFile.writeAsBytes(outputBytes);
    
    return outputFile;
  } catch (e) {
    print('Error resizing image: $e');
    return inputFile; // Return original if resize fails
  }
}
  
Future<String?> _uploadImageToStorage() async {
  if (_capturedImage == null && _imageBytes == null) {
    print('[WEB DEBUG] No image data available for upload');
    return null;
  }
  
  setState(() {
    _isUploading = true;
    _processingStatus = 'Uploading image...';
  });
  
  try {
    // Generate a timestamp-based path
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'users/${widget.userId}/devices/${widget.device.id}/testing/${timestamp}.jpg';
    print('[WEB DEBUG] Upload path: $path');
    
    // Create a storage reference
    final Reference storageRef = FirebaseStorage.instance.ref().child(path);
    
    // Upload with platform-specific handling
    TaskSnapshot uploadTask;
    
    if (kIsWeb) {
      if (_imageBytes == null) {
        throw Exception('No image bytes available for web upload');
      }
      
      print('[WEB DEBUG] Uploading web image bytes (${_imageBytes!.length} bytes)');
      
      // Try a more direct upload approach for web
      uploadTask = await storageRef.putData(
        _imageBytes!,
        SettableMetadata(contentType: 'image/jpeg')
      );
      
      print('[WEB DEBUG] Web upload completed. Status: ${uploadTask.state}');
    } else {
      // Mobile code (unchanged)
      if (_capturedImage == null) {
        throw Exception('No image file available for mobile upload');
      }
      
      uploadTask = await storageRef.putFile(_capturedImage!);
    }
    
    // Get the download URL
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    print('[WEB DEBUG] Upload succeeded. Download URL: $downloadUrl');
    
    setState(() {
      _isUploading = false;
      _processingStatus = 'Image uploaded';
    });
    
    return path;
  } catch (e) {
    print('[WEB DEBUG] Error uploading image: $e');
    setState(() {
      _isUploading = false;
      _processingStatus = 'Error uploading image: ${e.toString()}';
    });
    return null;
  }
}
  
Future<void> _processInference() async {
  print('[WEB DEBUG] Starting _processInference');
  
  // First upload the image to Firebase Storage
  final imagePath = await _uploadImageToStorage();
  if (imagePath == null) {
    print('[WEB DEBUG] Failed to upload image, cannot proceed with inference');
    setState(() {
      _isProcessing = false;
      _processingStatus = 'Failed to upload image';
    });
    return;
  }
  
  setState(() {
    _processingStatus = 'Running inference...';
  });
  
  try {
    print('[WEB DEBUG] Calling inference API with path: $imagePath');
    
    final Uri apiUri = Uri.parse(_inferenceApiUrl);
    print('[WEB DEBUG] API URL: $apiUri');
    
    final Map<String, dynamic> requestBody = {
      'user_id': widget.userId,
      'device_id': widget.device.id,
      'image_path': imagePath,
    };
    
    print('[WEB DEBUG] Request body: ${json.encode(requestBody)}');
    
    final response = await http.post(
      apiUri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestBody),
    );
    
    print('[WEB DEBUG] API response status: ${response.statusCode}');
    print('[WEB DEBUG] API response body: ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');
    
    if (response.statusCode == 200) {
      // Process successful response
      final result = json.decode(response.body);
      
      setState(() {
        _inferenceResults = result;
        _isProcessing = false;
        _processingStatus = 'Inference complete';
      });
      
      _pulseController.reset();
      _pulseController.repeat(reverse: true);
    } else {
      print('[WEB DEBUG] Error from inference API: ${response.statusCode} - ${response.body}');
      setState(() {
        _isProcessing = false;
        _processingStatus = 'API error: ${response.statusCode}';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode} - ${response.body.substring(0, min(100, response.body.length))}')),
        );
      }
    }
  } catch (e) {
    print('[WEB DEBUG] Error calling inference API: $e');
    setState(() {
      _isProcessing = false;
      _processingStatus = 'Network error: $e';
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }
}

  // Function to parse and display Moondream API results
  Widget _buildResultsText() {
    if (_inferenceResults == null) return const SizedBox.shrink();
    
    // Log the full result for debugging
    developer.log('Full inference results: ${_inferenceResults!.toString().substring(0, min(500, _inferenceResults.toString().length))}...');
    
    // Different display based on inference mode
    switch (widget.device.inferenceMode) {
      case 'Point':
        // Extract points from our merged results
        final points = _inferenceResults!.containsKey('points') 
            ? List.from(_inferenceResults!['points'] ?? [])
            : [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Points Detected: ${points.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (points.isEmpty)
              const Text(
                'No points detected',
                style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
              )
            else
              for (var point in points)
                Text(
                  '• ${point['class'] ?? 'Point'} at (${(point['x'] * 1024).toInt()}, ${(point['y'] * 1024).toInt()}) - ${((point['score'] ?? 0.5) * 100).toInt()}% confidence',
                  style: const TextStyle(color: Colors.white),
                ),
          ],
        );
        
      case 'Detect':
        // Extract objects from our merged results
        final objects = _inferenceResults!.containsKey('objects') 
            ? List.from(_inferenceResults!['objects'] ?? [])
            : [];
        
        // Group objects by class
        final Map<String, List<dynamic>> objectsByClass = {};
        for (var obj in objects) {
          final className = obj['class'] ?? 'Object';
          if (!objectsByClass.containsKey(className)) {
            objectsByClass[className] = [];
          }
          objectsByClass[className]!.add(obj);
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Objects Detected: ${objects.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (objects.isEmpty)
              const Text(
                'No objects detected',
                style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
              )
            else
              for (var entry in objectsByClass.entries)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key}: ${entry.value.length} found',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    for (var obj in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                        child: Text(
                          _getObjectText(obj),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
          ],
        );
        
      case 'VQA':
        // Extract answer from the result
        final result = _inferenceResults!['result'] ?? {};
        final answer = result['answer'] ?? 'No answer provided';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Response:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              answer,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        );
        
      case 'Caption':
        // Extract caption from the result
        final result = _inferenceResults!['result'] ?? {};
        final caption = result['caption'] ?? 'No caption provided';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Caption:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              caption,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        );
        
      default:
        return const Text(
          'Unsupported inference mode',
          style: TextStyle(color: Colors.white),
        );
    }
  }

  // Helper to get text description of an object
  String _getObjectText(Map<dynamic, dynamic> obj) {
    // Extract bounding box coordinates
    final bbox = obj['bbox'] ?? {};
    final x1 = bbox['x1']?.toInt() ?? 0;
    final y1 = bbox['y1']?.toInt() ?? 0;
    final x2 = bbox['x2']?.toInt() ?? 0;
    final y2 = bbox['y2']?.toInt() ?? 0;
    
    // Extract score
    final score = obj['score'] ?? 0.0;
    
    return 'Object at ($x1,$y1,$x2,$y2) - ${(score * 100).toInt()}% confidence';
  }

  // Function to draw visual overlay for results
  Widget _buildResultsOverlay() {
    if (_inferenceResults == null) return const SizedBox.shrink();
    
    switch (widget.device.inferenceMode) {
      case 'Point':
        final points = _inferenceResults!.containsKey('points') 
            ? List.from(_inferenceResults!['points'] ?? [])
            : [];
        return CustomPaint(
          painter: PointPainter(points, _pulseAnimation.value),
        );
        
      case 'Detect':
        final objects = _inferenceResults!.containsKey('objects') 
            ? List.from(_inferenceResults!['objects'] ?? [])
            : [];
        return CustomPaint(
          painter: BoundingBoxPainter(objects),
        );
        
      case 'VQA':
      case 'Caption':
      default:
        // No visual overlay for text-based results
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cameraTesting ?? 'Camera Testing'),
        actions: [
          // Device info edit button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _editDeviceInfo,
          ),
          // Camera switch button
          if (_cameras.length > 1 && _capturedImage == null)
            IconButton(
              icon: const Icon(Icons.flip_camera_android),
              onPressed: _switchCamera,
            ),
        ],
      ),
      body: Container(
        color: Colors.black, // Black background for the entire page
        child: _buildBody(),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Main content: camera/image + results
        Expanded(
          child: _capturedImage == null
              ? _buildCameraPreview()
              : _buildCapturedImageWithResults(),
        ),
        
        // Bottom info section showing the current mode
        Container(
          color: Colors.black.withOpacity(0.7),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            'Mode: ${_getInferenceModeLabel(widget.device.inferenceMode)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _initializeCamera();
                },
                child: Text(context.l10n.retry ?? 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate how to center-crop the camera preview to fit a square
    return Center(
      child: AspectRatio(
        aspectRatio: 1.0,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapturedImageWithResults() {
    if (_capturedImage == null && _imageBytes == null) return const SizedBox.shrink();
    
    return Column(
      children: [
        // Image with overlaid results
        Expanded(
          flex: 2, // Give more space to the image
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              if (kIsWeb && _imageBytes != null)
                Image.memory(
                  _imageBytes!,
                  fit: BoxFit.contain,
                )
              else if (_capturedImage != null)
                Image.file(
                  _capturedImage!,
                  fit: BoxFit.contain,
                ),
              
              // Overlay based on inference mode
              if (_inferenceResults != null && !_isProcessing)
                _buildResultsOverlay(),
              
              // Processing indicator
              if (_isProcessing)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          _processingStatus,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                
              // Reset button
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  onPressed: () {
                    setState(() {
                      _capturedImage = null;
                      _inferenceResults = null;
                      _pulseController.stop();
                    });
                  },
                  backgroundColor: Colors.white.withOpacity(0.7),
                  child: const Icon(Icons.refresh, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
        
        // Scrollable Results section
        if (_inferenceResults != null && !_isProcessing)
          Expanded(
            flex: 1, // Give limited space to results section
            child: Container(
              width: double.infinity,
              color: Colors.black.withOpacity(0.7),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildResultsText(),
              ),
            ),
          ),
      ],
    );
  }

Widget _buildFloatingActionButton() {
  // Hide capture button if already processing an image
  if (_isProcessing) return const SizedBox.shrink();
  
  // Show capture button only when camera is active
  if (_capturedImage != null || _imageBytes != null) return const SizedBox.shrink();

  return FloatingActionButton(
    backgroundColor: Colors.white,
    child: const Icon(Icons.camera_alt, color: Colors.black),
    onPressed: () {
      if (kIsWeb) {
        // For web, use a simpler approach initially to debug
        setState(() {
          _isProcessing = true;
          _processingStatus = "Web camera clicked";
        });
        
        // Add a delay to simulate processing and see if UI updates
        Future.delayed(Duration(seconds: 1), () {
          setState(() {
            _processingStatus = "Simulating upload...";
          });
          
          // Check if UI updates for this state change
          Future.delayed(Duration(seconds: 1), () {
            setState(() {
              _isProcessing = false;
              _processingStatus = "Simulation complete";
            });
          });
        });
      } else {
        // Regular takePicture for Android
        _takePicture();
      }
    },
  );
}
  
  String _getInferenceModeLabel(String mode) {
    switch (mode) {
      case 'Point':
        return 'Point Detection';
      case 'Detect':
        return 'Object Detection';
      case 'VQA':
        return 'Visual Q&A';
      case 'Caption':
        return 'Image Captioning';
      default:
        return mode;
    }
  }
  
  // Show dialog to edit device name and description
  void _editDeviceInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.deviceConfigPageEditDeviceInfo ?? 'Edit Device Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.deviceConfigPageDeviceName ?? 'Device Name',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _updateDevice(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _taskDescriptionController,
                decoration: InputDecoration(
                  labelText: context.l10n.deviceConfigPageTaskDescription ?? 'Task Description',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _updateDevice(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Inference Mode',
                  border: OutlineInputBorder(),
                ),
                value: _selectedInferenceMode,
                items: const [
                  DropdownMenuItem(value: 'Point', child: Text('Point Detection')),
                  DropdownMenuItem(value: 'Detect', child: Text('Object Detection')),
                  DropdownMenuItem(value: 'VQA', child: Text('Visual Q&A')),
                  DropdownMenuItem(value: 'Caption', child: Text('Image Captioning')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedInferenceMode = value;
                    });
                    _updateDevice();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.done ?? 'Done'),
            ),
          ],
        );
      },
    );
  }
}

// Custom painter for points
class PointPainter extends CustomPainter {
  final List points;
  final double pulse;

  PointPainter(this.points, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    // Define colors for different classes
    final classColors = {
      'default': Colors.red,
      // Add more class-specific colors as needed
    };

    for (var point in points) {
      // Get coordinates (normalized 0-1)
      final x = point['x'] ?? 0.5;
      final y = point['y'] ?? 0.5;

      // Scale to canvas size
      final scaledX = x * size.width;
      final scaledY = y * size.height;

      // Get class name for color selection
      final className = point['class'] ?? 'default';
      final color = (classColors[className] ?? classColors['default'])!;

      // Draw point marker
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // Outer pulsing circle
      canvas.drawCircle(
        Offset(scaledX, scaledY),
        20 * pulse, // Pulsing effect
        Paint()
          ..color = Color.fromRGBO(color.red, color.green, color.blue, 0.3)
          ..style = PaintingStyle.fill,
      );

      // Inner fixed circle
      canvas.drawCircle(
        Offset(scaledX, scaledY),
        8,
        paint,
      );

      // Draw crosshairs
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2;

      // Horizontal line
      canvas.drawLine(
        Offset(scaledX - 15, scaledY),
        Offset(scaledX + 15, scaledY),
        linePaint,
      );

      // Vertical line
      canvas.drawLine(
        Offset(scaledX, scaledY - 15),
        Offset(scaledX, scaledY + 15),
        linePaint,
      );

      // Draw class label
      final textSpan = TextSpan(
        text: className,
        style: TextStyle(
          color: Colors.white,
          backgroundColor: Color.fromRGBO(color.red, color.green, color.blue, 0.7),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(scaledX + 10, scaledY - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PointPainter oldDelegate) {
    return pulse != oldDelegate.pulse || points != oldDelegate.points;
  }
}

// Custom painter for bounding boxes
class BoundingBoxPainter extends CustomPainter {
  final List objects;
  
  BoundingBoxPainter(this.objects);
  
  @override
  void paint(Canvas canvas, Size size) {
    // Define colors for different classes
    final Map<String, Color> classColors = {};
    final defaultColors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
    ];
    
    // Map class names to colors for consistency
    final Set<String> classNames = {};
    for (var obj in objects) {
      final className = obj['class'] ?? 'Object';
      classNames.add(className);
    }
    
    int colorIndex = 0;
    for (var className in classNames) {
      classColors[className] = defaultColors[colorIndex % defaultColors.length];
      colorIndex++;
    }
    
    for (var obj in objects) {
      final bbox = obj['bbox'] ?? {};
      final className = obj['class'] ?? 'Object';
      
      // Get coordinates (already scaled to 1024x1024)
      final double x1 = bbox['x1']?.toDouble() ?? 0;
      final double y1 = bbox['y1']?.toDouble() ?? 0;
      final double x2 = bbox['x2']?.toDouble() ?? 0;
      final double y2 = bbox['y2']?.toDouble() ?? 0;
      
      // Scale to canvas size - use the smallest dimension to ensure the entire
      // box is visible regardless of aspect ratio
      final double scaleFactor = min(
        size.width / 1024.0, 
        size.height / 1024.0
      );
      
      // Center the content on the canvas
      final double xOffset = (size.width - 1024.0 * scaleFactor) / 2;
      final double yOffset = (size.height - 1024.0 * scaleFactor) / 2;
      
      // Apply scaling and centering
      final scaledX1 = x1 * scaleFactor + xOffset;
      final scaledY1 = y1 * scaleFactor + yOffset;
      final scaledX2 = x2 * scaleFactor + xOffset;
      final scaledY2 = y2 * scaleFactor + yOffset;
      
      // Get color for this class
      final color = classColors[className] ?? defaultColors[0];
      
      // Draw rectangle
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawRect(
        Rect.fromPoints(
          Offset(scaledX1, scaledY1),
          Offset(scaledX2, scaledY2)
        ),
        paint
      );
      
      // Draw class label background
      final labelPaint = Paint()
        ..color = color.withOpacity(0.7)
        ..style = PaintingStyle.fill;
        
      final labelText = className;
      
      // Measure text width
      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // Draw label background
      canvas.drawRect(
        Rect.fromLTWH(
          scaledX1, 
          scaledY1 - 22,
          textPainter.width + 10,
          22
        ),
        labelPaint
      );
      
      // Draw class label text
      textPainter.paint(
        canvas,
        Offset(scaledX1 + 5, scaledY1 - 20)
      );
      
      // Draw score label
      final score = obj['score'] ?? 0.0;
      final scoreText = '${(score * 100).toInt()}%';
      
      final scoreSpan = TextSpan(
        text: scoreText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      
      final scoreTextPainter = TextPainter(
        text: scoreSpan,
        textDirection: TextDirection.ltr,
      );
      
      scoreTextPainter.layout();
      scoreTextPainter.paint(
        canvas,
        Offset(scaledX2 - scoreTextPainter.width - 5, scaledY2 - 16)
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return objects != oldDelegate.objects;
  }
}



