import 'dart:io';
import 'dart:ui' as ui;
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:my_app/audio_bubble_.dart';
import 'package:my_app/chat_video_bubble.dart';
import 'package:my_app/chat_video_player.dart';
import 'package:my_app/create_invoice_sheet.dart';
import 'package:my_app/invoice_history_screen.dart';
import 'package:my_app/order_management_screen.dart';
import 'package:my_app/seller_profile_screen.dart';
import 'package:my_app/user_profile_screen.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:my_app/media_viewer.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:async'; // ✅ បន្ថែមនៅខាងលើ
import 'location_picker_sheet.dart';

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

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin { // ✅ បន្ថែម Mixin
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final Record _audioRecorder = Record();
  final ScreenshotController _screenshotController = ScreenshotController();

  late final String currentUserId;
  bool _isLoading = true; // ✅ បាត់មួយនេះ
  String? _errorMessage; // ✅ បាត់មួយនេះ
  bool _isRecording = false;
  bool _isLocked = false;
  double _dragOffset = 0;
  Set<String> _highlightedMessages = {}; // ✅ បន្ថែមអង្គនេះផង

  // ✅ បន្ថែម animation controller សម្រាប់ប៊ូតុងថត
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    // ✅ បន្ថែម animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    try {
      if (currentUserId.isNotEmpty) {
        _setOnline(false);
      }
    } catch (e) {
      debugPrint("Dispose error: $e");
    }
    _pulseController.dispose(); // ✅ កុំភ្លេច dispose
    super.dispose();
  }

  Future<void> _setOnline(bool isOnline) async {
    try {
      // បើរកមិនឃើញ ID មិនបាច់ឱ្យវាទៅមុខទេ ការពារ DEVELOPER_ERROR
      if (currentUserId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // បើមានបញ្ហា ឱ្យវាបោះ Log ធម្មតា កុំឱ្យវាទាត់ App ចោល
      debugPrint("⚠️ បញ្ហា Online Status: $e");
    }
  }

  // ✅ មុខងារសម្រាប់ Compress និង Upload រូបមួយសន្លឹក
  Future<void> _compressAndUploadImage(File originalFile) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}_${originalFile.hashCode}.jpg';

      XFile? compressed;
      try {
        compressed = await FlutterImageCompress.compressAndGetFile(
          originalFile.path,
          targetPath,
          quality: 60,
          minWidth: 1024,
          minHeight: 1024,
        );
      } catch (compressError) {
        debugPrint("⚠️ Image compress failed: $compressError");
      }

      final imageFile = compressed != null
          ? File(compressed.path)
          : originalFile;

      if (!await imageFile.exists()) {
        debugPrint("❌ ឯកសាររូបភាពមិនត្រឹមត្រូវ");
        return;
      }

      // ✅ Upload ភ្លាមៗ (មិនរងចាំគ្នា)
      _uploadAndSendBackground(imageFile, 'image');
    } catch (e) {
      debugPrint("❌ Compress image error: $e");
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
            _errorMessage = 'សូម Login មុននឹងប្រើឆាត';
          });
        }
        return;
      }

      // --- ចំណុចកែសម្រួលនៅត្រង់នេះ ---
      currentUserId = uid; // កំណត់ ID ឱ្យរួចរាល់សិន

      // បញ្ជាឱ្យ Online ភ្លាមបន្ទាប់ពីស្គាល់ ID
      await _setOnline(true);

      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({'unreadCount': 0})
          .catchError((e) => debugPrint("Reset unreadCount error: $e"));

      if (mounted)
        setState(() {
          _isLoading = false;
        });
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
  final List<String> _quickReplies = [
    "តម្លៃប៉ុន្មាន?",
    "ទីតាំងនៅណាដែរ?",
    "នៅមានស្តុកទេ?",
    "បាទ/ចា៎វានៅមាន",
    "សួស្ដីបង! តើសួរទំនិញមួយណាដែរ?",
    "សុំលេខ និងទីតាំងទទួលឥវ៉ាន់ផងបង",
    "ជួយចេញបុងអោយផង",
    "បាទ/ចា៎បានទទួល! សូមអរគុណច្រើន!🙏",
  ];

  String getChatRoomId(String a, String b) =>
      (a.compareTo(b) <= 0) ? "${a}_$b" : "${b}_$a";

  // --- មុខងារផ្ញើសារ ---
  Future<void> _sendMessage({
    String? text,
    String? fileUrl,
    String? type,
    String status = 'sent',
    File? imageFile,
  }) async {
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
      setState(() {}); // ✅ បន្ថែម setState បន្ទាប់ clear
      _scrollToBottom();
    } catch (e) {
      debugPrint("ផ្ញើសារមិនចេញ៖ $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ផ្ញើសារមិនបាន: $e')));
    }
  }

  Future<void> _cancelRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _dragOffset = 0;
    });
    // ✅ លប់ file ចោល មិនផ្ញើ
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    _showSnack('បានលប់សម្លេង', Colors.orange);
  }

  void _lockRecording() {
    setState(() => _isLocked = true);
    _showSnack('🔒 Lock — ចុច Send ពេលចប់', Colors.green);
  }

  // ✅ មុខងារថ្មី៖ ផ្ញើទីតាំងទៅអ្នកលក់
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
        locationText =
        "ទីតាំងផ្ញើតាមវិរៈប៊ុនថាំ:\n"
            "📍 ខេត្ត/ក្រុង: $province\n"
            "🏪 សាខា: $vireakBranch\n"
            "🏠 អាសយដ្ឋាន: $address";
      } else {
        locationText =
        "ទីតាំងទទួលឥវ៉ាន់:\n"
            "📍 ខេត្ត/ក្រុង: $province\n"
            "🏘️ ស្រុក/ខណ្ឌ: $district\n"
            "🏠 អាសយដ្ឋានលម្អិត: $address";
      }

      final messageData = {
        'chatRoomId': getChatRoomId(currentUserId, widget.seller_id),
        'productId': widget.productId,
        'productName': widget.productName,
        'message': locationText,
        'fileUrl': '',
        'type': 'location', // ✅ type ពិសេសសម្រាប់ទីតាំង
        'time': FieldValue.serverTimestamp(),
        'sender': currentUserId,
        'receiver': widget.receiver_id,
        'users': [currentUserId, widget.seller_id],
        'status': 'sent',
        'isSeen': false,
        // ✅ Metadata សម្រាប់ប្រើប្រាស់បន្ទាប់
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
      ).showSnackBar(SnackBar(content: Text('ផ្ញើទីតាំងមិនបាន: $e')));
    }
  }

  Future<void> _uploadAndSendBackground(File file, String type) async {
    if (!await file.exists()) {
      debugPrint("❌ File does not exist: ${file.path}");
      _showSnack("❌ ឯកសារមិនមាន", Colors.orange);
      return;
    }

    String msgId = FirebaseFirestore.instance.collection('chats').doc().id;
    String chatRoomId = getChatRoomId(currentUserId, widget.seller_id);

    try {
      // ✅ បង្កើត doc ជាមួយ progress
      await FirebaseFirestore.instance.collection('chats').doc(msgId).set({
        'chatRoomId': chatRoomId,
        'productId': widget.productId,
        'productName': widget.productName,
        'message': '',
        'fileUrl': '',
        'localPath': file.path,
        'type': type,
        'time': FieldValue.serverTimestamp(),
        'sender': currentUserId,
        'receiver': widget.receiver_id,
        'users': [currentUserId, widget.seller_id],
        'status': 'sending',
        'progress': 0, // ✅ បន្ថែម progress
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("❌ Failed to create message doc: $e");
      return;
    }

    try {
      String ext = type == 'image'
          ? 'jpg'
          : type == 'video'
          ? 'mp4'
          : 'm4a';
      String path = 'chat_$type/${DateTime.now().millisecondsSinceEpoch}.$ext';
      Reference ref = FirebaseStorage.instance.ref().child(path);

      debugPrint("⬆️ Uploading $type: ${file.path}");

      // ✅ ប្រើ putFile ជាមួយ listen សម្រាប់ progress
      final uploadTask = ref.putFile(file);

      // ✅ Listen to progress (optional - បើចង់បង្ហាញ progress bar)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        FirebaseFirestore.instance
            .collection('chats')
            .doc(msgId)
            .update({'progress': progress})
            .catchError((e) => debugPrint("Progress update error: $e"));
      });

      await uploadTask.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException("Upload timeout");
        },
      );

      String url = await ref.getDownloadURL();
      debugPrint("✅ Upload success: $url");

      await FirebaseFirestore.instance.collection('chats').doc(msgId).update({
        'fileUrl': url,
        'status': 'sent',
        'localPath': FieldValue.delete(),
        'progress': FieldValue.delete(),
      });
    } on TimeoutException catch (e) {
      debugPrint("⏱️ Upload timeout: $e");
      await FirebaseFirestore.instance.collection('chats').doc(msgId).update({
        'status': 'error',
        'errorMessage': 'Upload timeout',
      });
      _showSnack("⏱️ ផ្ទុកយឺតពេក", Colors.orange);
    } catch (e) {
      debugPrint("❌ Upload error: $e");
      await FirebaseFirestore.instance.collection('chats').doc(msgId).update({
        'status': 'error',
        'errorMessage': e.toString(),
      });
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
        // ✅ 1. បង្ហាញ "sending" ភ្លាម (មិនរង់ចាំ compression!)
        _uploadVideoWithThumbnail(originalFile);
      } else {
        _compressAndUploadImage(originalFile);
      }
    } catch (e) {
      debugPrint("❌ Pick media error: $e");
    }
  }

  // ✅ ថ្មី: ផ្ញើភ្លាម ហើយ compress នៅខាងក្រោយ
  Future<void> _uploadVideoWithThumbnail(File originalFile) async {
    // 1. បង្កើត message doc ជាមួយ status "sending"
    String msgId = FirebaseFirestore.instance.collection('chats').doc().id;
    String chatRoomId = getChatRoomId(currentUserId, widget.seller_id);

    await FirebaseFirestore.instance.collection('chats').doc(msgId).set({
      'chatRoomId': chatRoomId,
      'productId': widget.productId,
      'productName': widget.productName,
      'message': '',
      'fileUrl': '',
      'localPath': originalFile.path, // ✅ រក្សា path សម្រាប់បង្ហាញ thumbnail
      'type': 'video',
      'time': FieldValue.serverTimestamp(),
      'sender': currentUserId,
      'receiver': widget.receiver_id,
      'users': [currentUserId, widget.seller_id],
      'status': 'sending',
      'progress': 0,
    });
    _scrollToBottom();

    // 2. ធ្វើការងារធ្ងន់នៅ background (compression + upload)
    _processVideoInBackground(msgId, originalFile);
  }

  Future<void> _processVideoInBackground(
      String msgId,
      File originalFile,
      ) async {
    try {
      File fileToUpload = originalFile;

      // ✅ Compress តែបើ file ធំជាង 50MB
      final originalSize = await originalFile.length();
      if (originalSize > 50 * 1024 * 1024) {
        final info = await VideoCompress.compressVideo(
          originalFile.path,
          quality: VideoQuality.LowQuality, // ✅ Low លឿនជាង Medium
          deleteOrigin: false,
          includeAudio: true,
        );
        if (info?.file != null) {
          fileToUpload = info!.file!;
        }
      }

      String path = 'chat_video/${DateTime.now().millisecondsSinceEpoch}.mp4';
      Reference ref = FirebaseStorage.instance.ref().child(path);

      final uploadTask = ref.putFile(fileToUpload);

      uploadTask.snapshotEvents.listen((snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        FirebaseFirestore.instance.collection('chats').doc(msgId).update({
          'progress': progress,
        });
      });

      await uploadTask.timeout(const Duration(minutes: 5));
      String url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('chats').doc(msgId).update({
        'fileUrl': url,
        'status': 'sent',
        'localPath': FieldValue.delete(),
        'progress': FieldValue.delete(),
      });
    } catch (e) {
      await FirebaseFirestore.instance.collection('chats').doc(msgId).update({
        'status': 'error',
        'errorMessage': e.toString(),
      });
    }
  }
  Future<void> _openSellerShop() async {
    // ទាញឈ្មោះអ្នកលក់ពី Firestore
    String sellerName = widget.productName; // fallback
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


  Future<File> _compressVideoFast(String inputPath) async {
    try {
      final originalSize = await File(inputPath).length();

      final info = await VideoCompress.compressVideo(
        inputPath,
        quality: VideoQuality.Res640x480Quality, // ✅ តូចជាង LowQuality
        deleteOrigin: false,
        includeAudio: true,
      );

      if (info?.file != null) {
        final compressedSize = await info!.file!.length();
        debugPrint(
          '✅ ${(originalSize / 1024 / 1024).toStringAsFixed(1)}MB → '
              '${(compressedSize / 1024 / 1024).toStringAsFixed(1)}MB',
        );
        return info.file!;
      }

      return File(inputPath); // fallback
    } catch (e) {
      debugPrint('⚠️ Compress failed: $e');
      return File(inputPath); // fallback
    }
  }

  // ✅ មុខងារថ្មី៖ ជ្រើសរើសរូបភាពច្រើនសន្លឹក
  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> files = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920, // ✅ កំណត់ទំហំធំបន្តិច
        maxHeight: 1920,
      );

      if (files.isEmpty) {
        debugPrint("⚠️ អ្នកមិនបានជ្រើសរើសរូបភាព");
        return;
      }

      debugPrint("📸 ជ្រើសរើសបាន ${files.length} សន្លឹក");

      // ✅ ផ្ញើទាំងអស់ពីរបៀប async (មិនរងចាំគ្នា)
      for (final file in files) {
        final originalFile = File(file.path);

        if (!await originalFile.exists()) {
          debugPrint("❌ រកមិនឃើញឯកសារ: ${file.path}");
          continue;
        }

        // ✅ Compress និង upload រូបនីមួយៗ
        await _compressAndUploadImage(originalFile);
      }

      _showSnack("✅ បានផ្ញើ ${files.length} សន្លឹក", Colors.green);
    } catch (e, stackTrace) {
      debugPrint("❌ Pick multiple images error: $e");
      debugPrint(stackTrace.toString());
      _showSnack("មានបញ្ហា: $e", Colors.red);
    }
  }Future<void> _startRecording() async {
    if (_isRecording) return;

    // ✅ ញ័រដើម្បីឲ្យដឹងថាចាប់ផ្ដើមថត
    HapticFeedback.mediumImpact();

    // បង្កើតផ្លូវឯកសារមុន
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    setState(() => _isRecording = true);  // បង្ហាញ UI ភ្លាម

    try {
      // ✅ ប្រើ bitrate & sample rate ទាប ដើម្បីឲ្យ Recorder ចាប់ផ្ដើមលឿន (សំឡេងនៅតែគ្រប់គ្រាន់)
      await _audioRecorder.start(
        encoder: AudioEncoder.aacLc,
        bitRate: 48000,
        samplingRate: 22050,
        path: path,
      );
    } catch (e) {
      debugPrint("❌ Start recording error: $e");
      if (mounted) {
        setState(() => _isRecording = false);
        _showSnack('មិនអាចចាប់ផ្តើមថតបានទេ', Colors.red);
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (!_isRecording) return; // ✅ កុំឲ្យ stop ពេលមិនបានថត

      final path = await _audioRecorder.stop();

      if (mounted) {
        setState(() {
          _isRecording = false;
          _isLocked = false;
          _dragOffset = 0;
        });
      }

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          _uploadAndSendBackground(file, 'audio');
        }
      }
    } catch (e) {
      debugPrint("❌ Stop recording error: $e");
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isLocked = false;
        });
      }
    }
  }
  // ✅ បង្ហាញ Bottom Sheet ជ្រើសរើសទីតាំង (ដូច ReceiptScreen)
  void _showLocationPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // បង្ខំឲ្យ LocationPickerSheet rebuild នៅពេលមានការផ្លាស់ប្តូរ
            return LocationPickerSheet(
              onLocationSelected: (locationData) {
                _sendLocationMessage(
                  province: locationData['province'],
                  district: locationData['district'],
                  vireakBranch: locationData['vireakBranch'],
                  address: locationData['address'],
                  isVireakBuntham: locationData['isVireakBuntham'],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          title: const Text('ឆាត'),
        ),

        body: GestureDetector(       // <-- បន្ថែមនៅទីនេះ
          onTap: () {
            FocusScope.of(context).unfocus(); // បិទ Keyboard
          },
          behavior: HitTestBehavior.opaque,   // សំខាន់ ដើម្បីឱ្យ Gesture ចាប់យកការប៉ះលើ ListView
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.seller_id)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(widget.productName);
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text(widget.productName);
            }

            var userData = snapshot.data!.data() as Map<String, dynamic>?;

            return Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            UserProfileScreen(userId: widget.seller_id),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'profile_image_${widget.seller_id}',
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(
                            userData?['photoUrl'] ??
                                'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                          ),
                        ),
                        // ✅ Online dot
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: (userData?['isOnline'] == true)
                                  ? Colors.greenAccent
                                  : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userData?['name'] ?? 'អ្នកលក់',
                        style: const TextStyle(fontSize: 16),
                      ),
                      // ✅ Online status / lastSeen
                      Text(
                        userData?['isOnline'] == true
                            ? '🟢 កំពុង Online'
                            : _formatLastSeen(userData?['lastSeen']),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          // ✅ ប៊ូតុងមើលហាង
          IconButton(
            icon: const Icon(Icons.store, color: Colors.white),
            tooltip: 'មើលហាង',
            onPressed: () => _openSellerShop(),
          ),


          // ✅ ប៊ូតុងស្លាកលក់ (Order Management) - កែ Logic ទៅចាប់ ID អ្នកលក់ពិតប្រាកដ
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where(
              'sellerId',
              isEqualTo: widget.seller_id,
            ) // 🎯 ដូរទៅប្រើ widget.seller_id ដើម្បីទាញ Order របស់ហាងនេះ
                .snapshots(),
            builder: (context, orderSnapshot) {
              int orderCount = 0;
              if (orderSnapshot.hasData) {
                orderCount = orderSnapshot.data!.docs.length;
              }


              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.sell,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OrderManagementScreen(sellerId: currentUserId),
                          ),
                        );
                      },
                    ),
                    if (orderCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$orderCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
        body: GestureDetector(       // <-- បន្ថែមនៅទីនេះ
          onTap: () {
            FocusScope.of(context).unfocus(); // បិទ Keyboard
          },
          behavior: HitTestBehavior.opaque,   // សំខាន់ ដើម្បីឱ្យ Gesture ចាប់យកការប៉ះលើ ListView
          child: Column(
            children: [
      // ✅ បង្ហាញទំនិញដែលបានបោះចូលឆាត (ដាក់ក្នុង body ខាងលើ Expanded)
      // ✅ បង្ហាញ Chat Items ទាំង customer និង seller មើលឃើញ
      StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_items')
          .where(
        'chat_room_id',
        isEqualTo: getChatRoomId(currentUserId, widget.seller_id),
      )
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }


        var items = snapshot.data!.docs;


        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_basket,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ទំនិញដែលចង់ទិញ (${items.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        for (var item in items) {
                          await item.reference.delete();
                        }
                      },
                      child: const Text(
                        'លុបទាំងអស់',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              // ✅ បង្ហាញបញ្ជីទំនិញដែលបានបោះចូលឆាត (ជាមួយឈ្មោះ និងស៊ុម)
              // 🎯 រកមើល StreamBuilder<QuerySnapshot> នៃ 'chat_items' រួចដូរដុំ ListView.builder នេះ៖
              SizedBox(
                  height: 75, // 🎯 បង្កើនកម្ពស់ពី 60 ទៅ 75 ដើម្បីល្មមនឹងតម្លៃទំនិញ
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      var data = items[index].data() as Map<String, dynamic>;
                      String imageUrl = data['image_url']?.toString() ?? '';
                      String productName = data['product_name']?.toString() ?? 'ទំនិញ';
// 1. ទាញយកទិន្នន័យតម្លៃពី Firestore (ចេញមកជា "35,000")
                      dynamic priceData = data['price'];
                      String productPrice = '0';

                      if (priceData != null && priceData.toString().trim().isNotEmpty) {
                        // 🎯 គន្លឹះសំខាន់៖ លុបសញ្ញាក្បៀស (,) ចេញ ដើម្បីឱ្យសល់តែលេខសុទ្ធ "35000"
                        String cleanPrice = priceData.toString().replaceAll(',', '').trim();

                        // 2. យកទៅដាក់ចូល productPrice វិញ
                        productPrice = cleanPrice;
                      }


                      String addedByName = data['customer_name']?.toString() ?? '';
                      bool addedByMe = data['customer_id'] == currentUserId;

                      return Container(
                          width: 85, // 🎯 បង្កើនទទឹងបន្តិចពី 80 ទៅ 85
                          margin: const EdgeInsets.only(right: 6, bottom: 4),
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
                              // រូបភាពតូច
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                child: imageUrl.isNotEmpty
                                    ? Image.network(imageUrl, height: 30, width: double.infinity, fit: BoxFit.cover)
                                    : Container(height: 30, color: Colors.grey[200]),
                              ),
                              // ឈ្មោះទំនិញ + តម្លៃ + អ្នកបន្ថែម
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold),
                                    ),
                                    // 🎯 បន្ថែមការបង្ហាញតម្លៃពណ៌ក្រហមនៅត្រង់នេះ
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
                                        addedByMe ? 'ខ្លួនឯង' : addedByName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 6,
                                          color: addedByMe ? Colors.green[700] : Colors.orange[700],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // ប៊ូតុងលុបតូច
                          Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                  onTap: () => items[index].reference.delete(),
                                  child: Container(
                                      padding: const EdgeInsets.all(1),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.7),
                                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(4),
                                          topRight: Radius.circular(5),
                                        ),
                                      ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 8),
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
    ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "មិនអាចផ្ទុកសារបាន",
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${snapshot.error}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text("ព្យាយាមម្តងទៀត"),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "មិនទាន់មានសារ\nចាប់ផ្តើមសន្ទនាឥឡូវនេះ!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // ✅ ថ្មី — track ហើយ update តែ 1 ដង
                final Set<String> _seenUpdated = {};

                // ក្នុង StreamBuilder builder:
                for (var doc in docs) {
                  if (doc.exists) {
                    var data = doc.data() as Map<String, dynamic>;
                    if (data['receiver'] == currentUserId &&
                        data['isSeen'] == false &&
                        !_seenUpdated.contains(doc.id)) {
                      // ✅ check ជាមុន
                      _seenUpdated.add(doc.id);
                      doc.reference
                          .update({'isSeen': true})
                          .catchError(
                            (e) => debugPrint("Update isSeen error: $e"),
                      );
                    }
                  }
                }

                // ✅ ដូរ ListView.builder ឲ្យប្រើ RepaintBoundary
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: docs.length,
                  // ✅ បន្ថែម cacheExtent
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
                      (docs[index + 1].data()
                      as Map<String, dynamic>)['time']
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
            ),
          ),
          if (_isRecording && !_isLocked)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back, size: 14, color: Colors.grey[500]),
                  Text(
                    ' Swipe ឆ្វេង លប់',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          if (!_isRecording) _buildQuickReplies(),
          _buildInputPanel(),
        ],
      ),
        ),
    );
  }

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
                        opacity: status == 'sending' ? 0.5 : 1.0,
                        child: isLocation
                            ? _buildLocationBubble(data, isMe)
                            : _buildMessageContent(data, isMe),
                      ),
                      if (status == 'sending')
                        const Positioned.fill(
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
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
                      // ✅ បន្ថែមម៉ោង
                      Text(
                        DateFormat('HH:mm').format(messageDate),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 4),
                      status == 'sending'
                          ? const Icon(Icons.access_time, color: Colors.grey, size: 12)
                          : Icon(
                        data['status'] == 'seen' ? Icons.done_all : Icons.done,
                        color: data['status'] == 'seen' ? Colors.blue : Colors.grey,
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

  // ✅ Widget ថ្មី៖ បង្ហាញ Bubble ទីតាំង
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
              Text(
                isVireak ? "ទីតាំងផ្ញើតាមវិរៈ" : "ទីតាំងទទួលឥវ៉ាន់",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isMe ? Colors.white : Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _buildLocationRow(
            Icons.map_outlined,
            "ខេត្ត/ក្រុង",
            locationData?['province'] ?? '',
            isMe,
          ),
          if (!isVireak && locationData?['district'] != null)
            _buildLocationRow(
              Icons.location_city_outlined,
              "ស្រុក/ខណ្ឌ",
              locationData!['district'],
              isMe,
            ),
          if (isVireak && locationData?['vireakBranch'] != null)
            _buildLocationRow(
              Icons.store_outlined,
              "សាខាវិរៈ",
              locationData!['vireakBranch'],
              isMe,
            ),
          _buildLocationRow(
            Icons.home_outlined,
            "អាសយដ្ឋាន",
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

  Widget _buildMessageContent(Map<String, dynamic> data, bool isMe) {
    if (data['status'] == 'sending' && data['type'] != 'text') {
      return const SizedBox(
        width: 100,
        height: 40,
        child: Center(
          child: Text("កំពុងផ្ញើ...", style: TextStyle(fontSize: 10)),
        ),
      );
    }

    switch (data['type']) {
      case 'image':
        String? localPath = data['localPath'];
        String fileUrl = data['fileUrl'] ?? '';
        bool isSending = data['status'] == 'sending';

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
            height: isSending ? 200 : null,
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isSending && localPath != null
                  ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(localPath), fit: BoxFit.cover),
                  Container(color: Colors.black38),
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ],
              )
                  : fileUrl.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: fileUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => const Icon(Icons.error),
              )
                  : const Icon(Icons.image_not_supported),
            ),
          ),
        );

      case 'video':
        String? localPath = data['localPath'];
        String fileUrl = data['fileUrl'] ?? '';
        bool isSending = data['status'] == 'sending';
        double? progress = data['progress'] as double?;

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
            child: ChatVideoBubble(
              url: fileUrl,
              localPath: localPath,
              isSending: isSending,
              progress: progress,
            ),
          ),
        );

      case 'audio':
      // ✅ ពិនិត្យបើ URL ទទេ
        if (data['fileUrl'] == null || data['fileUrl'].toString().isEmpty) {
          return _buildAudioError("សម្លេងមិនមាន");
        }
        return AudioBubble(url: data['fileUrl'], isMe: isMe);

      default:
        return GestureDetector(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: data['message']));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'បានចម្លងហើយ!',
                      style: TextStyle(fontFamily: 'Siemreap'),
                    ),
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
  }

  Widget _buildStatusTick(Map<String, dynamic> data) {
    bool isSeen = data['status'] == 'seen';

    return Icon(
      Icons.done_all,
      size: 15,
      color: isSeen ? Colors.blue : Colors.grey,
    );
  }

  Widget _buildInputPanel() {
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
            // ✅ បន្ថែមប៊ូតុងទីតាំង
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.green,
                size: 28,
              ),
              onPressed: _showPickerOptions,
            ),

            // ✅ ប៊ូតុងទីតាំងថ្មី
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
                    const Text(
                      'កំពុងថតសម្លេង...',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Siemreap',
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
                  decoration: const InputDecoration(
                    hintText: 'សរសេរសារ...',
                    hintStyle: TextStyle(fontFamily: 'Siemreap'),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),

            // ✅ ប៊ូតុង Voice Recorder ដែលដក Lock ចេញ និងទុកតែ Cancel
            _msgController.text.trim().isEmpty
                ? Listener(
              onPointerDown: (_) {
                if (!_isRecording) {
                  _startRecording();
                }
              },
              onPointerMove: (details) {
                if (_isRecording) {
                  setState(() {
                    _dragOffset = details.localPosition.dx - 80; // ចាប់ផ្ដើមពីប៊ូតុង
                  });
                }
              },
              onPointerUp: (_) {
                if (!_isRecording) return;
                if (_dragOffset < -80) {
                  _cancelRecording();
                } else {
                  _stopRecording();
                }
                setState(() => _dragOffset = 0);
              },
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _isRecording ? _pulseAnimation.value : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? (_dragOffset < -50 ? Colors.red.shade900 : Colors.red)
                          : Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording
                          ? (_dragOffset < -50
                          ? Icons.delete_forever_rounded
                          : Icons.stop_rounded)
                          : Icons.mic_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
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

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            // ✅ ឈ្មោះថ្មី + លុបមួយចេញ
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text("ជ្រើសរើសរូបភាពពី Gallery"), // ឈ្មោះថ្មី
              subtitle: const Text(
                "ជ្រើសរើសបានច្រើនសន្លឹកក្នុងពេលតែមួយ",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickMultipleImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text("ថតរូបថ្មី"),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.orange),
              title: const Text("វីដេអូពី Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.red),
              title: const Text("ថតវីដេអូថ្មី"),
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

  Widget _buildLockedRecorder() {
    return Row(
      children: [
        // ✅ ប៊ូតុង Cancel
        GestureDetector(
          onTap: _cancelRecording,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: const [
                Icon(Icons.delete_outline, color: Colors.red, size: 18),
                SizedBox(width: 4),
                Text('លប់', style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // ✅ ប៊ូតុង Send
        GestureDetector(
          onTap: _stopRecording,
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
    );
  }

  // ✅ ដូរជា const widget
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
              label: const Text(
                "បង្កើតបុង",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              backgroundColor: Colors.amber[800],
              onPressed: _openInvoiceSheet,
            ),
          ),
          ..._quickReplies.map(
                (reply) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: ActionChip(
                label: Text(reply),
                onPressed: () => _sendMessage(text: reply),
                backgroundColor: Colors.green[50],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openInvoiceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateInvoiceSheet(
        onAction: (invoiceData) async {
          final String actionType = invoiceData['type'];


          if (actionType == 'save' || actionType == 'screenshot') {
            // ✅ ទាញព័ត៌មានអ្នកលក់មុន Screenshot
            String sellerName = 'អ្នកលក់';
            String sellerPhone = '';
            String sellerSesanId = '';
            String sellerLocation = '';


            try {
              // ទាញពី SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              final uid = prefs.getString('user_uid');


              if (uid != null && uid.isNotEmpty) {
                // ទាញពី Firestore
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


                // ទាញទីតាំងពី product ដំបូង
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


            // ✅ ប្រើតម្លៃសរុបដែលបានគណនាពី CreateInvoiceSheet
            final double grandTotal = (invoiceData['total'] as num?)?.toDouble() ?? 0;

            await _captureLongInvoice(
              sellerName: sellerName,
              sellerPhone: sellerPhone,
              sellerSesanId: sellerSesanId,
              sellerLocation: sellerLocation,
              grandTotal: grandTotal, // ✅ បន្ថែមបន្ទាត់នេះ!
            );

            await FirebaseFirestore.instance.collection('invoices').add({
              'buyer_name': CreateInvoiceSheet.cusName.text,
              'buyer_phone': CreateInvoiceSheet.cusPhone.text,
              'buyer_address': CreateInvoiceSheet.cusAddress.text,
              'total_amount': double.tryParse(_calculateGrandTotal()) ?? 0.0,
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


  Future<void> _captureLongInvoice({
    String sellerName = 'អ្នកលក់',
    String sellerPhone = '',
    String sellerSesanId = '',
    String sellerLocation = '',
    double grandTotal = 0, // ✅ បន្ថែម
  }) async {
    try {
      const int itemsPerPage = 10;
      int totalItems = CreateInvoiceSheet.items.length;
      int totalPages = (totalItems / itemsPerPage).ceil();


      for (int i = 0; i < totalPages; i++) {
        int start = i * itemsPerPage;
        int end = (start + itemsPerPage > totalItems)
            ? totalItems
            : start + itemsPerPage;
        List currentPageItems = CreateInvoiceSheet.items.sublist(start, end);


        final imageUint8List = await _screenshotController.captureFromWidget(
          Material(
            color: Colors.white,
            child: Directionality(
              textDirection: ui.TextDirection.ltr,
              child: Container(
                width: 375,
                padding: const EdgeInsets.all(
                  15,
                ), // បន្ថយ padding ដើម្បីសន្សំផ្ទៃ capture
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🎯 ហៅ Header ថ្មីដោយបោះព័ត៌មានអ្នកលក់ចូលទៅបង្ហាញនៅទំព័រទី១
                    if (i == 0)
                      _buildCaptureHeader(
                        sellerName: sellerName,
                        sellerPhone: sellerPhone,
                        sellerSesanId: sellerSesanId,
                        sellerLocation: sellerLocation,
                      ),


                    const SizedBox(height: 6),
                    Text(
                      "បញ្ជីទំនិញ (សន្លឹកទី ${i + 1})",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                    const Divider(thickness: 1, color: Colors.black),


                    // 🎯 កែសម្រួលត្រង់នេះ៖ បោះ index សរុបទៅឱ្យ Row នីមួយៗដើម្បីរាប់លេខជួរឈរ
                    ...currentPageItems.asMap().entries.map((entry) {
                      int localIndex = entry.key;
                      dynamic item = entry.value;
                      int globalIndex =
                          start +
                              localIndex; // គណនាគម្លាតលេខរាប់ទៅតាមទំព័រនីមួយៗ (ទំព័រទី២ រាប់បន្តពីទំព័រទី១)


                      return _buildCaptureItemRow(item, globalIndex);
                    }).toList(),


              if (i == totalPages - 1) ...[
            const Divider(thickness: 1, color: Colors.black),
            _buildCaptureTotalAndQR(grandTotal), // ✅ បញ្ជូន grandTotal
    ],
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        "--- ${i + 1} / $totalPages ---",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          pixelRatio: 3.0,
        );


        if (imageUint8List != null) {
          await Gal.putImageBytes(imageUint8List);
        }
      }


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ បានថតបំបែកជា $totalPages សន្លឹកក្នុង Gallery"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Capture Error: $e");
    }
  }


  Widget _buildCaptureHeader({
    required String sellerName,
    required String sellerPhone,
    required String sellerSesanId,
    required String sellerLocation,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🎯 ចំណងជើងវិក្កយបត្រ (បង្រួម Font សន្សំ Space)
        const Center(
          child: Text(
            "វិក្កយបត្រ / INVOICE",
            style: TextStyle(
              fontSize: 16, // 🎯 បន្ថយពី ២២ មក ១៦
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 2),
        const Divider(thickness: 1.5, color: Colors.black),
        const SizedBox(height: 4),


        // 🏪 កែប្រែទី១៖ ព័ត៌មានអ្នកលក់ (Seller Info) ឡើងមកនៅលើគេបង្អស់
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6), // បង្រួម padding
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🏪 អ្នកលក់៖ $sellerName',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11, // 🎯 បង្រួម Font មក ១១
                  color: Colors.black,
                ),
              ),
              if (sellerPhone.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  '📞 លេខទូរស័ព្ទ៖ $sellerPhone',
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ],
              if (sellerSesanId.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  '🆔 Sesan ID៖ $sellerSesanId',
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ],
              if (sellerLocation.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  '📍 ទីតាំង៖ $sellerLocation',
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ],
            ],
          ),
        ),


        const SizedBox(height: 6), // គម្លាតតូចរវាងអ្នកលក់ និងអ្នកទិញ
        // 👤 កែប្រែទី២៖ ព័ត៌មានអ្នកទិញ (Buyer Info) ធ្លាក់មកនៅខាងក្រោម
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "👤 អ្នកទិញ៖ ${CreateInvoiceSheet.cusName.text}",
                style: const TextStyle(
                  fontSize: 11, // 🎯 បង្រួម Font
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                "📞 លេខទូរស័ព្ទ៖ ${CreateInvoiceSheet.cusPhone.text}",
                style: const TextStyle(fontSize: 10, color: Colors.black87),
              ),
              const SizedBox(height: 1),
              Text(
                "🏠 អាសយដ្ឋាន៖ ${CreateInvoiceSheet.cusAddress.text}",
                style: const TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
      ],
    );
  }


  // 🎯 មុខងារបង្ហាញជួរទំនិញ៖ បន្ថែមប៉ារ៉ាម៉ែត្រ index ដើម្បីបង្ហាញលេខរាប់ជួរឈរ (1, 2, 3...)
  Widget _buildCaptureItemRow(dynamic item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start, // ឱ្យអក្សរ និងលេខតម្រឹមស្មើគ្នានៅខាងលើ
        children: [
          // 🔢 ១. ផ្នែកលេខរាប់លំដាប់ជួរឈរ (1, 2, 3...)
          SizedBox(
            width: 24, // កំណត់ប្រវែងទទឹងថេរ ដើម្បីកុំឱ្យរុញឈ្មោះទំនិញខុសជួរគ្នា
            child: Text(
              "${index + 1}.", // index ចាប់ពី 0 ដូចនេះត្រូវ + 1
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),


          // 📦 ២. ផ្នែកឈ្មោះទំនិញ
          Expanded(
            child: Text(
              item['desc']!.text,
              style: const TextStyle(color: Colors.black),
            ),
          ),


          // 💰 ៣. ផ្នែកចំនួន និងតម្លៃ
          Text(
            "${item['qty']!.text} x ${item['price']!.text} ៛",
            style: const TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }


  Widget _buildCaptureTotalAndQR(double grandTotal) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("សរុបចុងក្រោយ៖", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
            Text(
              "${NumberFormat('#,###').format(grandTotal)} ៛", // ✅ ប្រើ grandTotal
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        if (CreateInvoiceSheet.qrFile != null) ...[
          const SizedBox(height: 20),
          const Center(child: Text("Scan ដើម្បីបង់ប្រាក់", style: TextStyle(fontSize: 12, color: Colors.black))),
          const SizedBox(height: 10),
          Center(child: Image.file(CreateInvoiceSheet.qrFile!, width: 160)),
        ],
      ],
    );
  }
// 🎯 ១. កែមុខងារនេះឱ្យទៅជា double ដើម្បីងាយស្រួល Format ក្បៀស និងយកទៅរក្សាទុកក្នុង Database មិនឱ្យគាំង
  double _calculateGrandTotalAsDouble() {
    double total = CreateInvoiceSheet.items.fold(
      0,
          (sum, item) =>
      sum +
          ((double.tryParse(item['qty']!.text) ?? 0) *
              (double.tryParse(item['price']!.text) ?? 0)),
    );
    return total + (double.tryParse(CreateInvoiceSheet.shipPrice.text) ?? 0);
  }

  // 🎯 ២. រក្សាទុកមុខងារចាស់នេះដដែល ប៉ុន្តែឱ្យវាហៅពី double មក Format ក្បៀសឱ្យស្រេចតែម្តង
  String _calculateGrandTotal() {
    return NumberFormat('#,###').format(_calculateGrandTotalAsDouble());
  }

  String _formatLastSeen(dynamic timestamp) {
    if (timestamp == null) return 'អសកម្ម';
    final time = (timestamp as Timestamp).toDate();
    final diff = DateTime.now().difference(time);


    if (diff.inMinutes < 1) return 'ទើបតែសកម្ម';
    if (diff.inMinutes < 60) return 'សកម្ម ${diff.inMinutes} នាទីមុន';
    if (diff.inHours < 24) return 'សកម្ម ${diff.inHours} ម៉ោងមុន';
    return 'សកម្ម ${diff.inDays} ថ្ងៃមុន';
  }


  void _showMessageOptions(
      BuildContext context,
      Map<String, dynamic> data,
      String docId,
      ) {
    String type = data['type'] ?? 'text';
    bool isMe = data['sender'] == currentUserId;
    bool isHighlighted = _highlightedMessages.contains(docId);


    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),


              // ✅ 1. Copy (text only)
              if (type == 'text')
                _buildOptionTile(
                  icon: Icons.copy,
                  label: 'ចម្លងអក្សរ',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: data['message']));
                    _showSnack('បានចម្លងហើយ', Colors.blue);
                  },
                ),


              // ✅ 2. Highlight
              _buildOptionTile(
                icon: isHighlighted
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                label: isHighlighted ? 'លុប Highlight' : 'Highlight ⭐',
                color: Colors.amber,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (isHighlighted) {
                      _highlightedMessages.remove(docId);
                    } else {
                      _highlightedMessages.add(docId);
                    }
                  });
                  _showSnack(
                    isHighlighted ? 'បានលុប Highlight' : '⭐ បាន Highlight',
                    Colors.amber,
                  );
                },
              ),


              // ✅ 3. លុបសម្រាប់ខ្លួនឯង
              _buildOptionTile(
                icon: Icons.delete_outline,
                label: 'លុបសម្រាប់ខ្លួនឯង',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(
                    docId: docId,
                    fileUrl: data['fileUrl'],
                    type: type,
                    deleteForEveryone: false,
                  );
                },
              ),


              // ✅ 4. លុបសម្រាប់ទាំងអស់គ្នា (isMe only)
              if (isMe)
                _buildOptionTile(
                  icon: Icons.delete_forever,
                  label: 'លុបសម្រាប់ទាំងអស់គ្នា',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteForEveryone(
                      context,
                      docId,
                      data['fileUrl'],
                      type,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontFamily: 'Siemreap',
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }


  void _confirmDeleteForEveryone(
      BuildContext context,
      String docId,
      String? fileUrl,
      String type,
      ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'លុបសម្រាប់ទាំងអស់គ្នា?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Siemreap',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'សារនេះនឹងបាត់ចេញពីទូរស័ព្ទ'
                    'ទាំងអស់គ្នា មិនអាចដកវិញបានទេ។',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontFamily: 'Siemreap',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'បោះបង់',
                        style: TextStyle(fontFamily: 'Siemreap'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteMessage(
                          docId: docId,
                          fileUrl: fileUrl,
                          type: type,
                          deleteForEveryone: true,
                        );
                      },
                      child: const Text(
                        'លុបចេញ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _deleteMessage({
    required String docId,
    required String? fileUrl,
    required String type,
    required bool deleteForEveryone,
  }) async {
    try {
      if (deleteForEveryone) {
        if (fileUrl != null && fileUrl.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(fileUrl).delete();
          } catch (_) {}
        }
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(docId)
            .delete();


        _showSnack('បានលុបសម្រាប់ទាំងអស់គ្នា', Colors.red);
      } else {
        await FirebaseFirestore.instance.collection('chats').doc(docId).update({
          'message': '🚫 សារត្រូវបានលុប',
          'type': 'text',
          'fileUrl': '',
          'deletedFor': FieldValue.arrayUnion([currentUserId]),
        });


        _showSnack('បានលុបចេញ', Colors.orange);
      }
    } catch (e) {
      _showSnack('❌ លុបមិនបាន: $e', Colors.red);
    }
  }


  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'Siemreap',
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);


    // ✅ Format ម៉ោង/នាទី ជាភាសាខ្មែរ
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';


    if (messageDate == today) {
      return 'ថ្ងៃនេះ ម៉ោង $timeStr';
    } else if (messageDate == yesterday) {
      return 'ម្សិលមិញ ម៉ោង $timeStr';
    } else {
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    }
  }
}




