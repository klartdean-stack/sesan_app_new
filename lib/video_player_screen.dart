import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String? videoUrl;
  const VideoPlayerScreen({super.key, this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _hasError = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() async {
    // ១. ពិនិត្យ URL
    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    try {
      // ២. បង្កើត Controller និងផ្ទុកវីដេអូ
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl!),
      );

      await controller.initialize();

      // ៣. ចាក់វីដេអូដោយស្វ័យប្រវត្តិ
      await controller.play();

      if (mounted) {
        setState(() {
          _controller = controller;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Video Error: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "វីដេអូបង្ហាញទំនិញ",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Center(
        child: _hasError
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.videocam_off, color: Colors.white, size: 60),
            SizedBox(height: 10),
            Text(
              "មិនអាចមើលវីដេអូបានទេ",
              style: TextStyle(color: Colors.white),
            ),
          ],
        )
            : _isLoading
            ? const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 10),
            Text(
              "កំពុងផ្ទុកវីដេអូ...",
              style: TextStyle(color: Colors.white),
            ),
          ],
        )
            : (_controller != null && _controller!.value.isInitialized)
            ? GestureDetector(
          onTap: () {
            setState(() {
              _controller!.value.isPlaying
                  ? _controller!.pause()
                  : _controller!.play();
            });
          },
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        )
            : const SizedBox(),
      ),
      floatingActionButton:
      (_controller != null && _controller!.value.isInitialized)
          ? FloatingActionButton(
        backgroundColor: Colors.white.withOpacity(0.5),
        onPressed: () {
          setState(() {
            _controller!.value.isPlaying
                ? _controller!.pause()
                : _controller!.play();
          });
        },
        child: Icon(
          _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.black,
        ),
      )
          : null,
    );
  }@override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}