import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';


class AudioBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  const AudioBubble({super.key, required this.url, required this.isMe});


  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}


class _AudioBubbleState extends State<AudioBubble> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;
  String? _error;


  @override
  void initState() {
    super.initState();
    _initAudio();
  }


  Future<void> _initAudio() async {
    try {
      _player = AudioPlayer();


      if (widget.url.isEmpty) {
        setState(() {
          _error = "គ្មានសម្លេង";
          _isLoading = false;
        });
        return;
      }


      await _player!.setSource(UrlSource(widget.url));


      _player!.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });


      _player!.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });


      _player!.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      });


      _player!.onPlayerComplete.listen((_) {
        if (mounted)
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
      });


      final duration = await _player!.getDuration();
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = "សម្លេងមិនដំណើរ";
          _isLoading = false;
        });
    }
  }


  void _playPause() async {
    if (_player == null || _error != null) return;


    try {
      if (_isPlaying) {
        await _player!.pause();
      } else {
        await _player!.resume(); // ប្ដូរពី play(UrlSource) ទៅ resume()
      }
    } catch (e) {
      debugPrint("Audio error: $e");
    }
  }


  @override
  void dispose() {
    _player?.dispose();
    _player = null;
    super.dispose();
  }


  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}";
  }


  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[400]),
            const SizedBox(width: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.red[600], fontSize: 12),
            ),
          ],
        ),
      );
    }


    if (_isLoading) {
      return Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text("កំពុងផ្ទុក...", style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }


    return Container(
      width: MediaQuery.of(context).size.width * 0.7,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.green[600] : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _playPause,
            child: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              size: 40,
              color: widget.isMe ? Colors.white : Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProgressBar(
                  progress: _position,
                  total: _duration,
                  progressBarColor: widget.isMe ? Colors.white : Colors.green,
                  baseBarColor: widget.isMe ? Colors.white24 : Colors.grey[300],
                  thumbColor: widget.isMe ? Colors.white : Colors.green,
                  onSeek: (d) => _player?.seek(d),
                ),
                Text(
                  "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



