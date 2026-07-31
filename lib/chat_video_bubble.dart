import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:path_provider/path_provider.dart';     // ✅ បន្ថែម

class ChatVideoBubble extends StatefulWidget {
  final String url;
  final String? localPath;
  final bool isSending;
  final double? progress;

  const ChatVideoBubble({
    super.key,
    required this.url,
    this.localPath,
    this.isSending = false,
    this.progress,
  });

  @override
  State<ChatVideoBubble> createState() => _ChatVideoBubbleState();
}

class _ChatVideoBubbleState extends State<ChatVideoBubble> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _error;
  String? _thumbnailPath; // ✅ thumbnail path

  @override
  void initState() {
    super.initState();
    if (widget.isSending && widget.localPath != null) {

    } else if (!widget.isSending && widget.url.isNotEmpty) {
      _initPlayer();
    }
  }



  Future<void> _initPlayer() async {
    try {
      if (widget.url.isEmpty || !widget.url.startsWith('http')) {
        setState(() => _error = "Invalid URL");
        return;
      }

      VideoPlayerController controller;
      try {
        final file = await DefaultCacheManager()
            .getSingleFile(widget.url)
            .timeout(const Duration(seconds: 10));
        controller = VideoPlayerController.file(file);
      } catch (e) {
        controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      }

      await controller.initialize().timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = "មិនអាចចាក់បាន");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSending) return _buildSendingWidget();
    if (_error != null) return _buildErrorWidget(_error!);
    if (!_isInitialized || _controller == null) return _buildLoadingWidget();
    return _buildPlayerWidget();
  }

  // ✅ SENDING — Thumbnail ពិតប្រាកដ ដូច Telegram!
  Widget _buildSendingWidget() {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
          alignment: Alignment.center,
          children: [
      // ✅ Thumbnail ពិត
      ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: _thumbnailPath != null
          ? Image.file(
        File(_thumbnailPath!),
        width: 200,
        height: 150,
        fit: BoxFit.cover,
      )
          : Container(
        color: Colors.grey[800],
        child: const Icon(
          Icons.videocam,
          color: Colors.grey,
          size: 40,
        ),
      ),
    ),

    // Overlay ខ្មៅ
    Container(
    decoration: BoxDecoration(
    color: Colors.black.withOpacity(0.45),
    borderRadius: BorderRadius.circular(16),
    ),
    ),
// Progress + %
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    value: widget.progress,
                    strokeWidth: 3,
                    valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.white24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.progress != null
                      ? "${(widget.progress! * 100).toInt()}%"
                      : "កំពុងផ្ញើ...",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
      ),
    );
  }

  Widget _buildPlayerWidget() {
    return GestureDetector(
      onTap: () => setState(() {
        _controller!.value.isPlaying
            ? _controller!.pause()
            : _controller!.play();
      }),
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller!),
            AnimatedOpacity(
              opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 40),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(color: Colors.red[600], fontSize: 12)),
        ],
      ),
    );
  }
}