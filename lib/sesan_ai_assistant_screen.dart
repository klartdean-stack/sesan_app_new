import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ai_packages_screen.dart';

class SesanAiAssistantScreen extends StatefulWidget {
  const SesanAiAssistantScreen({
    super.key,
    this.initialPrompt = '',
    this.initialRole = 'agriculture',
    this.initialImageUrl = '',
  });

  final String initialPrompt;
  final String initialRole;
  final String initialImageUrl;

  @override
  State<SesanAiAssistantScreen> createState() => _SesanAiAssistantScreenState();
}

class _SesanAiAssistantScreenState extends State<SesanAiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final Record _recorder = Record();
  final List<_AiMessage> _messages = [];

  Timer? _recordTimer;
  bool _loadingHistory = true;
  bool _sending = false;
  bool _recording = false;
  String _role = 'agriculture';
  Uint8List? _pendingImageBytes;
  String? _pendingImageData;
  int? _remainingCredits;

  bool get _english => Localizations.localeOf(context).languageCode == 'en';
  String _t(String km, String en) => _english ? en : km;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    _controller.text = widget.initialPrompt.trim();
    _loadHistory();
    _loadInitialImage();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialImage() async {
    final url = widget.initialImageUrl.trim();
    if (url.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300 || response.bodyBytes.isEmpty) return;
      final type = (response.headers['content-type'] ?? 'image/jpeg').split(';').first;
      if (!mounted) return;
      setState(() {
        _pendingImageBytes = response.bodyBytes;
        _pendingImageData = 'data:$type;base64,${base64Encode(response.bodyBytes)}';
      });
    } catch (e) {
      debugPrint('AI initial image error: $e');
    }
  }

  Future<void> _loadHistory() async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('askFarmAssistant');
      final result = await callable.call(<String, dynamic>{'action': 'history'});
      final data = Map<String, dynamic>.from(result.data as Map);
      final raw = (data['messages'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(raw.map((value) {
            final item = Map<String, dynamic>.from(value as Map);
            return _AiMessage(
              id: (item['id'] ?? '').toString(),
              text: (item['text'] ?? '').toString(),
              user: item['role'] == 'user',
              feedback: (item['feedback'] ?? '').toString(),
              imageUrl: (item['imageUrl'] ?? '').toString(),
              sources: ((item['sources'] as List?) ?? const [])
                  .map((s) => Map<String, dynamic>.from(s as Map))
                  .map((s) => _AiSource(
                        title: (s['title'] ?? '').toString(),
                        url: (s['url'] ?? '').toString(),
                      ))
                  .where((s) => s.url.isNotEmpty)
                  .toList(),
            );
          }));
      });
      _scrollBottom();
    } catch (e) {
      debugPrint('AI history error: $e');
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t('លុបប្រវត្តិសន្ទនា?', 'Clear chat history?')),
        content: Text(_t('សារ Sesan AI ទាំងអស់នឹងត្រូវលុប។', 'All Sesan AI messages will be deleted.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('បោះបង់', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(_t('លុប', 'Clear'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('askFarmAssistant');
      await callable.call(<String, dynamic>{'action': 'clear_history'});
      if (mounted) setState(_messages.clear);
    } catch (e) {
      _snack(_t('មិនអាចលុបប្រវត្តិបាន', 'Could not clear history'), error: true);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(_t('ជ្រើសពី Gallery', 'Choose from gallery')),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: Text(_t('ថតរូបថ្មី', 'Take a photo')),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 90, maxWidth: 2048, maxHeight: 2048);
    if (picked == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: _t('កាត់រូបភាព', 'Crop image'), toolbarColor: Colors.green, toolbarWidgetColor: Colors.white),
        IOSUiSettings(title: _t('កាត់រូបភាព', 'Crop image')),
      ],
    );
    if (cropped == null) return;
    final bytes = await cropped.readAsBytes();
    if (bytes.isEmpty || bytes.length > 4500000) {
      _snack(_t('រូបធំពេក', 'Image is too large'), error: true);
      return;
    }
    if (mounted) {
      setState(() {
        _pendingImageBytes = bytes;
        _pendingImageData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    }
  }

  Future<void> _startVoice() async {
    if (_sending || _recording || kIsWeb) return;
    if (!await _recorder.hasPermission()) {
      _snack(_t('សូមអនុញ្ញាត Microphone ជាមុន', 'Please allow microphone access first'), error: true);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/sesan_ai_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      path: path,
      encoder: AudioEncoder.aacLc,
      bitRate: 48000,
      samplingRate: 22050,
    );
    if (!mounted) return;
    setState(() => _recording = true);
    _recordTimer?.cancel();
    _recordTimer = Timer(const Duration(seconds: 7), _finishVoice);
  }

  Future<void> _finishVoice() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    if (mounted) setState(() => _recording = false);
    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) return;
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty || bytes.length > 7500000) return;
      await _send(
        audioData: 'data:audio/m4a;base64,${base64Encode(bytes)}',
        displayText: _t('🎤 សារជាសម្លេង', '🎤 Voice message'),
      );
    } catch (e) {
      _snack(_t('មិនអាចអានសម្លេងនេះបានទេ', 'Could not read this recording'), error: true);
    }
  }

  Future<void> _send({String? preset, String? audioData, String? displayText}) async {
    if (_sending) return;
    final text = (preset ?? _controller.text).trim();
    final image = _pendingImageData;
    if (text.isEmpty && image == null && audioData == null) return;

    final shown = displayText ?? (text.isNotEmpty ? text : _t('📷 សូមពិនិត្យរូបនេះ', '📷 Please check this image'));
    final imageBytes = _pendingImageBytes;
    final history = _messages.length <= 12 ? _messages : _messages.sublist(_messages.length - 12);

    setState(() {
      _messages.add(_AiMessage(text: shown, user: true, imageBytes: imageBytes));
      _controller.clear();
      _pendingImageBytes = null;
      _pendingImageData = null;
      _sending = true;
    });
    _scrollBottom();

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('askFarmAssistant');
      final result = await callable.call(<String, dynamic>{
        'message': text,
        'role': _role,
        'locale': _english ? 'en' : 'km',
        'history': history
            .map((m) => {'role': m.user ? 'user' : 'assistant', 'content': m.text})
            .toList(),
        if (image != null) 'image': image,
        if (audioData != null) 'audio': audioData,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final answer = (data['answer'] ?? '').toString().trim();
      if (answer.isEmpty) throw StateError('Empty answer');
      final sources = ((data['sources'] as List?) ?? const [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .map((s) => _AiSource(title: (s['title'] ?? '').toString(), url: (s['url'] ?? '').toString()))
          .where((s) => s.url.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _remainingCredits = int.tryParse((data['remainingCredits'] ?? '').toString()) ?? _remainingCredits;
        _messages.add(_AiMessage(
          id: (data['messageId'] ?? '').toString(),
          text: answer,
          user: false,
          sources: sources,
        ));
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _messages.add(_AiMessage(text: e.message ?? _t('មិនអាចឆ្លើយបាននៅពេលនេះ', 'Unable to answer right now'), user: false, error: true)));
    } catch (e) {
      if (mounted) setState(() => _messages.add(_AiMessage(text: _t('មានបញ្ហាបណ្តាញ សូមសាកម្ដងទៀត។', 'Network problem. Please try again.'), user: false, error: true)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollBottom();
    }
  }

  Future<void> _feedback(int index, String rating) async {
    final message = _messages[index];
    if (message.id.isEmpty || message.user) return;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('askFarmAssistant');
      await callable.call({'action': 'submit_feedback', 'messageId': message.id, 'rating': rating});
      if (!mounted) return;
      setState(() => _messages[index] = message.copyWith(feedback: rating));
    } catch (e) {
      _snack(_t('មិនអាចរក្សាមតិយោបល់បាន', 'Could not save feedback'), error: true);
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Sesan AI ជំនួយការ', 'Sesan AI Assistant')),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _t('កញ្ចប់ Sesan AI', 'Sesan AI Packages'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiPackagesScreen())),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
          IconButton(
            tooltip: _t('លុបប្រវត្តិសន្ទនា', 'Clear history'),
            onPressed: _messages.isEmpty ? null : _clearHistory,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          _roleBar(),
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _welcome()
                    : _messageList(),
          ),
          _inputBar(),
        ]),
      ),
    );
  }

  Widget _roleBar() {
    final roles = <String, String>{
      'agriculture': _t('កសិកម្ម', 'Agriculture'),
      'sales': _t('លក់ដូរ', 'Sales'),
      'finance': _t('ហិរញ្ញវត្ថុ', 'Finance'),
      'app_help': _t('របៀបប្រើ App', 'App Help'),
    };
    return Container(
      width: double.infinity,
      color: Colors.green.shade50,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_remainingCredits != null)
          Text(_t('AI Credit នៅសល់៖ $_remainingCredits', 'AI credits remaining: $_remainingCredits'),
              style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 6,
          children: roles.entries
              .map((e) => ChoiceChip(
                    selected: _role == e.key,
                    label: Text(e.value, style: const TextStyle(fontSize: 11)),
                    onSelected: (_) => setState(() => _role = e.key),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  Widget _welcome() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 30),
          CircleAvatar(radius: 36, backgroundColor: Colors.green.shade100, child: Icon(Icons.auto_awesome, size: 36, color: Colors.green.shade700)),
          const SizedBox(height: 15),
          Text(_t('សួរខ្ញុំអំពីកសិកម្ម និងអាជីវកម្ម', 'Ask about farming and agribusiness'),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(_t('អាចសរសេរ ផ្ញើរូបភាព ឬសម្លេង ដើម្បីសួរ Sesan AI។', 'You can type, attach an image, or send a voice question to Sesan AI.'),
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
        ],
      );

  Widget _messageList() => ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _messages.length + (_sending ? 1 : 0),
        itemBuilder: (_, index) {
          if (index == _messages.length) {
            return const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
          }
          final m = _messages[index];
          return Align(
            alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: m.user ? Colors.green.shade600 : (m.error ? Colors.red.shade50 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (m.imageBytes != null || m.imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: m.imageBytes != null
                        ? Image.memory(m.imageBytes!, width: 220, height: 170, fit: BoxFit.cover)
                        : Image.network(m.imageUrl, width: 220, height: 170, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 7),
                ],
                SelectableText(m.text.replaceAll('**', ''),
                    style: TextStyle(color: m.user ? Colors.white : Colors.black87, height: 1.45)),
                if (!m.user && m.sources.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: m.sources
                        .map((s) => TextButton.icon(
                              onPressed: () async {
                                final uri = Uri.tryParse(s.url);
                                if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(Icons.menu_book_outlined, size: 14),
                              label: Text(s.title.isEmpty ? _t('ប្រភព', 'Source') : s.title, style: const TextStyle(fontSize: 10)),
                            ))
                        .toList(),
                  ),
                if (!m.user && !m.error && m.id.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(onPressed: () => _feedback(index, 'helpful'), icon: Icon(m.feedback == 'helpful' ? Icons.thumb_up : Icons.thumb_up_outlined, size: 17)),
                    IconButton(onPressed: () => _feedback(index, 'not_helpful'), icon: Icon(m.feedback == 'not_helpful' ? Icons.thumb_down : Icons.thumb_down_outlined, size: 17)),
                    IconButton(onPressed: () => _feedback(index, 'reported'), icon: Icon(m.feedback == 'reported' ? Icons.flag : Icons.flag_outlined, size: 17)),
                  ]),
              ]),
            ),
          );
        },
      );

  Widget _inputBar() => Material(
        elevation: 8,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_pendingImageBytes != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_pendingImageBytes!, width: 68, height: 68, fit: BoxFit.cover)),
                  Positioned(right: 0, top: 0, child: InkWell(onTap: () => setState(() { _pendingImageBytes = null; _pendingImageData = null; }), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)))),
                ]),
              ),
            ),
          if (_recording)
            Padding(padding: const EdgeInsets.only(top: 5), child: Text(_t('🎤 កំពុងស្តាប់...', '🎤 Listening...'), style: const TextStyle(color: Colors.red))),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 7, 4, 9),
            child: Row(children: [
              IconButton(onPressed: _sending ? null : _pickImage, icon: const Icon(Icons.add_photo_alternate_outlined), color: Colors.green),
              IconButton(
                onPressed: _sending || kIsWeb ? null : (_recording ? _finishVoice : _startVoice),
                icon: Icon(_recording ? Icons.stop_circle : Icons.mic_none_rounded),
                color: _recording ? Colors.red : Colors.green,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: _t('សរសេរសំណួរ...', 'Write a question...'),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton(onPressed: _sending ? null : _send, icon: const Icon(Icons.send_rounded), color: Colors.green),
            ]),
          ),
        ]),
      );
}

class _AiMessage {
  const _AiMessage({
    this.id = '',
    required this.text,
    required this.user,
    this.error = false,
    this.imageBytes,
    this.imageUrl = '',
    this.sources = const [],
    this.feedback = '',
  });

  final String id;
  final String text;
  final bool user;
  final bool error;
  final Uint8List? imageBytes;
  final String imageUrl;
  final List<_AiSource> sources;
  final String feedback;

  _AiMessage copyWith({String? feedback}) => _AiMessage(
        id: id,
        text: text,
        user: user,
        error: error,
        imageBytes: imageBytes,
        imageUrl: imageUrl,
        sources: sources,
        feedback: feedback ?? this.feedback,
      );
}

class _AiSource {
  const _AiSource({required this.title, required this.url});
  final String title;
  final String url;
}
