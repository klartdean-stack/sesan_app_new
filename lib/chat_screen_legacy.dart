import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:my_app/audio_bubble_.dart';
import 'package:my_app/chat_video_bubble.dart';
import 'package:my_app/create_invoice_sheet.dart';
import 'package:my_app/invoice_capture_helper.dart';
import 'package:my_app/invoice_history_screen.dart';
import 'package:my_app/order_management_screen.dart';
import 'package:my_app/seller_profile_screen.dart';
import 'package:my_app/user_profile_screen.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/media_viewer.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'dart:async';
import 'location_picker_sheet.dart';
import 'localized_text.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// ═══════════════════════════════════════════════════════════════════
//  OPTIMIZED CHAT SCREEN - Telegram-style smooth messaging
//  Key improvements:
//  1. Instant local thumbnail preview (no spinning while uploading)
//  2. Non-blocking recording - can record while previous uploads
//  3. Decoupled upload queue - uploads happen in background
//  4. Optimized image/video/audio handling
// ═══════════════════════════════════════════════════════════════════

class ChatScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final String seller_id;
  final String receiver_id;

  const ChatScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.seller_id,
    required this.receiver_id,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// ─── Upload Task Model for Queue ──────────────────────────────────
class _UploadTask {
  final String messageId;
  final File? file;
  final Uint8List? bytes;
  final String type; // image | video | audio
  final String? extension;
  final String? contentType;

  _UploadTask({
    required this.messageId,
    this.file,
    this.bytes,
    required this.type,
    this.extension,
    this.contentType,
  }) : assert(file != null || bytes != null);
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ScreenshotController _screenshotController = ScreenshotController();

  late final String currentUserId;
  Timer? _recordTimer;
  String? _loggedUid;
  bool _isLoading = true;
  String? _errorMessage;
  double _dragOffset = 0;
  int _recordSeconds = 0;
  bool _isLocked = false;
  bool isCancelling = false;
  bool _isBlocked = false;
  bool _isLoadingBlock = false;
  Set<String> _highlightedMessages = {};
  bool _isOnline = false;
  bool _amIBlocked = false;
  bool _isRecording = false;
  String _webAudioExtension = 'wav';
  String _webAudioContentType = 'audio/wav';
  BytesBuilder? _webPcmBytes;
  StreamSubscription<Uint8List>? _webAudioSubscription;
  Completer<void>? _webAudioStreamDone;
  static const int _webAudioSampleRate = 44100;

  // ═══════════════════════════════════════════════════════════════
  //  UPLOAD QUEUE - Decoupled from UI for non-blocking experience
  // ═══════════════════════════════════════════════════════════════
  final List<_UploadTask> _uploadQueue = [];
  bool _isProcessingQueue = false;

  // ═══════════════════════════════════════════════════════════════
  //  LOCAL THUMBNAIL CACHE - Instant preview without waiting
  // ═══════════════════════════════════════════════════════════════
  final Map<String, Uint8List> _localImageThumbnails = {};
  final Map<String, Uint8List> _localVideoThumbnails = {};

  final List<String> _quickReplyKeys = [
    'chat_quick_price',
    'chat_quick_location',
    'chat_quick_stock',
    'chat_quick_available',
    'chat_quick_product',
    'chat_quick_delivery_info',
    'chat_quick_invoice',
    'chat_quick_received',
  ];

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    try {
      if (currentUserId.isNotEmpty) {
        _setOnline(false);
      }
    } catch (e) {
      debugPrint("Dispose error: $e");
    }
    _msgController.dispose();
    _scrollController.dispose();
    _webAudioSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ─── Block/Unblock ─────────────────────────────────────────────
  Future<void> _blockUser() async {
    if (_isLoadingBlock) return;
    setState(() => _isLoadingBlock = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
            'blockedUsers': FieldValue.arrayUnion([widget.seller_id]),
          });
      setState(() {
        _isBlocked = true;
        _isLoadingBlock = false;
      });
      _showSnack('chat_block_success'.tr, Colors.red);
    } catch (e) {
      setState(() => _isLoadingBlock = false);
      _showSnack(appText(context, km: '❌ មិនអាច Block បាន: $e', en: '❌ Unable to block user: $e'), Colors.red);
    }
  }

  Future<void> _unblockUser() async {
    if (_isLoadingBlock) return;
    setState(() => _isLoadingBlock = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
            'blockedUsers': FieldValue.arrayRemove([widget.seller_id]),
          });
      setState(() {
        _isBlocked = false;
        _isLoadingBlock = false;
      });
      _showSnack('chat_unblock_success'.tr, Colors.green);
    } catch (e) {
      setState(() => _isLoadingBlock = false);
      _showSnack(appText(context, km: '❌ មិនអាចដោះ Block បាន: $e', en: '❌ Unable to unblock user: $e'), Colors.red);
    }
  }

  Future<void> _checkIfBlocked() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final blockedList = (data['blockedUsers'] as List?) ?? [];
        setState(() {
          _isBlocked = blockedList.contains(widget.seller_id);
        });
      }
    } catch (e) {
      debugPrint("Check blocked error: $e");
    }
  }

  Future<void> _checkIfBlockedByThem() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.seller_id)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final blockedList = (data['blockedUsers'] as List?) ?? [];
        setState(() {
          _amIBlocked = blockedList.contains(currentUserId);
        });
      }
    } catch (e) {
      debugPrint("Check if I am blocked error: $e");
    }
  }

  Future<void> _setOnline(bool isOnline) async {
    try {
      if (currentUserId.isEmpty) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
            'isOnline': isOnline,
            'lastSeen': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint("⚠️ បញ្ហា Online Status: $e");
    }
  }

  Future<void> _ensureBlockedField() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId);
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data()!;
        if (!data.containsKey('blockedUsers')) {
          await docRef.update({'blockedUsers': []});
        }
      } else {
        await docRef.set({'blockedUsers': []}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("⚠️ Error ensuring blockedUsers field: $e");
    }
  }

  Future<void> _initializeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String uid = prefs.getString('user_uid') ?? '';

      if (uid.isEmpty) {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          uid = firebaseUser.uid;
          await prefs.setString('user_uid', uid);
        }
      }

      if (uid.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = appText(context, km: 'សូមចូលគណនីមុននឹងប្រើឆាត', en: 'Please sign in before using chat.');
          });
        }
        return;
      }

      currentUserId = uid;
      await _ensureBlockedField();
      await _checkIfBlocked();
      await _checkIfBlockedByThem();
      await _setOnline(true);
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({'unreadCount': 0})
          .catchError((e) => debugPrint("Reset unreadCount error: $e"));

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("❌ ChatScreen - Init Error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'មានបញ្ហា: $e';
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  INSTANT LOCAL PREVIEW - Generate thumbnails immediately
  //  This is the KEY fix - no more spinning loaders!
  // ═══════════════════════════════════════════════════════════════

  /// Generate thumbnail from image file instantly for local preview
  Future<Uint8List?> _generateImageThumbnail(File imageFile) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        minWidth: 300,
        minHeight: 300,
        quality: 50,
      );
      return result;
    } catch (e) {
      debugPrint("⚠️ Thumbnail generation failed: $e");
      return null;
    }
  }

  /// Generate video thumbnail instantly using video_thumbnail package
  Future<Uint8List?> _generateVideoThumbnail(String videoPath) async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 50,
      );
      return uint8list;
    } catch (e) {
      debugPrint("⚠️ Video thumbnail generation failed: $e");
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  UPLOAD QUEUE SYSTEM - Non-blocking, background uploads
  //  Like Telegram: send instantly, upload in background
  // ═══════════════════════════════════════════════════════════════

  void _addToUploadQueue(_UploadTask task) {
    _uploadQueue.add(task);
    if (!_isProcessingQueue) {
      _processUploadQueue();
    }
  }

  Future<void> _processUploadQueue() async {
    if (_uploadQueue.isEmpty) {
      _isProcessingQueue = false;
      return;
    }
    _isProcessingQueue = true;

    final task = _uploadQueue.removeAt(0);

    try {
      await _executeUpload(task);
    } catch (e) {
      debugPrint("❌ Upload task failed: $e");
    }

    // Continue with next task
    _processUploadQueue();
  }

  Future<void> _executeUpload(_UploadTask task) async {
    final String ext = task.extension ??
        (task.type == 'image'
            ? 'jpg'
            : task.type == 'video'
                ? 'mp4'
                : 'm4a');
    final String path =
        'chat_${task.type}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final Reference ref = FirebaseStorage.instance.ref().child(path);

    UploadTask uploadTask;
    if (task.bytes != null) {
      // Web recordings are browser blobs. Upload their bytes directly because
      // dart:io File and Firebase putFile are not available in the browser.
      uploadTask = ref.putData(
        task.bytes!,
        SettableMetadata(contentType: task.contentType),
      );
    } else {
      File fileToUpload = task.file!;

      // Compress video if needed (only if > 20MB).
      if (task.type == 'video') {
        final originalSize = await task.file!.length();
        if (originalSize > 20 * 1024 * 1024) {
          try {
            final info = await VideoCompress.compressVideo(
              task.file!.path,
              quality: VideoQuality.LowQuality,
              deleteOrigin: false,
              includeAudio: true,
            );
            if (info?.file != null) {
              fileToUpload = info!.file!;
            }
          } catch (e) {
            debugPrint("⚠️ Video compress failed, using original: $e");
          }
        }
      }

      uploadTask = ref.putFile(fileToUpload);
    }

    // Update progress in Firestore
    uploadTask.snapshotEvents.listen((snapshot) {
      double progress = snapshot.bytesTransferred / snapshot.totalBytes;
      FirebaseFirestore.instance
          .collection('chats')
          .doc(task.messageId)
          .update({'progress': progress})
          .catchError((e) => debugPrint("Progress update error: $e"));
    });

    await uploadTask.timeout(const Duration(minutes: 5));
    String url = await ref.getDownloadURL();

    // Update message with URL and mark as sent
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(task.messageId)
        .update({
          'fileUrl': url,
          'status': 'sent',
          'localPath': FieldValue.delete(),
          'progress': FieldValue.delete(),
        });

    // Clean up local thumbnail cache after successful upload
    if (task.type == 'image') {
      _localImageThumbnails.remove(task.messageId);
    } else if (task.type == 'video') {
      _localVideoThumbnails.remove(task.messageId);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  INSTANT MESSAGE CREATION - Show immediately, upload later
  // ═══════════════════════════════════════════════════════════════

  Future<String> _createPlaceholderMessage({
    required String type,
    String text = '',
    String? localPath,
    int? durationSeconds,
  }) async {
    String msgId = FirebaseFirestore.instance.collection('chats').doc().id;
    String chatRoomId = getChatRoomId(currentUserId, widget.seller_id);

    await FirebaseFirestore.instance.collection('chats').doc(msgId).set({
      'chatRoomId': chatRoomId,
      'productId': widget.productId,
      'productName': widget.productName,
      'message': text,
      'fileUrl': '',
      'localPath': localPath,
      'type': type,
      'time': FieldValue.serverTimestamp(),
      'sender': currentUserId,
      'receiver': widget.receiver_id,
      'users': [currentUserId, widget.seller_id],
      'status': 'sending',
      'progress': 0,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    });

    _scrollToBottom();
    return msgId;
  }

  // ─── Send Text Message ───────────────────────────────────────────
  Future<void> _sendMessage({
    String? text,
    String? fileUrl,
    String? type,
    String status = 'sent',
  }) async {
    if (_amIBlocked) {
      _showSnack(
        'អ្នកត្រូវបាន Block ដោយអ្នកប្រើនេះ មិនអាចផ្ញើសារបានទេ',
        Colors.red,
      );
      return;
    }

    if ((text == null || text.trim().isEmpty) && fileUrl == null) return;

    try {
      final messageData = {
        'chatRoomId': getChatRoomId(currentUserId, widget.seller_id),
        'productId': widget.productId,
        'productName': widget.productName,
        'message': text ?? '',
        'fileUrl': fileUrl ?? '',
        'type': type ?? 'text',
        'time': FieldValue.serverTimestamp(),
        'sender': currentUserId,
        'receiver': widget.receiver_id,
        'users': [currentUserId, widget.seller_id],
        'status': status,
        'isSeen': false,
      };

      await FirebaseFirestore.instance.collection('chats').add(messageData);
      _msgController.clear();
      if (mounted) setState(() {});
      _scrollToBottom();
    } catch (e) {
      debugPrint("ផ្ញើសារមិនចេញ៖ $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ផ្ញើសារមិនបាន: $e')));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  INSTANT IMAGE SEND - Show thumbnail immediately, upload in bg
  // ═══════════════════════════════════════════════════════════════
  Future<void> _sendImage(File imageFile) async {
    try {
      // 1. Generate thumbnail instantly for smooth UI
      final thumbnail = await _generateImageThumbnail(imageFile);

      // 2. Create placeholder message in Firestore (shows immediately)
      String msgId = await _createPlaceholderMessage(
        type: 'image',
        localPath: imageFile.path,
      );

      // 3. Cache thumbnail locally for instant display
      if (thumbnail != null) {
        _localImageThumbnails[msgId] = thumbnail;
        if (mounted) setState(() {});
      }

      // 4. Compress image for upload
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';

      XFile? compressed;
      try {
        compressed = await FlutterImageCompress.compressAndGetFile(
          imageFile.path,
          targetPath,
          quality: 60,
          minWidth: 1024,
          minHeight: 1024,
        );
      } catch (e) {
        debugPrint("⚠️ Image compress failed: $e");
      }

      final fileToUpload = compressed != null
          ? File(compressed.path)
          : imageFile;

      // 5. Add to upload queue (non-blocking!)
      _addToUploadQueue(
        _UploadTask(messageId: msgId, file: fileToUpload, type: 'image'),
      );
    } catch (e) {
      debugPrint("❌ Send image error: $e");
      _showSnack(appText(context, km: '❌ ផ្ញើរូបមិនបាន', en: '❌ Could not send image'), Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  INSTANT VIDEO SEND - Show thumbnail immediately, upload in bg
  // ═══════════════════════════════════════════════════════════════
  Future<void> _sendVideo(File videoFile) async {
    try {
      // 1. Generate video thumbnail instantly
      final thumbnail = await _generateVideoThumbnail(videoFile.path);

      // 2. Create placeholder message (shows immediately with thumbnail)
      String msgId = await _createPlaceholderMessage(
        type: 'video',
        localPath: videoFile.path,
      );

      // 3. Cache thumbnail locally
      if (thumbnail != null) {
        _localVideoThumbnails[msgId] = thumbnail;
        if (mounted) setState(() {});
      }

      // 4. Add to upload queue (non-blocking)
      _addToUploadQueue(
        _UploadTask(messageId: msgId, file: videoFile, type: 'video'),
      );
    } catch (e) {
      debugPrint("❌ Send video error: $e");
      _showSnack(appText(context, km: '❌ ផ្ញើវីដេអូមិនបាន', en: '❌ Could not send video'), Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  INSTANT AUDIO SEND - Show waveform placeholder, upload in bg
  //  KEY FIX: Recording is NOT blocked by previous uploads!
  // ═══════════════════════════════════════════════════════════════
  Future<void> _sendAudio(File audioFile, int durationSeconds) async {
    try {
      final String msgId = await _createPlaceholderMessage(
        type: 'audio',
        localPath: audioFile.path,
        durationSeconds: durationSeconds,
      );
      _addToUploadQueue(
        _UploadTask(messageId: msgId, file: audioFile, type: 'audio'),
      );
    } catch (e) {
      debugPrint("❌ Send audio error: $e");
    }
  }

  Future<void> _sendWebAudio(
    Uint8List audioBytes,
    int durationSeconds,
  ) async {
    try {
      final String msgId = await _createPlaceholderMessage(
        type: 'audio',
        durationSeconds: durationSeconds,
      );
      _addToUploadQueue(
        _UploadTask(
          messageId: msgId,
          bytes: audioBytes,
          type: 'audio',
          extension: _webAudioExtension,
          contentType: _webAudioContentType,
        ),
      );
    } catch (e) {
      debugPrint("❌ Send web audio error: $e");
      _showSnack(
        appText(
          context,
          km: 'ផ្ញើសម្លេងមិនបាន',
          en: 'Could not send audio',
        ),
        Colors.red,
      );
    }
  }

  // ─── Pick Media (optimized) ──────────────────────────────────────
  Future<void> _pickMedia(ImageSource source, bool isVideo) async {
    try {
      final XFile? file = isVideo
          ? await _picker.pickVideo(
              source: source,
              maxDuration: const Duration(seconds: 60),
            )
          : await _picker.pickImage(source: source, imageQuality: 80);

      if (file == null) return;

      final originalFile = File(file.path);
      if (!await originalFile.exists()) return;

      if (isVideo) {
        await _sendVideo(originalFile);
      } else {
        await _sendImage(originalFile);
      }
    } catch (e) {
      debugPrint("❌ Pick media error: $e");
    }
  }

  // ─── Pick Multiple Images (optimized) ──────────────────────────
  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> files = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (files.isEmpty) return;

      // Send all images instantly (each gets its own thumbnail + upload queue)
      for (final file in files) {
        final originalFile = File(file.path);
        if (await originalFile.exists()) {
          await _sendImage(originalFile);
        }
      }

      _showSnack(appText(context, km: '✅ បានផ្ញើ ${files.length} សន្លឹក', en: '✅ Sent ${files.length} images'), Colors.green);
    } catch (e, stackTrace) {
      debugPrint("❌ Pick multiple images error: $e");
      debugPrint(stackTrace.toString());
      _showSnack(appText(context, km: 'មានបញ្ហា: $e', en: 'Error: $e'), Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  RECORDING - Completely non-blocking now!
  //  Can start new recording even while previous audio is uploading
  // ═══════════════════════════════════════════════════════════════

  Uint8List _pcm16ToWav(Uint8List pcmBytes) {
    const int channels = 1;
    const int bitsPerSample = 16;
    const int headerSize = 44;
    final int byteRate =
        _webAudioSampleRate * channels * (bitsPerSample ~/ 8);
    final int blockAlign = channels * (bitsPerSample ~/ 8);
    final header = ByteData(headerSize);
    final headerBytes = header.buffer.asUint8List();

    void writeAscii(int offset, String value) {
      headerBytes.setRange(offset, offset + value.length, value.codeUnits);
    }

    writeAscii(0, 'RIFF');
    header.setUint32(4, 36 + pcmBytes.length, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, _webAudioSampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    header.setUint32(40, pcmBytes.length, Endian.little);

    final wav = Uint8List(headerSize + pcmBytes.length);
    wav.setRange(0, headerSize, headerBytes);
    wav.setRange(headerSize, wav.length, pcmBytes);
    return wav;
  }

  Future<void> _startRecording() async {
    try {
      if (_isRecording) return;

      if (!await _audioRecorder.hasPermission()) {
        _showSnack(
          appText(
            context,
            km: 'សូមអនុញ្ញាតឲ្យប្រើមីក្រូហ្វូន',
            en: 'Please allow microphone access',
          ),
          Colors.orange,
        );
        return;
      }

      HapticFeedback.mediumImpact();

      if (kIsWeb) {
        // Capture raw PCM on Web and build a standards-compliant WAV file
        // ourselves. This avoids browser Blob/container mismatches.
        _webPcmBytes = BytesBuilder(copy: false);
        _webAudioStreamDone = Completer<void>();
        final stream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: _webAudioSampleRate,
            numChannels: 1,
            echoCancel: true,
            noiseSuppress: true,
            autoGain: true,
          ),
        );
        _webAudioSubscription = stream.listen(
          (chunk) => _webPcmBytes?.add(chunk),
          onError: (Object error) {
            debugPrint('Web audio stream error: $error');
            if (!(_webAudioStreamDone?.isCompleted ?? true)) {
              _webAudioStreamDone!.complete();
            }
          },
          onDone: () {
            if (!(_webAudioStreamDone?.isCompleted ?? true)) {
              _webAudioStreamDone!.complete();
            }
          },
          cancelOnError: false,
        );
        _webAudioExtension = 'wav';
        _webAudioContentType = 'audio/wav';
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,
            sampleRate: 44100,
            echoCancel: true,
            noiseSuppress: true,
            autoGain: true,
          ),
          path: path,
        );
      }

      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
          _dragOffset = 0;
        });
        _startRecordTimer();
      }
    } catch (e) {
      debugPrint("❌ Start recording error: $e");
      await _webAudioSubscription?.cancel();
      _webAudioSubscription = null;
      _webPcmBytes = null;
      if (mounted) {
        setState(() => _isRecording = false);
        _showSnack(
          appText(
            context,
            km: 'មិនអាចចាប់ផ្តើមថតបានទេ',
            en: 'Could not start recording',
          ),
          Colors.red,
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    final int currentDuration = _recordSeconds;
    _recordTimer?.cancel();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isLocked = false;
        _dragOffset = 0;
      });
    }

    if (kIsWeb) {
      try {
        await _audioRecorder.stop();
        try {
          await _webAudioStreamDone?.future.timeout(
            const Duration(seconds: 1),
          );
        } catch (_) {
          // Some browsers stop without sending an explicit stream done event.
        }
        await _webAudioSubscription?.cancel();
        _webAudioSubscription = null;

        final pcmBytes = _webPcmBytes?.takeBytes() ?? Uint8List(0);
        _webPcmBytes = null;
        if (pcmBytes.isEmpty) {
          throw StateError('Empty PCM recording');
        }

        final wavBytes = _pcm16ToWav(pcmBytes);
        await _sendWebAudio(wavBytes, currentDuration);
      } catch (e) {
        debugPrint("❌ Finish web audio error: $e");
        _showSnack(
          appText(
            context,
            km: 'ការថតសម្លេងបរាជ័យ សូមពិនិត្យ Microphone',
            en: 'Recording failed. Please check the microphone.',
          ),
          Colors.orange,
        );
        return;
      }
    } else {
      final path = await _audioRecorder.stop();
      if (path == null) {
        _showSnack(
          appText(context, km: 'ការថតបរាជ័យ', en: 'Recording failed'),
          Colors.orange,
        );
        return;
      }
      final file = File(path);
      if (!await file.exists()) {
        _showSnack(
          appText(
            context,
            km: 'ឯកសារសម្លេងមិនមាន',
            en: 'Audio file was not found',
          ),
          Colors.orange,
        );
        return;
      }
      await _sendAudio(file, currentDuration);
    }
    _scrollToBottom();
  }

  Future<void> _cancelRecording() async {
    try {
      if (!_isRecording) return;

      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (kIsWeb) {
        await _webAudioSubscription?.cancel();
        _webAudioSubscription = null;
        _webPcmBytes = null;
      }

      if (mounted) {
        setState(() {
          _isRecording = false;
          _isLocked = false;
          _dragOffset = 0;
        });
      }

      if (!kIsWeb && path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      _showSnack(appText(context, km: 'បានលប់សម្លេង', en: 'Recording deleted'), Colors.orange);
    } catch (e) {
      debugPrint("❌ Cancel recording error: $e");
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isLocked = false;
        });
      }
    }
  }

  void _startRecordTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          _recordSeconds++;
        });
      }
    });
  }

  void _lockRecording() {
    setState(() => _isLocked = true);
    _showSnack(appText(context, km: '🔒 បានចាក់សោ — ចុចផ្ញើពេលចប់', en: '🔒 Locked — tap Send when finished'), Colors.green);
  }

  // ─── Send Location ───────────────────────────────────────────────
  Future<void> _sendLocationMessage({
    required String province,
    String? district,
    String? vireakBranch,
    required String address,
    bool isVireakBuntham = false,
  }) async {
    try {
      String locationText;
      if (isVireakBuntham) {
        locationText = appText(
          context,
          km:
              'ទីតាំងផ្ញើតាមវិរៈប៊ុនថាំ:\n'
              '📍 ខេត្ត/ក្រុង: $province\n'
              '🏪 សាខា: $vireakBranch\n'
              '🏠 អាសយដ្ឋាន/លេខទូរស័ព្ទ: $address',
          en:
              'Vireak Buntham delivery location:\n'
              '📍 Province/City: $province\n'
              '🏪 Branch: $vireakBranch\n'
              '🏠 Address/Phone: $address',
        );
      } else {
        locationText = appText(
          context,
          km:
              'ទីតាំងទទួលឥវ៉ាន់:\n'
              '📍 ខេត្ត/ក្រុង: $province\n'
              '🏘️ ស្រុក/ខណ្ឌ: $district\n'
              '🏠 អាសយដ្ឋានលម្អិត/លេខទូរស័ព្ទ: $address',
          en:
              'Delivery location:\n'
              '📍 Province/City: $province\n'
              '🏘️ District: $district\n'
              '🏠 Detailed address/Phone: $address',
        );
      }

      final messageData = {
        'chatRoomId': getChatRoomId(currentUserId, widget.seller_id),
        'productId': widget.productId,
        'productName': widget.productName,
        'message': locationText,
        'fileUrl': '',
        'type': 'location',
        'time': FieldValue.serverTimestamp(),
        'sender': currentUserId,
        'receiver': widget.receiver_id,
        'users': [currentUserId, widget.seller_id],
        'status': 'sent',
        'isSeen': false,
        'locationData': {
          'province': province,
          'district': district,
          'vireakBranch': vireakBranch,
          'address': address,
          'isVireakBuntham': isVireakBuntham,
        },
      };

      await FirebaseFirestore.instance.collection('chats').add(messageData);
      _scrollToBottom();
    } catch (e) {
      debugPrint("ផ្ញើទីតាំងមិនបាន៖ $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            appText(
              context,
              km: 'ផ្ញើទីតាំងមិនបាន: $e',
              en: 'Could not send location: $e',
            ),
          ),
        ),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String getChatRoomId(String a, String b) =>
      (a.compareTo(b) <= 0) ? "${a}_$b" : "${b}_$a";

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Siemreap')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD METHOD - Optimized message rendering
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            _buildChatItemsBar(),
            Expanded(child: _buildMessagesList()),
            if (_isRecording && !_isLocked) _buildRecordingHint(),
            if (!_isRecording && !_isBlocked && !_amIBlocked)
              _buildQuickReplies(),
            _buildInputPanel(),
          ],
        ),
      ),
    );
  }

  // ─── Blocked Screen ────────────────────────────────────────────
  Widget _buildBlockedScreen() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        title: Text(widget.productName),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'unblock') _showUnblockConfirmDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'unblock',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Unblock', style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_rounded, color: Colors.red.shade300, size: 80),
            const SizedBox(height: 20),
            Text(
              'អ្នកបាន Block អ្នកប្រើនេះ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                fontFamily: 'Siemreap',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'អ្នកមិនអាចផ្ញើ ឬទទួលសារពីអ្នកប្រើនេះបានទេ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontFamily: 'Siemreap',
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _isLoadingBlock ? null : _showUnblockConfirmDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 14,
                ),
              ),
              icon: _isLoadingBlock
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle, color: Colors.white),
              label: Text(
                _isLoadingBlock ? 'កំពុងដំណើរការ...' : 'Unblock',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Siemreap',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error Screen ──────────────────────────────────────────────
  Widget _buildErrorScreen() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        title: Text('ឆាត'.tr),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 18, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ត្រឡប់ក្រោយ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── App Bar ───────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.green[700],
      foregroundColor: Colors.white,
      title: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.seller_id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text(widget.productName);
          if (!snapshot.hasData ||
              snapshot.data == null ||
              !snapshot.data!.exists) {
            return Text(widget.productName);
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>?;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      UserProfileScreen(userId: widget.seller_id),
                ),
              );
            },
            child: Row(
              children: [
                Hero(
                  tag: 'profile_image_${widget.seller_id}',
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(
                          userData?['photoUrl'] ??
                              'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: (userData?['isOnline'] == true)
                                ? Colors.greenAccent
                                : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userData?['name'] ?? 'chat_seller'.tr,
                        style: const TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        userData?['isOnline'] == true
                            ? '🟢 ${'chat_online'.tr}'
                            : _formatLastSeen(userData?['lastSeen']),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton.icon(
          onPressed: _openSellerShop,
          icon: const Icon(
            Icons.storefront_outlined,
            color: Colors.white,
            size: 18,
          ),
          label: Text(
            'មើលហាង'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Siemreap',
            ),
          ),
        ),
        _buildPopupMenu(),
      ],
    );
  }

  Widget _buildPopupMenu() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'confirmed')
          .snapshots(),
      builder: (context, orderSnapshot) {
        int orderCount = 0;
        if (orderSnapshot.hasData && orderSnapshot.data != null) {
          orderCount = orderSnapshot.data!.docs.length;
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
              padding: EdgeInsets.zero,
              onSelected: (value) {
                switch (value) {
                  case 'shop':
                    _openSellerShop();
                    break;
                  case 'orders':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            OrderManagementScreen(sellerId: currentUserId),
                      ),
                    );
                    break;
                  case 'block':
                    _showBlockConfirmDialog();
                    break;
                  case 'unblock':
                    _showUnblockConfirmDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'shop',
                  child: Row(
                    children: [
                      Icon(Icons.store, color: Colors.green[700], size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'មើលហាង'.tr,
                        style: const TextStyle(fontFamily: 'Siemreap', fontSize: 11),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'orders',
                  child: Row(
                    children: [
                      Icon(Icons.sell, color: Colors.amber[700], size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'chat_manage_sales'.tr,
                        style: const TextStyle(fontFamily: 'Siemreap', fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                if (!_isBlocked)
                  PopupMenuItem<String>(
                    value: 'block',
                    child: Row(
                      children: [
                        const Icon(Icons.block, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'chat_block'.tr,
                          style: const TextStyle(
                            color: Colors.red,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isBlocked)
                  PopupMenuItem<String>(
                    value: 'unblock',
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'chat_unblock'.tr,
                          style: const TextStyle(
                            color: Colors.green,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (orderCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      '$orderCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ─── Chat Items Bar ────────────────────────────────────────────
  Widget _buildChatItemsBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_items')
          .where(
            'chat_room_id',
            isEqualTo: getChatRoomId(currentUserId, widget.seller_id),
          )
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        var items = snapshot.data!.docs;

        return Container(
          margin: const EdgeInsets.fromLTRB(6, 2, 6, 4),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_basket,
                      color: Colors.orange[700],
                      size: 16,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: appText(
                        context,
                        km: 'លុបទាំងអស់',
                        en: 'Delete all',
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        for (var item in items) {
                          await item.reference.delete();
                        }
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 62,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    var data = items[index].data() as Map<String, dynamic>;
                    String imageUrl = data['image_url']?.toString() ?? '';
                    String productName =
                        data['product_name']?.toString() ??
                        appText(context, km: 'ទំនិញ', en: 'Product');
                    dynamic priceData = data['price'];
                    String productPrice = '0';
                    if (priceData != null &&
                        priceData.toString().trim().isNotEmpty) {
                      productPrice = priceData
                          .toString()
                          .replaceAll(',', '')
                          .trim();
                    }
                    String addedByName =
                        data['customer_name']?.toString() ?? '';
                    bool addedByMe = data['customer_id'] == currentUserId;

                    return Container(
                      width: 72,
                      margin: const EdgeInsets.only(right: 5, bottom: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: addedByMe ? Colors.green : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5),
                                ),
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        height: 23,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        height: 23,
                                        color: Colors.grey[200],
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 1,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "${NumberFormat('#,###').format(double.tryParse(productPrice) ?? 0)} ៛",
                                      style: const TextStyle(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                    if (addedByName.isNotEmpty)
                                      Text(
                                        addedByMe
                                            ? appText(
                                                context,
                                                km: 'ខ្លួនឯង',
                                                en: 'You',
                                              )
                                            : addedByName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 6,
                                          color: addedByMe
                                              ? Colors.green[700]
                                              : Colors.orange[700],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => items[index].reference.delete(),
                              child: Container(
                                padding: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.7),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(4),
                                    topRight: Radius.circular(5),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Messages List ─────────────────────────────────────────────
  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where(
            'chatRoomId',
            isEqualTo: getChatRoomId(currentUserId, widget.seller_id),
          )
          .orderBy('time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("Chat Stream Error: ${snapshot.error}");
          return _buildErrorWidget(snapshot.error);
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data!.docs;

        if (_isBlocked) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['sender'] == currentUserId;
          }).toList();
        }

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "មិនទាន់មានសារ\nចាប់ផ្តើមសន្ទនាឥឡូវនេះ!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        // Mark messages as seen
        final Set<String> seenUpdated = {};
        for (var doc in docs) {
          if (doc.exists) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['receiver'] == currentUserId &&
                data['isSeen'] == false &&
                !seenUpdated.contains(doc.id)) {
              seenUpdated.add(doc.id);
              doc.reference
                  .update({'isSeen': true})
                  .catchError((e) => debugPrint("Update isSeen error: $e"));
            }
          }
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          itemCount: docs.length,
          cacheExtent: 500,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            bool isMe = data['sender'] == currentUserId;

            DateTime messageDate = data['time'] != null
                ? (data['time'] as Timestamp).toDate()
                : DateTime.now();

            bool showDateHeader = false;
            if (index == docs.length - 1) {
              showDateHeader = true;
            } else {
              DateTime nextMessageDate =
                  (docs[index + 1].data() as Map<String, dynamic>)['time']
                      .toDate();
              if (messageDate.day != nextMessageDate.day ||
                  messageDate.month != nextMessageDate.month ||
                  messageDate.year != nextMessageDate.year) {
                showDateHeader = true;
              }
            }

            return Column(
              children: [
                if (showDateHeader)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _formatDateHeader(messageDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                _buildChatBubble(data, isMe, docs[index].id),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildErrorWidget(dynamic error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          const Text(
            "មិនអាចផ្ទុកសារបាន",
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "$error",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: Text('ព្យាយាមម្តងទៀត'.tr),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  OPTIMIZED CHAT BUBBLE - Instant thumbnails, no spinning!
  // ═══════════════════════════════════════════════════════════════

  Widget _buildChatBubble(Map<String, dynamic> data, bool isMe, String docId) {
    final messageDate = data['time'] != null
        ? (data['time'] as Timestamp).toDate()
        : DateTime.now();
    String status = data['status'] ?? 'sent';
    bool isMedia = data['type'] != 'text' && data['type'] != 'location';
    bool isLocation = data['type'] == 'location';
    bool isHighlighted = _highlightedMessages.contains(docId);

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context, data, docId),
      child: Container(
        color: isHighlighted
            ? Colors.amber.withOpacity(0.15)
            : Colors.transparent,
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Material(
                elevation: isMedia ? 4.0 : 2.0,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe
                      ? const Radius.circular(18)
                      : const Radius.circular(0),
                  bottomRight: isMe
                      ? const Radius.circular(0)
                      : const Radius.circular(18),
                ),
                color: isLocation
                    ? (isMe ? const Color(0xFF1B5E20) : const Color(0xFFE8F5E9))
                    : (isMedia
                          ? Colors.transparent
                          : (isMe ? Colors.green[600] : Colors.grey[200])),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  margin: EdgeInsets.all(isMedia ? 2 : 0),
                  padding: const EdgeInsets.all(5),
                  child: Stack(
                    children: [
                      Opacity(
                        opacity: status == 'sending' ? 0.85 : 1.0,
                        child: isLocation
                            ? _buildLocationBubble(data, isMe)
                            : _buildMessageContent(data, isMe, docId),
                      ),
                      // Show progress indicator only as small overlay, not blocking
                      if (status == 'sending' && data['type'] != 'text')
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: (data['progress'] as num?)?.toDouble(),
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 15, top: 4, bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(messageDate),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 4),
                      status == 'sending'
                          ? const Icon(
                              Icons.access_time,
                              color: Colors.grey,
                              size: 12,
                            )
                          : Icon(
                              data['status'] == 'seen'
                                  ? Icons.done_all
                                  : Icons.done,
                              color: data['status'] == 'seen'
                                  ? Colors.blue
                                  : Colors.grey,
                              size: 14,
                            ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  INSTANT MESSAGE CONTENT - No more spinning loaders!
  //  Uses local thumbnails for instant preview
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMessageContent(
    Map<String, dynamic> data,
    bool isMe,
    String docId,
  ) {
    switch (data['type']) {
      case 'image':
        return _buildImageMessage(data, docId);

      case 'video':
        return _buildVideoMessage(data, docId);

      case 'audio':
        return _buildAudioMessage(data, isMe);

      default:
        return _buildTextMessage(data, isMe);
    }
  }

  /// Image message with INSTANT local thumbnail preview
  Widget _buildImageMessage(Map<String, dynamic> data, String docId) {
    String? localPath = data['localPath'];
    String fileUrl = data['fileUrl'] ?? '';
    bool isSending = data['status'] == 'sending';

    // KEY: Use local thumbnail for instant display while uploading
    Uint8List? localThumb = _localImageThumbnails[docId];

    return GestureDetector(
      onTap: fileUrl.isNotEmpty
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaViewer(url: fileUrl, type: 'image'),
                ),
              );
            }
          : null,
      child: Container(
        width: 200,
        height: 200,
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[200],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Priority 1: Local thumbnail (instant)
              if (localThumb != null)
                Image.memory(
                  localThumb,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              // Priority 2: Local file path (while sending)
              else if (isSending && localPath != null)
                Image.file(File(localPath), fit: BoxFit.cover)
              // Priority 3: Cached network image (after upload)
              else if (fileUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: fileUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, error, stackTrace) =>
                      const Icon(Icons.error, color: Colors.red),
                )
              // Fallback
              else
                Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Video message with INSTANT local thumbnail preview
  Widget _buildVideoMessage(Map<String, dynamic> data, String docId) {
    String? localPath = data['localPath'];
    String fileUrl = data['fileUrl'] ?? '';
    bool isSending = data['status'] == 'sending';
    double? progress = (data['progress'] as num?)?.toDouble();

    // KEY: Use local thumbnail for instant display
    Uint8List? localThumb = _localVideoThumbnails[docId];

    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        // ✅ បើ fileUrl មានរួច (Upload ចប់ហើយ) ប្រើ ChatVideoBubble ដោយផ្ទាល់
        // ដើម្បីឱ្យវាគ្រប់គ្រង aspect ratio ត្រឹមត្រូវ (មិនសំបែត) និង
        // ប៊ូតុង play/pause ដែលដំណើរការចេញពី widget ខ្លួនឯង (មិនមាន icon
        // ថេរណាមួយពីលើទប់ការចុចទៀតទេ)
        child: fileUrl.isNotEmpty
            ? ChatVideoBubble(
                url: fileUrl,
                localPath: localPath,
                isSending: isSending,
                progress: progress,
              )
            // ✅ ពេលកំពុង Upload (មិនទាន់មាន fileUrl) បង្ហាញ local thumbnail
            // ជាមួយ AspectRatio 9:16 (រាងឈរដូចវីដេអូទូរស័ព្ទភាគច្រើន)
            // ដើម្បីកុំឱ្យរូបខូចរាង/សំបែត
            : AspectRatio(
                aspectRatio: 9 / 16,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: Colors.black,
                      child: localThumb != null
                          ? Image.memory(
                              localThumb,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            )
                          : const Center(
                              child: Icon(
                                Icons.videocam,
                                color: Colors.white54,
                                size: 40,
                              ),
                            ),
                    ),
                    if (localThumb != null)
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white70,
                          size: 46,
                        ),
                      ),
                    if (isSending)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: progress,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Audio message - shows waveform placeholder while uploading
  Widget _buildAudioMessage(Map<String, dynamic> data, bool isMe) {
    final int durationSeconds = data['durationSeconds'] ?? 0;
    final bool hasUrl =
        data['fileUrl'] != null && data['fileUrl'].toString().isNotEmpty;
    final bool isSending = data['status'] == 'sending';

    if (!hasUrl && isSending) {
      // INSTANT placeholder - no spinning, just a nice waveform skeleton
      return Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            // Fake waveform bars
            Row(
              children: List.generate(12, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 3,
                  height: 8 + (index % 3) * 6.0,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(durationSeconds),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (hasUrl) {
      return AudioBubble(url: data['fileUrl'], isMe: isMe);
    }

    return _buildAudioError("សម្លេងមិនអាចផ្ទុកបាន");
  }

  Widget _buildAudioError(String message) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_off, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTextMessage(Map<String, dynamic> data, bool isMe) {
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: data['message']));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('បានចម្លងហើយ!', style: TextStyle(fontFamily: 'Siemreap')),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Text(
        data['message'],
        style: TextStyle(color: isMe ? Colors.white : Colors.black87),
      ),
    );
  }

  // ─── Location Bubble ───────────────────────────────────────────
  Widget _buildLocationBubble(Map<String, dynamic> data, bool isMe) {
    final locationData = data['locationData'] as Map<String, dynamic>?;
    final bool isVireak = locationData?['isVireakBuntham'] ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: isMe ? Colors.white : Colors.green[700],
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isVireak
                      ? appText(
                          context,
                          km: 'ទីតាំងផ្ញើតាមវិរៈ',
                          en: 'Vireak delivery location',
                        )
                      : appText(
                          context,
                          km: 'ទីតាំងទទួលឥវ៉ាន់',
                          en: 'Delivery location',
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isMe ? Colors.white : Colors.green[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _buildLocationRow(
            Icons.map_outlined,
            appText(context, km: 'ខេត្ត/ក្រុង', en: 'Province/City'),
            locationData?['province'] ?? '',
            isMe,
          ),
          if (!isVireak && locationData?['district'] != null)
            _buildLocationRow(
              Icons.location_city_outlined,
              appText(context, km: 'ស្រុក/ខណ្ឌ', en: 'District'),
              locationData!['district'],
              isMe,
            ),
          if (isVireak && locationData?['vireakBranch'] != null)
            _buildLocationRow(
              Icons.store_outlined,
              appText(context, km: 'សាខាវិរៈ', en: 'Vireak branch'),
              locationData!['vireakBranch'],
              isMe,
            ),
          _buildLocationRow(
            Icons.home_outlined,
            appText(context, km: 'អាសយដ្ឋាន', en: 'Address'),
            locationData?['address'] ?? '',
            isMe,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(
    IconData icon,
    String label,
    String value,
    bool isMe,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: isMe ? Colors.white70 : Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "$label: $value",
              style: TextStyle(
                fontSize: 12,
                color: isMe ? Colors.white.withOpacity(0.9) : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Recording Hint ────────────────────────────────────────────
  Widget _buildRecordingHint() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_back, size: 14, color: Colors.grey[500]),
          Text(
            appText(context, km: ' អូសទៅឆ្វេងដើម្បីលុប', en: ' Swipe left to cancel'),
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ─── Input Panel ───────────────────────────────────────────────
  Widget _buildInputPanel() {
    // Keep chat history visible; blocking only disables sending.
    if (_isBlocked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border(top: BorderSide(color: Colors.orange.shade200)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.orange.shade800, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'chat_you_blocked'.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Siemreap',
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: _isLoadingBlock ? null : _showUnblockConfirmDialog,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('chat_unblock'.tr, style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      );
    }

    if (_amIBlocked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border(top: BorderSide(color: Colors.red.shade200)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Icon(Icons.block, color: Colors.red.shade400, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'chat_blocked_you'.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Siemreap',
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Add button
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.green,
                size: 28,
              ),
              onPressed: _showPickerOptions,
            ),

            // Location button
            IconButton(
              icon: const Icon(
                Icons.location_on_outlined,
                color: Colors.red,
                size: 26,
              ),
              onPressed: _showLocationPickerSheet,
            ),

            Expanded(
              child: _isRecording
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fiber_manual_record,
                            color: Colors.red,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            appText(context, km: 'កំពុងថតសម្លេង...', en: 'Recording...'),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Siemreap',
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _msgController,
                        maxLines: 5,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: appText(
                            context,
                            km: 'សរសេរសារ...',
                            en: 'Write a message...',
                          ),
                          hintStyle: const TextStyle(
                            fontFamily: 'Siemreap',
                            fontSize: 12,
                          ),
                          hintMaxLines: 1,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
            ),

            const SizedBox(width: 6),

            // Voice / Send button
            _msgController.text.trim().isEmpty
                ? GestureDetector(
                    // Desktop browsers do not naturally expose the mobile
                    // press-and-hold interaction. On Web, one click starts
                    // recording and the next click stops and sends it.
                    onTap: kIsWeb
                        ? () {
                            if (_isRecording) {
                              _stopRecording();
                            } else {
                              _startRecording();
                            }
                          }
                        : null,
                    onLongPressStart: kIsWeb ? null : (_) => _startRecording(),
                    onLongPressMoveUpdate: kIsWeb
                        ? null
                        : (details) {
                            setState(() {
                              _dragOffset = details.offsetFromOrigin.dx;
                            });
                          },
                    onLongPressEnd: kIsWeb
                        ? null
                        : (details) {
                            if (_dragOffset < -80) {
                              _cancelRecording();
                            } else {
                              _stopRecording();
                            }
                            setState(() => _dragOffset = 0);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? (_dragOffset < -50
                                  ? Colors.red.shade900
                                  : Colors.red)
                            : Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        _isRecording
                            ? (_dragOffset < -50
                                  ? Icons.delete_forever_rounded
                                  : Icons.mic_rounded)
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => _sendMessage(text: _msgController.text),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // ─── Quick Replies ─────────────────────────────────────────────
  Widget _buildQuickReplies() {
    return SizedBox(
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ActionChip(
              elevation: 4,
              avatar: const Icon(
                Icons.receipt_long,
                color: Colors.white,
                size: 16,
              ),
              label: Text(
                'chat_create_invoice'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              backgroundColor: Colors.amber[800],
              onPressed: _openInvoiceSheet,
            ),
          ),
          ..._quickReplyKeys.map((key) {
            final reply = key.tr;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: ActionChip(
                label: Text(
                  reply,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () => _sendMessage(text: reply),
                backgroundColor: Colors.green[50],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Picker Options ────────────────────────────────────────────
  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: Text(appText(context, km: 'ជ្រើសរើសរូបភាពពី Gallery', en: 'Choose images from Gallery')),
              subtitle: Text(
                appText(context, km: 'ជ្រើសរើសបានច្រើនសន្លឹកក្នុងពេលតែមួយ', en: 'Select multiple images at once'),
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickMultipleImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: Text(appText(context, km: 'ថតរូបថ្មី', en: 'Take a new photo')),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.orange),
              title: Text(appText(context, km: 'វីដេអូពី Gallery', en: 'Choose video from Gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.red),
              title: Text(appText(context, km: 'ថតវីដេអូថ្មី', en: 'Record a new video')),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, true);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ─── Location Picker Sheet ─────────────────────────────────────
  void _showLocationPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationPickerSheet(
        onLocationSelected: (locationData) {
          _sendLocationMessage(
            province: locationData['province'],
            district: locationData['district'],
            vireakBranch: locationData['vireakBranch'],
            address: locationData['address'],
            isVireakBuntham: locationData['isVireakBuntham'],
          );
        },
      ),
    );
  }

  // ─── Block/Unblock Dialogs ─────────────────────────────────────
  void _showBlockConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('chat_block_title'.tr),
        content: Text(
          'chat_block_body'.tr,
          style: const TextStyle(fontFamily: 'Siemreap'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('chat_cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _blockUser();
            },
            child: Text('chat_block'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUnblockConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('chat_unblock_title'.tr),
        content: Text(
          'chat_unblock_body'.tr,
          style: const TextStyle(fontFamily: 'Siemreap'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('chat_cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _unblockUser();
            },
            child: Text('chat_unblock'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Message Options ───────────────────────────────────────────
  void _showMessageOptions(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (data['type'] == 'text')
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.blue),
                title: const Text('ចម្លង'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: data['message']));
                  Navigator.pop(context);
                  _showSnack('បានចម្លងហើយ!', Colors.green);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('លុបសារ'),
              onTap: () {
                FirebaseFirestore.instance
                    .collection('chats')
                    .doc(docId)
                    .delete();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Open Seller Shop ──────────────────────────────────────────
  Future<void> _openSellerShop() async {
    String sellerName = widget.productName;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.seller_id)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        sellerName = data['name'] ?? sellerName;
      }
    } catch (e) {
      debugPrint("Error getting seller name: $e");
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SellerProfileScreen(
            sellerId: widget.seller_id,
            sellerName: sellerName,
          ),
        ),
      );
    }
  }

  // ─── Invoice Sheet ─────────────────────────────────────────────
  void _openInvoiceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateInvoiceSheet(
        onAction: (invoiceData) async {
          final String actionType = invoiceData['type'];

          if (actionType == 'save' || actionType == 'screenshot') {
            String sellerName = 'អ្នកលក់';
            String sellerPhone = '';
            String sellerSesanId = '';
            String sellerLocation = '';

            try {
              final prefs = await SharedPreferences.getInstance();
              final uid = prefs.getString('user_uid');

              if (uid != null && uid.isNotEmpty) {
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get();

                if (userDoc.exists) {
                  final data = userDoc.data()!;
                  sellerName = data['name'] ?? 'អ្នកលក់';
                  sellerPhone = data['phone'] ?? '';
                  sellerSesanId = data['sesan_id'] ?? '';
                }

                final productSnap = await FirebaseFirestore.instance
                    .collection('products')
                    .where('seller_id', isEqualTo: uid)
                    .limit(1)
                    .get();
                if (productSnap.docs.isNotEmpty) {
                  sellerLocation =
                      productSnap.docs.first.data()['location'] ?? '';
                }
              }
            } catch (_) {}

            final double grandTotal =
                (invoiceData['total'] as num?)?.toDouble() ?? 0;

            await InvoiceCaptureHelper.captureInvoice(
              context: context,
              screenshotController: _screenshotController,
              sellerName: sellerName,
              sellerPhone: sellerPhone,
              sellerSesanId: sellerSesanId,
              sellerLocation: sellerLocation,
            );

            await FirebaseFirestore.instance.collection('invoices').add({
              'buyer_name': CreateInvoiceSheet.cusName.text,
              'buyer_phone': CreateInvoiceSheet.cusPhone.text,
              'buyer_address': CreateInvoiceSheet.cusAddress.text,
              'total_amount': grandTotal,
              'seller_name': sellerName,
              'seller_phone': sellerPhone,
              'seller_sesan_id': sellerSesanId,
              'created_at': FieldValue.serverTimestamp(),
            });

            if (mounted) {
              Navigator.pop(context);
            }
          } else if (actionType == 'history') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InvoiceHistoryScreen(),
              ),
            );
          }
        },
      ),
    );
  }

  // ─── Format Last Seen ──────────────────────────────────────────
  String _formatLastSeen(dynamic timestamp) {
    if (timestamp == null) return 'chat_offline'.tr;
    try {
      final time = (timestamp as Timestamp).toDate();
      final diff = DateTime.now().difference(time);
      if (diff.inMinutes < 1) return 'chat_last_seen_now'.tr;
      if (diff.inHours < 1) {
        return 'chat_last_seen_minutes'.trParams({'count': minutes.toString()})Params({'count': '${diff.inMinutes}'});
      }
      if (diff.inDays < 1) {
        return 'chat_last_seen_hours'.trParams({'count': hours.toString()})Params({'count': '${diff.inHours}'});
      }
      if (diff.inDays < 7) {
        return 'chat_last_seen_days'.trParams({'count': days.toString()})Params({'count': '${diff.inDays}'});
      }
      return DateFormat('dd/MM/yyyy').format(time);
    } catch (e) {
      return 'chat_unknown'.tr;
    }
  }

  String _formatDateHeader(DateTime date) {
    DateTime now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'ថ្ងៃនេះ';
    }
    DateTime yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'ម្សិលមិញ';
    }
    return DateFormat('EEEE, dd MMMM yyyy', 'km').format(date);
  }
}
