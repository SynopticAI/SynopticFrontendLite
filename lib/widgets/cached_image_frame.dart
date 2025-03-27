import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CachedImageFrame extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Duration cacheDuration;

  const CachedImageFrame({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheDuration = const Duration(days: 30),
  }) : super(key: key);

  @override
  State<CachedImageFrame> createState() => _CachedImageFrameState();
}

class _CachedImageFrameState extends State<CachedImageFrame> {
  File? _cachedFile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (kIsWeb) {
      // For web, just set isLoading to false as we'll use Image.network directly
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final cachedFile = await _getCachedFile();
      if (cachedFile != null) {
        setState(() {
          _cachedFile = cachedFile;
          _isLoading = false;
        });
      } else {
        await _downloadAndCacheImage();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<String> _getFilePath() async {
    if (kIsWeb) return '';
    
    final cacheDir = await getTemporaryDirectory();
    final hash = md5.convert(utf8.encode(widget.imageUrl)).toString();
    return '${cacheDir.path}/img_$hash';
  }

  Future<File?> _getCachedFile() async {
    if (kIsWeb) return null;
    
    final path = await _getFilePath();
    final file = File(path);
    
    if (await file.exists()) {
      final fileStats = await file.stat();
      final age = DateTime.now().difference(fileStats.modified);
      
      if (age < widget.cacheDuration) {
        return file;
      } else {
        await file.delete();
        return null;
      }
    }
    return null;
  }

  Future<void> _downloadAndCacheImage() async {
    if (kIsWeb) return;

    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode == 200) {
        final path = await _getFilePath();
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes);
        
        if (mounted) {
          setState(() {
            _cachedFile = file;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to download image');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || (!kIsWeb && _cachedFile == null)) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: Icon(Icons.error),
        ),
      );
    }

    if (kIsWeb) {
      return Image.network(
        widget.imageUrl,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (context, error, stackTrace) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: Icon(Icons.error),
            ),
          );
        },
      );
    }

    return Image.file(
      _cachedFile!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: Icon(Icons.error),
          ),
        );
      },
    );
  }
}

/// Class to manage cache cleanup
class ImageCacheManager {
  static Future<void> cleanupOldCache() async {
    if (kIsWeb) return;  // Skip cleanup on web

    try {
      final cacheDir = await getTemporaryDirectory();
      final now = DateTime.now();
      
      // Get all files in cache directory
      final files = cacheDir.listSync();
      
      for (var entity in files) {
        if (entity is File && entity.path.contains('img_')) {
          final stats = await entity.stat();
          final age = now.difference(stats.modified);
          
          // Delete files older than 30 days
          if (age > const Duration(days: 30)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('Error cleaning image cache: $e');
    }
  }
}