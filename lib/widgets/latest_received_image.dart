import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/cached_image_frame.dart';

class LatestReceivedImage extends StatefulWidget {
  final String userId;
  final String deviceId;
  final double size;

  const LatestReceivedImage({
    Key? key,
    required this.userId,
    required this.deviceId,
    this.size = 80,
  }) : super(key: key);

  @override
  State<LatestReceivedImage> createState() => _LatestReceivedImageState();
}

class _LatestReceivedImageState extends State<LatestReceivedImage> {
  String? _imageUrl;
  String? _nextImageUrl;
  bool _isEnlarged = false;
  
  @override
  void initState() {
    super.initState();
    _fetchLatestImage();
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _fetchLatestImage();
        _startPeriodicRefresh();
      }
    });
  }

  Future<void> _fetchLatestImage() async {
    try {
      if (!mounted) return;

      final storageRef = FirebaseStorage.instance.ref()
          .child('users/${widget.userId}/devices/${widget.deviceId}/receiving');

      final ListResult result = await storageRef.listAll();
      
      if (result.items.isEmpty) {
        if (!mounted) return;
        setState(() {
          _nextImageUrl = null;
        });
        return;
      }

      // Sort items by name (timestamp) in descending order
      final sortedItems = result.items.toList()
        ..sort((a, b) => b.name.compareTo(a.name));

      // Get URL of latest image
      final latestUrl = await sortedItems.first.getDownloadURL();

      if (!mounted) return;
      
      // Only update if we have a new image
      if (latestUrl != _imageUrl) {
        setState(() {
          _imageUrl = latestUrl;
        });
      }

    } catch (e) {
      // Silently handle errors to prevent visual disruption
      print('Error fetching latest image: $e');
    }
  }

  void _showEnlargedView(BuildContext context) {
    setState(() => _isEnlarged = true);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                // Image
                if (_imageUrl != null)
                  CachedImageFrame(
                    key: ValueKey(_imageUrl),
                    imageUrl: _imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                else
                  Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.camera_alt, size: 48),
                    ),
                  ),
                
                // Close button overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        setState(() => _isEnlarged = false);
                        Navigator.of(context).pop();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

                // Timestamp overlay
                if (_imageUrl != null)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getTimestampFromUrl(_imageUrl!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ).then((_) => setState(() => _isEnlarged = false));
  }

  String _getTimestampFromUrl(String url) {
    // Extract timestamp from the URL
    final RegExp regExp = RegExp(r'/(\d+)\.(?:jpg|png)');
    final match = regExp.firstMatch(url);
    if (match != null) {
      final timestamp = int.tryParse(match.group(1) ?? '');
      if (timestamp != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // If no image yet, show camera icon
    if (_imageUrl == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.camera_alt),
      );
    }

    // Show the current image with tap handler
    return GestureDetector(
      onTap: () => _showEnlargedView(context),
      child: Hero(
        tag: 'latest_image_${widget.deviceId}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedImageFrame(
            key: ValueKey(_imageUrl),
            imageUrl: _imageUrl!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}