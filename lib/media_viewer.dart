import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';

class MediaViewer extends StatelessWidget {
  final String url;
  final String type; // 'image' ឬ 'video'

  const MediaViewer({super.key, required this.url, required this.type});

  // មុខងារ Save ចូល Gallery
  Future<void> _saveMedia(BuildContext context) async {
    try {
      // បង្ហាញ Loading ប្រាប់អ្នកប្រើបន្តិច
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("កំពុងទាញយក..."),
          duration: Duration(seconds: 1),
        ),
      );

      // ១. បង្កើតទីតាំងទុក File បណ្ដោះអាសន្ន (Temporary Path)
      final temp = await getTemporaryDirectory();
      final extension = type == 'image' ? 'jpg' : 'mp4';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final savePath = '${temp.path}/$fileName';

      // ២. ទាញយក File ពី URL មកកាន់ម៉ាស៊ីន
      await Dio().download(url, savePath);

      // ៣. រក្សាទុកចូលក្នុង Gallery តាមប្រភេទ File
      if (type == 'image') {
        await Gal.putImage(savePath);
      } else {
        await Gal.putVideo(savePath);
      }

      // ៤. លុប File បណ្ដោះអាសន្នចេញពីម៉ាស៊ីនវិញដើម្បីកុំឱ្យធ្ងន់ App
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("រក្សាទុកក្នុង Gallery រួចរាល់!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("ការរក្សាទុកបរាជ័យ: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _saveMedia(context),
          ),
        ],
      ),
      body: Center(
        child: type == 'image'
            ? PhotoView(imageProvider: NetworkImage(url))
            : FullVideoPlayer(url: url),
      ),
    );
  }
}

class FullVideoPlayer extends StatefulWidget {
  final String url;
  const FullVideoPlayer({super.key, required this.url});
  @override
  State<FullVideoPlayer> createState() => _FullVideoPlayerState();
}

class _FullVideoPlayerState extends State<FullVideoPlayer> {
  late VideoPlayerController _controller;

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                  onPressed: () => setState(
                    () => _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play(),
                  ),
                ),
              ],
            ),
          )
        : const CircularProgressIndicator();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
