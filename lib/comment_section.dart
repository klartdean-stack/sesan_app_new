import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:intl/intl.dart';
import 'user_profile_screen.dart';


class CommentSection extends StatefulWidget {
  final String productId;
  final String sellerId;
  final String? currentUserId;


  const CommentSection({
    super.key,
    required this.productId,
    required this.sellerId,
    this.currentUserId,
  });


  @override
  State<CommentSection> createState() => _CommentSectionState();
}


class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();
  final _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();


  bool _isUploading = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordSeconds = 0;
  String? _recordPath;
  String? _currentPlayingUrl;


  bool _isExpanded = false;
  int _displayLimit = 1;
  String _storedUid = '';
  int _currentLimit = 1; // បង្ហាញដំបូងតែ ១ គត់


  // Reply state
  String? _replyingToCommentId;
  String? _replyingToUserName;
  String? _replyingToParentId;


  // Player state
  Duration _playerPosition = Duration.zero;
  Duration _playerDuration = Duration.zero;


  // Track expanded comments for See More/Less
  final Set<String> _expandedComments = {};


  @override
  void initState() {
    super.initState();
    if (widget.currentUserId != null && widget.currentUserId!.isNotEmpty) {
      _storedUid = widget.currentUserId!;
    } else {
      _getStoredUid();
    }
    _getStoredUid();
    _initAudioPlayer();
  }


  Future<void> _getStoredUid() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _storedUid = prefs.getString('user_uid') ?? '';
      });
    }
  }


  void _initAudioPlayer() {
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _playerPosition = position);
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _playerDuration = duration);
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playerPosition = Duration.zero;
          _currentPlayingUrl = null;
        });
      }
    });
  }


  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _commentController.dispose();
    super.dispose();
  }


  // ==================== VOICE RECORDING ====================


  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _showSnack('ត្រូវការសិទ្ធិ Microphone', Colors.orange);
      return;
    }


    final tempDir = await getTemporaryDirectory();
    _recordPath =
    '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';


    await _audioRecorder.start(
      encoder: AudioEncoder.aacLc, // កំណត់ប្រភេទសំឡេង
      bitRate: 128000,             // កម្រិតច្បាស់
      samplingRate: 44100,         // ល្បឿនទាញយកសំណាក
      path: _recordPath!,          // ផ្លូវផ្ទុក File
    );


    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });


    _startRecordTimer();
  }


  void _startRecordTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isRecording) return false;
      if (mounted) setState(() => _recordSeconds++);
      return true;
    });
  }


  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);


    if (path != null && _recordSeconds > 1) {
      final file = File(path);
      await _postComment(
        audioFile: file,
        audioDuration: _recordSeconds,
        parentCommentId: _replyingToCommentId,
        parentReplyId: _replyingToParentId,
      );
    } else {
      _showSnack('សម្លេងខ្លីពេក', Colors.orange);
    }
  }


  Future<void> _cancelRecording() async {
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
  }


  // ==================== POST COMMENT ====================


  Future<void> _postComment({
    String? text,
    File? imageFile,
    File? audioFile,
    int audioDuration = 0,
    String? parentCommentId,
    String? parentReplyId,
  }) async {
    final content = text ?? _commentController.text.trim();
    if (content.isEmpty && imageFile == null && audioFile == null) return;
    if (_storedUid.isEmpty) {
      _showSnack('សូម Login មុនសិន', Colors.orange);
      return;
    }


    setState(() => _isUploading = true);


    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_storedUid)
          .get();


      Map<String, dynamic> userProfile = {};
      if (userDoc.exists && userDoc.data() != null) {
        userProfile = userDoc.data() as Map<String, dynamic>;
      }


      String? imageUrl;
      String? audioUrl;


      // Upload image
      if (imageFile != null) {
        File? compressedFile = await _compressImage(imageFile);
        if (compressedFile != null) {
          final ref = FirebaseStorage.instance.ref().child(
            'comments/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await ref.putFile(compressedFile);
          imageUrl = await ref.getDownloadURL();
        }
      }


      // Upload audio
      if (audioFile != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'voice_comments/${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        await ref.putFile(audioFile);
        audioUrl = await ref.getDownloadURL();
      }


      final commentData = {
        'userId': _storedUid,
        'userName':
        userProfile['name'] ?? userProfile['user_name'] ?? "អ្នកប្រើប្រាស់",
        'userPhoto': userProfile['photoUrl'] ?? userProfile['user_photo'] ?? "",
        'content': content,
        'imageUrl': imageUrl,
        'audioUrl': audioUrl,
        'durationSeconds': audioDuration,
        'isVoiceComment': audioFile != null,
        'createdAt': FieldValue.serverTimestamp(),
      };


      if (parentReplyId != null && parentCommentId != null) {
        // Nested reply
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .collection('comments')
            .doc(parentCommentId)
            .collection('replies')
            .doc(parentReplyId)
            .collection('nested_replies')
            .add({
          ...commentData,
          'parentCommentId': parentCommentId,
          'parentReplyId': parentReplyId,
          'replyingToUserName': _replyingToUserName,
        });
      } else if (parentCommentId != null) {
        // Reply to main comment
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .collection('comments')
            .doc(parentCommentId)
            .collection('replies')
            .add({
          ...commentData,
          'parentCommentId': parentCommentId,
          'replyingToUserName': _replyingToUserName,
        });


        // Increment reply count
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .collection('comments')
            .doc(parentCommentId)
            .update({'replyCount': FieldValue.increment(1)});
      } else {
        // Main comment
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .collection('comments')
            .add({...commentData, 'replyCount': 0});
      }


      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToUserName = null;
        _replyingToParentId = null;
      });
    } catch (e) {
      debugPrint("Error posting comment: $e");
      _showSnack('កំហុស: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }


  // ==================== AUDIO PLAYBACK ====================


  Future<void> _playAudio(String url) async {
    if (_currentPlayingUrl == url && _isPlaying) {
      await _audioPlayer.pause();
      return;
    }


    if (_currentPlayingUrl != url) {
      await _audioPlayer.stop();
      _currentPlayingUrl = url;
      if (mounted) setState(() {});
      await _audioPlayer.play(UrlSource(url));
    } else {
      await _audioPlayer.resume();
    }
  }


  // ==================== IMAGE COMPRESSION ====================


  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path =
        "${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      path,
      quality: 50,
    );
    return result != null ? File(result.path) : null;
  }


  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return 'ឥឡូវនេះ';
    if (diff.inMinutes < 60) return '${diff.inMinutes} នាទីមុន';
    if (diff.inHours < 24) return '${diff.inHours} ម៉ោងមុន';
    if (diff.inDays < 7) return '${diff.inDays} ថ្ងៃមុន';
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }


  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }


  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Siemreap')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }


  void _goToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: userId,
          currentUserId: _storedUid.isNotEmpty ? _storedUid : null,
        ),
      ),
    );
  }


  // ==================== BUILD ====================


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // ទម្លាក់ keyboard
        behavior: HitTestBehavior.translucent, // ឲ្យកូន Widget នៅតែទទួលការចុច
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            _buildCommentsList(),
            const Divider(height: 1),
            if (_replyingToCommentId != null) _buildReplyIndicator(),
            _buildInputSection(),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          const Text(
            "មតិយោបល់",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Siemreap',
            ),
          ),
          const Spacer(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .doc(widget.productId)
                .collection('comments')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return Text(
                "${snapshot.data!.docs.length} មតិ",
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              );
            },
          ),
        ],
      ),
    );
  }


  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const SizedBox();


        final allDocs = snapshot.data!.docs;
        final visibleDocs = allDocs.take(_currentLimit).toList();


        return Column(
          children: [
            // បញ្ជី Comment
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleDocs.length,
              itemBuilder: (context, index) {
                final doc = visibleDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildCommentItem(data, doc.id, isMainComment: true);
              },
            ),


            // 🎯 ប៊ូតុងស្ទីល Tap Window (Dropdown Style)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (allDocs.length > _currentLimit) {
                      // បើនៅមានមតិសល់ ឱ្យពន្លាម្ដង ៤
                      _currentLimit = (_currentLimit == 1)
                          ? 4
                          : _currentLimit + 3;
                    } else {
                      // បើអស់ហើយ ឱ្យបង្រួមមក ១ វិញ
                      _currentLimit = 1;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ប្តូរ Icon តាមស្ថានភាព (បើអស់មតិឱ្យបង្ហាញព្រួញឡើង)
                      Icon(
                        allDocs.length > _currentLimit
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        color: Colors.blue,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        allDocs.length > _currentLimit
                            ? (_currentLimit == 1
                            ? "បង្ហាញមតិយោបល់"
                            : "មើល ៣ ទៀត")
                            : "បិទមកត្រឹម ១ វិញ",
                        style: const TextStyle(
                          fontFamily: 'Siemreap',
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildReplyIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.blue.withOpacity(0.05),
      child: Row(
        children: [
          const Icon(Icons.reply, color: Colors.blue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "កំពុងឆ្លើយតបទៅ ${_replyingToUserName ?? ''}",
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 13,
                fontFamily: 'Siemreap',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _replyingToCommentId = null;
                _replyingToUserName = null;
                _replyingToParentId = null;
              });
            },
            child: const Icon(Icons.close, color: Colors.grey, size: 18),
          ),
        ],
      ),
    );
  }


  // ==================== COMMENT ITEM (FULLY FIXED) ====================


  // ==================== BUILD COMMENT ITEM (FIXED OVERFLOW) ====================
  Widget _buildCommentItem(
      Map<String, dynamic> data,
      String docId, {
        required bool isMainComment,
        String? parentCommentId,
        String? parentReplyId,
      }) {
    final String? commenterId = data['userId'] ?? data['uid'];
    final String commenterName = data['userName'] ?? "អ្នកប្រើប្រាស់";
    final String? photoUrl = data['userPhoto'] ?? data['photoUrl'];
    final String content = data['content'] ?? "";
    final String? imageUrl = data['imageUrl'];
    final String? audioUrl = data['audioUrl'];
    final int durationSeconds = data['durationSeconds'] ?? 0;
    final bool isVoiceComment = data['isVoiceComment'] ?? false;
    final Timestamp? timestamp = data['createdAt'] as Timestamp?;
    final int replyCount = data['replyCount'] ?? 0;


    final bool isNestedReply = parentReplyId != null;
    final double avatarSize = isNestedReply ? 28 : 40;
    final double fontSize = isNestedReply ? 12 : 14;


    final String commentKey = parentCommentId != null
        ? '${parentCommentId}_$docId'
        : docId;
    final bool isCommentExpanded = _expandedComments.contains(commentKey);


    return Container(
      padding: EdgeInsets.all(isNestedReply ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Section
              GestureDetector(
                onTap: () => _goToProfile(commenterId!),
                child: CircleAvatar(
                  radius: isNestedReply ? 14 : 20,
                  backgroundImage: CachedNetworkImageProvider(photoUrl ?? ""),
                ),
              ),
              const SizedBox(width: 10),


              // Content Section (FIXED: ប្រើ Expanded ដើម្បីទប់ Overflow)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Name - FIXED: Constrained width
                        Flexible(
                          child: Text(
                            commenterName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isNestedReply ? 12 : 14,
                              color: Colors.blue.shade800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Time
                        Text(
                          _formatTimeAgo(timestamp?.toDate() ?? DateTime.now()),
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                        const Spacer(),
                        // Delete Icon
                        if (_storedUid == commenterId)
                          GestureDetector(
                            onTap: () => _showDeleteDialog(docId),
                            child: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Colors.red.shade300,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),


                    // 🎯 ហៅមុខងារ មើលច្រើន/តិច
                    if (content.isNotEmpty)
                      _buildCollapsibleText(
                        content,
                        14,
                        isCommentExpanded,
                        commentKey,
                        isNestedReply,
                      ),


                    // Voice Comment
                    if (isVoiceComment && audioUrl != null)
                      _buildVoicePlayer(audioUrl, durationSeconds),


                    // Image
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () => _showImageFullScreen(imageUrl),
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: isNestedReply ? 80 : 150,
                              width: isNestedReply ? 80 : double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: isNestedReply ? 80 : 150,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),


                    // Reply Button
                    if (!isNestedReply) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _replyingToCommentId = isMainComment
                                    ? docId
                                    : parentCommentId;
                                _replyingToParentId = isMainComment
                                    ? null
                                    : docId;
                                _replyingToUserName = commenterName;
                              });
                            },
                            child: Text(
                              "ឆ្លើយតប",
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (replyCount > 0 && isMainComment) ...[
                            const SizedBox(width: 12),
                            Text(
                              "$replyCount ការឆ្លើយតប",
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),


          // Replies Section
          if (isMainComment && replyCount > 0) _buildRepliesSection(docId),


          // Nested Replies
          if (!isMainComment && !isNestedReply)
            _buildNestedRepliesSection(parentCommentId!, docId),
        ],
      ),
    );
  }


  // ==================== NEW: COLLAPSIBLE TEXT WIDGET ====================


  // ==================== មុខងារមើលច្រើន/មើលតិច (កែថ្មី) ====================
  Widget _buildCollapsibleText(
      String content,
      double fontSize,
      bool isExpanded,
      String commentKey,
      bool isNestedReply,
      ) {
    const int maxLinesCollapsed = 3;
    final bool showSeeMore =
        content.length > 100; // បើអក្សរវែងជាង ១០០ តួទើបបង្ហាញ


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          firstChild: // ក្នុងផ្នែក firstChild នៃ AnimatedCrossFade
          Text(
            content,
            maxLines: 3, // កំណត់ឱ្យឃើញតែ ៣ ជួរការពារកុំឱ្យវែងពេក
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isNestedReply ? 12 : 14,
              height: 1.5,
              fontFamily: 'Siemreap',
            ),
          ),
          secondChild: Text(
            content,
            style: TextStyle(
              fontSize: isNestedReply ? 12 : 14,
              height: 1.5,
              color: Colors.black87,
              fontFamily: 'Siemreap',
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        if (showSeeMore)
          GestureDetector(
            onTap: () {
              setState(() {
                if (_expandedComments.contains(commentKey)) {
                  _expandedComments.remove(commentKey);
                } else {
                  _expandedComments.add(commentKey);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isExpanded ? 'លាក់វិញ' : 'មើលច្រើនទៀត',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Siemreap',
                ),
              ),
            ),
          ),
      ],
    );
  }


  // ==================== VOICE PLAYER ====================


  Widget _buildVoicePlayer(String audioUrl, int durationSeconds) {
    final isCurrentAudio = _currentPlayingUrl == audioUrl;
    final isPlayingThis = isCurrentAudio && _isPlaying;


    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _playAudio(audioUrl),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlayingThis ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: isCurrentAudio
                ? ProgressBar(
              progress: _playerPosition,
              buffered: _playerDuration,
              total: _playerDuration,
              onSeek: (duration) {
                _audioPlayer.seek(duration);
              },
              barHeight: 3,
              baseBarColor: Colors.grey.shade300,
              progressBarColor: Colors.blue,
              bufferedBarColor: Colors.blue.withOpacity(0.3),
              thumbColor: Colors.blue,
              thumbRadius: 6,
              timeLabelTextStyle: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            )
                : Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isCurrentAudio
                ? '${_formatDuration(_playerPosition.inSeconds)} / ${_formatDuration(durationSeconds)}'
                : _formatDuration(durationSeconds),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }


  // ==================== REPLIES SECTIONS ====================


  Widget _buildRepliesSection(String commentId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }


        final replies = snapshot.data!.docs;


        return Container(
          margin: const EdgeInsets.only(left: 48, top: 8),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.grey.shade300, width: 2),
            ),
          ),
          child: Column(
            children: replies.map((replyDoc) {
              final reply = replyDoc.data() as Map<String, dynamic>;
              return _buildCommentItem(
                reply,
                replyDoc.id,
                isMainComment: false,
                parentCommentId: commentId,
              );
            }).toList(),
          ),
        );
      },
    );
  }


  Widget _buildNestedRepliesSection(String commentId, String replyId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId)
          .collection('nested_replies')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }


        final nestedReplies = snapshot.data!.docs;


        return Container(
          margin: const EdgeInsets.only(left: 40, top: 6),
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.grey.shade200, width: 1.5),
            ),
          ),
          child: Column(
            children: nestedReplies.map((nestedDoc) {
              final nested = nestedDoc.data() as Map<String, dynamic>;
              return _buildCommentItem(
                nested,
                nestedDoc.id,
                isMainComment: false,
                parentCommentId: commentId,
                parentReplyId: replyId,
              );
            }).toList(),
          ),
        );
      },
    );
  }


  // ==================== INPUT SECTION ====================


  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (_replyingToCommentId == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _isRecording
                  ? _buildRecordingWidget()
                  : _buildStartRecordButton(),
            ),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 70,
                  );
                  if (picked != null) {
                    _postComment(
                      imageFile: File(picked.path),
                      parentCommentId: _replyingToCommentId,
                      parentReplyId: _replyingToParentId,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.image, color: Colors.green, size: 24),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: _replyingToCommentId != null
                        ? "ឆ្លើយតបទៅ ${_replyingToUserName ?? ''}..."
                        : "សរសេរមតិយោបល់...",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontFamily: 'Siemreap',
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) {
                    _postComment(
                      text: _commentController.text,
                      parentCommentId: _replyingToCommentId,
                      parentReplyId: _replyingToParentId,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              _isUploading
                  ? const SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
                  : GestureDetector(
                onTap: () {
                  _postComment(
                    text: _commentController.text,
                    parentCommentId: _replyingToCommentId,
                    parentReplyId: _replyingToParentId,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _replyingToCommentId != null
                        ? Icons.reply
                        : Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildStartRecordButton() {
    return GestureDetector(
      onTap: _startRecording,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              'ថតសម្លេង',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
                fontFamily: 'Siemreap',
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildRecordingWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatDuration(_recordSeconds),
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.grey, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRecordingWave() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 4,
          height: 10 + (index % 2) * 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }


  // ==================== DIALOGS ====================


  void _showDeleteDialog(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "លុបមតិយោបល់?",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "បោះបង់",
              style: TextStyle(fontFamily: 'Siemreap'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(widget.productId)
                  .collection('comments')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("លុប", style: TextStyle(fontFamily: 'Siemreap')),
          ),
        ],
      ),
    );
  }


  void _showDeleteReplyDialog(String parentId, String replyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "លុបការឆ្លើយតប?",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "បោះបង់",
              style: TextStyle(fontFamily: 'Siemreap'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(widget.productId)
                  .collection('comments')
                  .doc(parentId)
                  .collection('replies')
                  .doc(replyId)
                  .delete();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("លុប", style: TextStyle(fontFamily: 'Siemreap')),
          ),
        ],
      ),
    );
  }


  void _showImageFullScreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}



