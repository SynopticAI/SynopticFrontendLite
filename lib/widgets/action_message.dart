// Fixed ActionMessage to properly display icon

import 'package:flutter/material.dart';
import '../services/listener_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActionMessage extends StatefulWidget {
  final String userId;
  final String deviceId;
  final String messageTimestamp;
  final String action;
  final Map<String, dynamic>? actionResult;
  final Function() onActionComplete;

  const ActionMessage({
    Key? key,
    required this.userId,
    required this.deviceId,
    required this.messageTimestamp,
    required this.action,
    this.actionResult,
    required this.onActionComplete,
  }) : super(key: key);

  @override
  State<ActionMessage> createState() => _ActionMessageState();
}

class _ActionMessageState extends State<ActionMessage> {
  final ListenerService _listenerService = ListenerService();
  Map<String, dynamic> _actionState = {};
  bool _isComplete = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // If we have actionResult directly from batch tooling, use it immediately
    if (widget.actionResult != null && widget.actionResult!.isNotEmpty) {
      // Initialize with the action result
      _actionState = {
        'status': widget.actionResult!['status'] ?? 'processing',
        'actionDescription': _getActionDescription(),
        'progress': widget.actionResult!['progress'] ?? '1/1',
      };
      
      // If result includes additional data, add it
      if (widget.actionResult!.containsKey('message')) {
        if (_actionState.containsKey('textArray')) {
          _actionState['textArray'].add(widget.actionResult!['message']);
        } else {
          _actionState['textArray'] = [widget.actionResult!['message']];
        }
      }
      
      // For specific action data
      if (widget.action == 'setClasses') {
        if (widget.actionResult!.containsKey('classes')) {
          _actionState['classes'] = widget.actionResult!['classes'];
        }
        if (widget.actionResult!.containsKey('classDescriptions')) {
          _actionState['classDescriptions'] = widget.actionResult!['classDescriptions'];
        }
      }
      
      // Mark as complete if successful
      if (widget.actionResult!['status'] == 'success') {
        _isComplete = true;
      }
      
      _isInitialized = true;
    }
    
    // Always start the listener for compatibility and to get image URLs
    _startListener();
  }

  @override
  void dispose() {
    _listenerService.stopListener(widget.messageTimestamp);
    super.dispose();
  }

  String _getActionDescription() {
    // Get a user-friendly description based on action
    switch (widget.action) {
      case 'createDeviceIcon':
        return 'Creating device icon';
      case 'setClasses':
        return 'Setting up classification classes';
      default:
        return ListenerService.getActionDescription(widget.action);
    }
  }

  void _startListener() {
    _listenerService.startListener(
      userId: widget.userId,
      deviceId: widget.deviceId,
      messageTimestamp: widget.messageTimestamp,
      action: widget.action,
      onUpdate: (data) {
        setState(() => _actionState = data);
      },
      onComplete: () {
        setState(() => _isComplete = true);
        widget.onActionComplete();
      },
    );
  }

  Widget _buildProgressBar() {
    final progress = _actionState['progress'] as String?;
    if (progress == null) return const SizedBox.shrink();

    final double progressValue = ListenerService.calculateProgressValue(progress);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_actionState['actionDescription'] ?? _getActionDescription()}: $progress',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progressValue,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            _isComplete ? Colors.green : Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildTextArray() {
    final List<String> texts = List<String>.from(_actionState['textArray'] ?? []);
    if (texts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: texts.map((text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(text),
      )).toList(),
    );
  }

  Widget _buildImageGrid() {
    final List<String> imageUrls = List<String>.from(_actionState['imageUrls'] ?? []);
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: imageUrls.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            imageUrls[index],
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / 
                        loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActionSpecificContent() {
    // Add any action-specific widgets based on action type
    switch (widget.action) {
      case 'setClasses':
        final classes = _actionState['classes'] as List<dynamic>?;
        final classDescriptions = _actionState['classDescriptions'] as List<dynamic>?;
        
        if (classes != null && classes.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Classes defined:', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              ...List.generate(classes.length, (index) {
                final className = classes[index].toString();
                final description = classDescriptions != null && index < classDescriptions.length
                    ? classDescriptions[index].toString()
                    : '';
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    description.isNotEmpty
                        ? '• $className: $description'
                        : '• $className',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }),
            ],
          );
        }
        break;
      
      case 'createDeviceIcon':
        // Show icon if available
        final List<String> imageUrls = List<String>.from(_actionState['imageUrls'] ?? []);
        if (imageUrls.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Device icon created:', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrls.first,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          );
        } else {
          // Show message about the icon creation
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text(
              'Device icon will be generated based on your device description',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
          );
        }
      
      default:
        return const SizedBox.shrink();
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.centerLeft,
      child: Card(
        color: Colors.grey[50],
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getActionIcon(),
                    size: 16,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getActionTitle(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (_isComplete)
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    )
                  else
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildProgressBar(),
              const SizedBox(height: 4),
              _buildActionSpecificContent(),
              if (_actionState.containsKey('textArray')) ...[
                const SizedBox(height: 8),
                _buildTextArray(),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  String _getActionTitle() {
    switch (widget.action) {
      case 'createDeviceIcon':
        return 'Creating Device Icon';
      case 'setClasses':
        return 'Setting Up Classification Classes';
      default:
        return widget.action;
    }
  }
  
  IconData _getActionIcon() {
    switch (widget.action) {
      case 'createDeviceIcon':
        return Icons.image;
      case 'setClasses':
        return Icons.category;
      default:
        return Icons.settings;
    }
  }
}