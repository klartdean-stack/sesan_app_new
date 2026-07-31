import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';


class VideoPlayerScreen extends StatefulWidget {
  final String? videoUrl; // អាចទទួលតម្លៃ Null បានដើម្បីការពារការរលត់
  const VideoPlayerScreen({super.key, this.videoUrl});


  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}


class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _hasError = false;


  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }


  void _initializeVideo() {
    // ១. ឆែកមើលបើអត់មាន Link វីដេអូ គឺមិនឱ្យវាដំណើរការនាំឱ្យរលត់ទេ
    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) {
      setState(() {
        _hasError = true;
      });
      return;
    }


    try {
      // ២. ចាប់ផ្ដើមទាញវីដេអូតាម Link
      _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!))
        ..initialize()
            .then((_) {
          if (mounted) {
            setState(() {});
            _controller?.play();
            _controller?.setLooping(true);
          }
        })
            .catchError((error) {
          // ករណី Link ខូច ឬអ៊ីនធឺណិតដាច់
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
        });
    } catch (e) {
      setState(() {
        _hasError = true;
      });
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
            const SizedBox(height: 10),
            const Text(
              "មិនអាចមើលវីដេអូបានទេ",
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            Text(
              "មិនអាចមើលវីដេអូបានទេ",
              style: TextStyle(color: Colors.white),
            ),
          ],
        )
            : (_controller != null && _controller!.value.isInitialized)
            ? AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        )
            : const CircularProgressIndicator(color: Colors.white),
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
  }


  @override
  void dispose() {
    _controller?.dispose(); // បិទឱ្យស្អាតពេលចាកចេញ
    super.dispose();
  }
}



