import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Android V51-compatible AI search controller used by the iOS product list.
class ProductSearchV51Controller {
  ProductSearchV51Controller(this.context);

  final BuildContext context;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _voiceTimer;
  bool busy = false;
  bool recording = false;

  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  void _message(String text, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  bool _signedIn() {
    if (FirebaseAuth.instance.currentUser?.uid.isNotEmpty == true) return true;
    _message(_t(
      'សូមចូលគណនីជាមុន ដើម្បីស្វែងរកតាមរូប ឬសម្លេង',
      'Please sign in to search with a photo or voice',
    ));
    return false;
  }

  Future<Map<String, dynamic>> _analyze({String? image, String? audio}) async {
    final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('analyzeProductSearch');
    final result = await callable.call(<String, dynamic>{
      'locale': Localizations.localeOf(context).languageCode,
      if (image != null) 'image': image,
      if (audio != null) 'audio': audio,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  String _combined(Map<String, dynamic> data) {
    final query = (data['query'] ?? '').toString().trim();
    if (query.isEmpty) throw StateError('Empty AI search query');
    final keywords = (data['keywords'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    return <String>{query, ...keywords}.join(' | ');
  }

  Future<String?> searchByImage() async {
    if (busy || !_signedIn()) return null;
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 72,
    );
    if (image == null) return null;
    busy = true;
    try {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.length > 3300000) {
        throw StateError('Image is too large');
      }
      final mime = image.mimeType == 'image/png' || image.mimeType == 'image/webp'
          ? image.mimeType!
          : 'image/jpeg';
      final data = await _analyze(image: 'data:$mime;base64,${base64Encode(bytes)}');
      final result = _combined(data);
      _message(_t('ស្វែងរកតាមរូបបានសម្រេច', 'Image search ready'), color: Colors.green);
      return result;
    } on FirebaseFunctionsException catch (e) {
      _message(e.message ?? _t('មិនអាចស្វែងរកតាមរូបបានទេ', 'Image search failed'));
      return null;
    } catch (e) {
      debugPrint('Product image search: $e');
      _message(_t('រូបធំពេក ឬមិនអាចអានបាន', 'The image is too large or unreadable'));
      return null;
    } finally {
      busy = false;
    }
  }

  Future<void> startVoice({required Future<void> Function(String query) onResult}) async {
    if (busy || recording || !_signedIn()) return;
    if (!await _audioRecorder.hasPermission()) {
      _message(_t('សូមអនុញ្ញាត Microphone ជាមុន', 'Please allow microphone access first'));
      return;
    }
    final path = kIsWeb
        ? ''
        : '${(await getTemporaryDirectory()).path}/sesan_product_search_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(
      RecordConfig(
        encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
        bitRate: 48000,
        sampleRate: 22050,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      ),
      path: path,
    );
    recording = true;
    _voiceTimer?.cancel();
    _voiceTimer = Timer(const Duration(seconds: 5), () => finishVoice(onResult: onResult));
  }

  Future<void> finishVoice({required Future<void> Function(String query) onResult}) async {
    if (!recording) return;
    _voiceTimer?.cancel();
    recording = false;
    busy = true;
    try {
      final path = await _audioRecorder.stop();
      if (path == null || path.isEmpty) throw StateError('Empty recording');
      Uint8List? bytes;
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration(milliseconds: i == 0 ? 250 : 400));
        try {
          final candidate = await XFile(path).readAsBytes();
          if (candidate.isNotEmpty) { bytes = candidate; break; }
        } catch (_) {}
      }
      if (bytes == null || bytes.isEmpty || bytes.length > 7500000) {
        throw StateError('Audio unreadable');
      }
      final mime = kIsWeb ? 'audio/wav' : 'audio/m4a';
      final data = await _analyze(audio: 'data:$mime;base64,${base64Encode(bytes)}');
      await onResult(_combined(data));
    } on FirebaseFunctionsException catch (e) {
      _message(e.message ?? _t('មិនអាចយល់សម្លេងនេះបានទេ', 'Could not understand this recording'));
    } catch (e) {
      debugPrint('Product voice search: $e');
      _message(_t('ការស្វែងរកតាមសម្លេងបរាជ័យ', 'Voice search failed'));
    } finally {
      busy = false;
    }
  }

  Future<void> dispose() async {
    _voiceTimer?.cancel();
    await _audioRecorder.dispose();
  }
}
