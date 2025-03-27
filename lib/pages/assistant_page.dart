import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/user_settings.dart';
import '../widgets/action_message.dart';
import '../widgets/setup_stage_display.dart';
import 'package:ai_device_manager/device.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai_device_manager/l10n/app_localizations.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:math';
import 'dart:async'; // For Timer
import 'package:ai_device_manager/utils/app_theme.dart';
// import 'package:ai_device_manager/pages/data_swipe_page.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ai_device_manager/pages/camera_testing_page.dart';

class AssistantPage extends StatefulWidget {
  final String userId;
  final String deviceId;

  const AssistantPage({
    Key? key,
    required this.userId,
    required this.deviceId,
  }) : super(key: key);

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  
  bool _isLoading = false;
  String? _currentMessageTimestamp;
  Device? _device;

  // Added for image handling
  final List<String> _attachedImageTimestamps = [];
  final List<String> _attachedImageUrls = [];
  bool _isUploadingImage = false;
  final ImagePicker _imagePicker = ImagePicker();

  // Added for speech to text with enhanced tracking
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _currentText = '';  // Stores the text before speech recognition started
  String _lastPartialResult = '';  // Stores the last partial result
  bool _speechInitialized = false;
  Timer? _listeningTimer;  // Timer to detect if listening stops unexpectedly

  static const String firebaseFunctionUrl = 
    'https://europe-west4-aimanagerfirebasebackend.cloudfunctions.net/assistant_chat';

  @override
  void initState() {
    super.initState();
    _sendInitialMessage();
    _fetchDeviceInfo();
    _initSpeech();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _sendEndOfConversation();
    _listeningTimer?.cancel();
    if (_isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  // Initialize speech to text
  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      setState(() {
        _speechInitialized = available;
      });
    } catch (e) {
      print('Error initializing speech recognition: $e');
      setState(() {
        _speechInitialized = false;
      });
    }
  }
  
  // Start a timer to monitor if speech recognition stops unexpectedly
  void _startListeningMonitor() {
    // Cancel any existing timer
    _listeningTimer?.cancel();
    
    // Create a new timer that checks every 2 seconds if we're still listening
    _listeningTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (mounted && _isListening) {
        // Check if SpeechToText is actually still listening
        if (!_speech.isListening) {
          print('Speech recognition stopped unexpectedly, updating UI...');
          setState(() {
            _isListening = false;
          });
          timer.cancel();
        }
      } else {
        // If we're not supposed to be listening or widget is disposed, cancel the timer
        timer.cancel();
      }
    });
  }

  // Handle speech recognition status changes with improved status tracking
  void _onSpeechStatus(String status) {
    if (mounted) {
      print('Speech recognition status: $status'); // Helpful for debugging
      
      // Update UI based on status
      setState(() {
        // Only consider it listening if the status is explicitly 'listening'
        if (status == 'listening') {
          _isListening = true;
        } else if (status == 'notListening' || status == 'done') {
          // If explicitly not listening or done, update UI
          _isListening = false;
        }
        // Note: We don't handle 'initialized' status here as it shouldn't affect the listening state
      });
    }
  }

  // Handle speech recognition errors with graceful UI recovery
  void _onSpeechError(dynamic error) {
    print('Speech recognition error: $error');
    
    if (mounted) {
      // Always update UI state to not listening on error
      setState(() {
        _isListening = false;
      });
      
      // Only show user-facing errors if they're meaningful
      if (error is String && 
          error.isNotEmpty && 
          !error.contains('recognition already started') && // Skip common errors
          !error.contains('recognition not started')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speech recognition error: $error'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // For no speech detected errors, provide more helpful message
      if (error is String && error.contains('no speech detected')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.noSpeechDetected ?? 'No speech detected. Try again?'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Handle speech recognition results - improved to prevent duplication
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (mounted) {
      setState(() {
        if (result.finalResult) {
          // For final results, we use the complete recognized text
          // and append it to the original text we saved at the start
          String fullText = _currentText;
          if (fullText.isNotEmpty && !fullText.endsWith(' ')) {
            fullText += ' ';
          }
          fullText += result.recognizedWords;
          _controller.text = fullText;
          
          // Reset tracking variables but keep the current text updated
          _lastPartialResult = '';
          
          // Move cursor to the end
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        } else if (result.recognizedWords.isNotEmpty) {
          // For partial results, replace the entire text field content
          // with the original text + current recognition
          
          // Store the base text before any recognition if this is the first partial result
          if (_lastPartialResult.isEmpty) {
            _currentText = _controller.text;
          }
          
          // Construct text by starting with the original text and adding new recognition
          String fullText = _currentText;
          if (fullText.isNotEmpty && !fullText.endsWith(' ')) {
            fullText += ' ';
          }
          fullText += result.recognizedWords;
          
          // Update text controller with the full text (no duplication)
          _controller.text = fullText;
          
          // Move cursor to the end
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
          
          // Remember the current partial result
          _lastPartialResult = result.recognizedWords;
        }
      });
    }
  }

  // Toggle speech recognition on/off - improved with reliable state handling
  Future<void> _toggleListening() async {
    // If currently listening according to our state, stop listening
    if (_isListening) {
      try {
        await _speech.stop();
        setState(() {
          _isListening = false;
        });
      } catch (e) {
        print('Error stopping speech recognition: $e');
        // Force the UI to update even if the API call fails
        setState(() {
          _isListening = false;
        });
      }
    } else {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.microphonePermissionDenied ?? 'Microphone permission denied')),
        );
        return;
      }
      
      // Ensure any previous listening session is fully stopped
      try {
        await _speech.stop();
      } catch (e) {
        // Ignore errors here, we're just making sure it's stopped
        print('Error ensuring speech recognition is stopped: $e');
      }
      
      // Initialize speech if not already done
      if (!_speechInitialized) {
        _speechInitialized = await _speech.initialize(
          onStatus: _onSpeechStatus,
          onError: _onSpeechError,
        );
      }
      
      if (_speechInitialized) {
        // Reset state tracking variables
        setState(() {
          _lastPartialResult = '';
          _currentText = _controller.text;
        });
        
        // Determine appropriate locale for speech recognition
        String? localeId;
        try {
          final userLanguage = await UserSettings().getCurrentLanguage();
          final availableLocales = await _speech.locales();
          
          // Try to find a matching locale for the current language
          for (var locale in availableLocales) {
            if (locale.localeId.startsWith(userLanguage)) {
              localeId = locale.localeId;
              break;
            }
          }
          
          // Use default locale if no match found
          if (localeId == null && availableLocales.isNotEmpty) {
            localeId = availableLocales.first.localeId;
          }
        } catch (e) {
          print('Error getting locale for speech recognition: $e');
        }
        
        // Start listening with increased timeouts for better user experience
        try {
          // Start listening with simplified parameters to avoid errors
          await _speech.listen(
            onResult: _onSpeechResult,
            localeId: localeId,
            listenFor: Duration(seconds: 60),
            pauseFor: Duration(seconds: 10),
            partialResults: true,
          );
          
          // Manually update state since we're catching potential errors with the return value
          setState(() {
            _isListening = true;
          });
          
          // Start a monitoring timer to check if speech recognition stops unexpectedly
          _startListeningMonitor();
        } catch (e) {
          print('Error starting speech recognition: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting speech recognition: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.speechNotAvailable ?? 'Speech recognition not available')),
        );
      }
    }
  }

  Future<void> _fetchDeviceInfo() async {
    try {
      final deviceDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('devices')
          .doc(widget.deviceId)
          .get();
      
      if (deviceDoc.exists) {
        setState(() {
          _device = Device.fromMap({
            ...deviceDoc.data() as Map<String, dynamic>,
            'id': widget.deviceId
          });
        });
      }
    } catch (e) {
      print('Error fetching device info: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Image handling methods
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        await _uploadImage(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage(XFile image) async {
    try {
      setState(() => _isUploadingImage = true); // Using the correct state variable
      
      // Load the original image file
      final File originalFile = File(image.path);
      final Uint8List originalBytes = await originalFile.readAsBytes();
      
      // Decode the image
      final img.Image? decodedImage = img.decodeImage(originalBytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }
      
      // Crop to square
      final int size = min(decodedImage.width, decodedImage.height);
      final int xOffset = (decodedImage.width - size) ~/ 2;
      final int yOffset = (decodedImage.height - size) ~/ 2;
      final img.Image squareImage = img.copyCrop(
        decodedImage,
        x: xOffset,
        y: yOffset,
        width: size,
        height: size,
      );
      
      // Resize to 1036x1036
      final img.Image resizedImage = img.copyResize(
        squareImage,
        width: 1036,
        height: 1036,
        interpolation: img.Interpolation.linear,
      );
      
      // Encode as JPEG
      final Uint8List resizedBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 90));
      
      // Create a temporary file for the resized image
      final String tempPath = image.path.replaceAll(
        RegExp(r'\.[^.]*$'),
        '_resized.jpg'
      );
      final File resizedFile = File(tempPath);
      await resizedFile.writeAsBytes(resizedBytes);
      
      // Continue with the upload process using the resized file
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String path = 'users/${widget.userId}/devices/${widget.deviceId}/assistant/$timestamp.jpg';
      
      // Create storage reference
      final storageRef = FirebaseStorage.instance.ref().child(path);
      
      // Upload resized image
      await storageRef.putFile(resizedFile);
      
      // Get download URL
      final downloadURL = await storageRef.getDownloadURL();
      
      if (mounted) {
        setState(() {
          _attachedImageTimestamps.add(timestamp);
          _attachedImageUrls.add(downloadURL);
          _isUploadingImage = false; // Using the correct state variable
        });
      }
      
      // Clean up the temporary file
      if (await resizedFile.exists()) {
        await resizedFile.delete();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false); // Using the correct state variable
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  void _removeAttachedImage(int index) {
    setState(() {
      _attachedImageTimestamps.removeAt(index);
      _attachedImageUrls.removeAt(index);
    });
  }

Future<void> _sendMessage(String message) async {
  if (_isLoading || _isUploadingImage) return;
  
  if (message.trim().isEmpty && _attachedImageTimestamps.isEmpty) return;

  // Store images for the message
  final List<String> messageThumbnails = List<String>.from(_attachedImageTimestamps);
  final List<String> messageImageUrls = List<String>.from(_attachedImageUrls);
  
  // Clear attached images immediately
  setState(() {
    _messages.add({
      "role": "user",
      "text": message,
      "imageTimestamps": messageThumbnails,
      "imageUrls": messageImageUrls,
    });
    _isLoading = true;
    _attachedImageTimestamps.clear();
    _attachedImageUrls.clear();
  });

  _scrollToBottom();
  _controller.clear();

  try {
    await _processAssistantResponse(
      message: message,
      promptType: "conversational",
      imageTimestamps: messageThumbnails,
    );
  } catch (e) {
    setState(() {
      _messages.add({
        "role": "assistant",
        "text": "Error: $e",
      });
      _isLoading = false;
    });
    _scrollToBottom();
  }
}

Future<void> _sendInitialMessage() async {
  setState(() => _isLoading = true);
  try {
    await _processAssistantResponse(
      message: "",
      promptType: "initial",
    );
  } catch (e) {
    setState(() {
      _messages.add({
        "role": "assistant",
        "text": "Error initializing chat: $e",
      });
      _isLoading = false;
    });
  }
}

  Future<void> _sendEndOfConversation() async {
    if (_messages.isEmpty) return;

    try {
      final userLanguage = await UserSettings().getCurrentLanguage();
      
      await http.post(
        Uri.parse(firebaseFunctionUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": widget.userId,
          "device_id": widget.deviceId,
          "prompt_type": "endOfConversation",
          "userLanguage": userLanguage,
          "conversation_history": _messages.map((msg) => {
            "role": msg["role"],
            "content": msg["text"] ?? "",
            "imageTimestamps": msg["imageTimestamps"] ?? [],
          }).toList(),
        }),
      );
    } catch (e) {
      print('Error in _sendEndOfConversation: $e');
    }
  }

Future<Map<String, dynamic>> _callAssistantChat({
  required String promptType,
  required String message,
  List<String>? imageTimestamps,
}) async {
  final userLanguage = await UserSettings().getCurrentLanguage();
  _currentMessageTimestamp = DateTime.now().millisecondsSinceEpoch.toString();

  final payload = {
    "user_id": widget.userId,
    "device_id": widget.deviceId,
    "prompt_type": promptType,
    "message": message,
    "userLanguage": userLanguage,
    "messageTimestamp": _currentMessageTimestamp,
    if (imageTimestamps != null && imageTimestamps.isNotEmpty) 
      "imageTimestamps": imageTimestamps,
    "conversation_history": _messages.map((msg) => {
      "role": msg["role"],
      "content": msg["text"] ?? "",
      "imageTimestamps": msg["imageTimestamps"] ?? [],
    }).toList(),
  };

  final response = await http.post(
    Uri.parse(firebaseFunctionUrl),
    headers: {"Content-Type": "application/json"},
    body: json.encode(payload),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to get response: ${response.body}');
  }

  return json.decode(response.body);
}

Future<void> _processAssistantResponse({
  required String message,
  required String promptType,
  List<String>? imageTimestamps,
}) async {
  final response = await _callAssistantChat(
    promptType: promptType,
    message: message,
    imageTimestamps: imageTimestamps,
  );

  // Extract the assistant's text reply
  String assistantReply = response["assistant_reply"] ?? "";
  
  // Extract any actions from the response
  List<Map<String, dynamic>> actions = [];
  
  // Check if response contains actions array
  if (response.containsKey("actions") && response["actions"] is List) {
    List<dynamic> actionsData = response["actions"];
    for (var actionData in actionsData) {
      // Extract relevant action data
      String toolName = actionData["tool"] ?? "unknown";
      String timestamp = actionData["timestamp"] ?? _currentMessageTimestamp ?? "none";
      var result = actionData["result"] ?? {};
      
      actions.add({
        "tool": toolName,
        "timestamp": timestamp,
        "result": result,
      });
    }
  }

  // First, add action messages to the conversation
  if (actions.isNotEmpty) {
    for (var actionInfo in actions) {
      setState(() {
        _messages.add({
          "role": "assistant",
          "isAction": true,
          "action": actionInfo["tool"],
          "timestamp": actionInfo["timestamp"],
          "result": actionInfo["result"],
        });
      });
      _scrollToBottom();
    }
    
    // Add a small delay to visually separate action messages from the text reply
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // Then, add the text response from the assistant
  // ALWAYS show assistantReply, even if empty (to maintain message order)
  setState(() {
    _messages.add({
      "role": "assistant",
      "text": assistantReply,
    });
    _isLoading = false;
  });
  _scrollToBottom();
}

Widget _buildMessage(Map<String, dynamic> message) {
  final bool isUser = message["role"] == "user";
  final bool isAction = message["isAction"] == true;
  final List<String> imageUrls = List<String>.from(message["imageUrls"] ?? []);

  if (isAction) {
    return ActionMessage(
      userId: widget.userId,
      deviceId: widget.deviceId,
      messageTimestamp: message["timestamp"],
      action: message["action"],
      // Pass any additional result data to the ActionMessage
      actionResult: message["result"],
      onActionComplete: () {
        // Action completion is now handled automatically by the backend
        // Just update UI if needed
        setState(() {});
      },
    );
  }

  // Parse message text for bold formatting
  Widget buildFormattedText(String text) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    
    // Use RegExp to find markdown bold patterns
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
    
    // Split the text by bold patterns
    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;
    
    for (Match match in boldPattern.allMatches(text)) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(
            color: isUser ? Colors.black87 : Colors.black,
          ),
        ));
      }
      
      // Add the bold text (without the ** markers)
      spans.add(TextSpan(
        text: match.group(1), // The text between **
        style: TextStyle(
          color: AppTheme.secondaryAccentColor,
          fontWeight: FontWeight.bold,
        ),
      ));
      
      lastMatchEnd = match.end;
    }
    
    // Add any remaining text after the last match
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(
          color: isUser ? Colors.black87 : Colors.black,
        ),
      ));
    }
    
    return RichText(
      text: TextSpan(
        children: spans,
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.all(8),
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Card(
      color: isUser ? Colors.blue[100] : Colors.grey[50],
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message["text"] != null && message["text"].isNotEmpty)
              buildFormattedText(message["text"]),
            if (imageUrls.isNotEmpty) ...[
              if (message["text"] != null && message["text"].isNotEmpty)
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate ideal image size to fit 3 in a row
                    // Account for spacing between images (8 * 2) and container padding
                    final imageSize = (constraints.maxWidth - 16 - (8 * 2)) / 3;
                    
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: imageUrls.map((url) => GestureDetector(
                        onTap: () {
                          // Show full-screen image when tapped
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: Image.network(url, fit: BoxFit.contain),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: imageSize,
                            height: imageSize,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )).toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
  );
}

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Display attached images
        if (_attachedImageUrls.isNotEmpty)
          Container(
            height: 100,
            margin: const EdgeInsets.all(8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _attachedImageUrls.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(_attachedImageUrls[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _removeAttachedImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        
        // Upload indicator
        if (_isUploadingImage)
          const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
        
        // Input row
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // Image attachment button
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: _isLoading || _isUploadingImage || _isListening ? null : _pickImage,
              ),
              
              // Expandable text field
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: _isListening 
                        ? context.l10n.listeningHint ?? 'Listening...' 
                        : context.l10n.typeYourMessage ?? 'Type your message...',
                    border: OutlineInputBorder(),
                    suffixIcon: _isListening 
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  enabled: !_isLoading && !_isUploadingImage && !_isListening,
                  maxLines: null, // Allow unlimited lines
                  minLines: 1,  // Start with one line
                  keyboardType: TextInputType.multiline, // Enable multiline input
                  textInputAction: TextInputAction.newline, // Add line break on Enter
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Speech to text button
              IconButton(
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                color: _isListening ? Colors.red : null,
                onPressed: (!_isLoading && !_isUploadingImage) ? _toggleListening : null,
              ),
              
              // Send button
              if (_isLoading || _isUploadingImage)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(),
                )
              else
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(_controller.text),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.assistantChat),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('devices')
            .doc(widget.deviceId)
            .snapshots(),
        builder: (context, snapshot) {
          // Use the stream data if available, otherwise fall back to the stored device
          Device? currentDevice = _device;
          
          if (snapshot.hasData && snapshot.data!.exists) {
            currentDevice = Device.fromMap({
              ...snapshot.data!.data() as Map<String, dynamic>,
              'id': widget.deviceId
            });
            
            // Update the stored device
            if (_device?.setupStage != currentDevice.setupStage) {
              Future.microtask(() {
                if (mounted) {
                  setState(() {
                    _device = currentDevice;
                  });
                }
              });
            }
          }
          
          return Stack(
            children: [
              Column(
                children: [
                  // Data Navigation Button - only shown when device is in appropriate setup stage
                  if (currentDevice != null && currentDevice.setupStage >= 1.0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: ElevatedButton.icon(
                        icon: Icon(
                          // Show analytics icon in testing stage, otherwise upload icon
                          // only testing button type for now, might add more for further setup stages later 
                          currentDevice.setupStage >= 1.0 ? Icons.analytics : Icons.analytics,
                          color: AppTheme.surfaceColor,
                        ),
                        label: Text(
                          currentDevice.setupStage >= 1.0 
                              ? context.l10n.testingMode ?? 'Test Your Model' 
                              : context.l10n.testingMode ?? 'Test Your Model',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColorMuted,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CameraTestingPage(
                                device: currentDevice!,
                                userId: widget.userId,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _buildMessage(_messages[index]),
                    ),
                  ),
                  _buildInputArea(),
                ],
              ),
              if (currentDevice != null)
                Positioned(
                  top: 20,
                  right: 0,
                  child: SetupStageDisplay(
                    device: currentDevice,
                    userId: widget.userId,
                    width: 50,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}