import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:my_app/ai_packages_screen.dart';

class SesanAiAssistantScreen extends StatefulWidget {
  final String initialPrompt;
  final String initialRole;
  final String initialImageUrl;

  const SesanAiAssistantScreen({
    super.key,
    this.initialPrompt = '',
    this.initialRole = 'agriculture',
    this.initialImageUrl = '',
  });

  @override
  State<SesanAiAssistantScreen> createState() =>
      _SesanAiAssistantScreenState();
}

class _SesanAiAssistantScreenState extends State<SesanAiAssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AssistantMessage> _messages = [];
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _voiceTimer;
  Uint8List? _pendingImageBytes;
  String? _pendingImageData;
  Future<void>? _initialProductImageFuture;
  bool _initialProductImageConsumed = false;
  bool _sending = false;
  bool _recording = false;
  bool _loadingHistory = true;
  int? _remainingCredits;
  String _role = 'agriculture';

  bool get _isEnglish =>
      Localizations.localeOf(context).languageCode == 'en';

  String _t(String km, String en) => _isEnglish ? en : km;

  final List<Map<String, String>> _roles = const [
    {'id': 'agriculture', 'km': 'កសិកម្ម', 'en': 'Agriculture'},
    {'id': 'sales', 'km': 'លក់ដូរ', 'en': 'Sales'},
    {'id': 'finance', 'km': 'ហិរញ្ញវត្ថុ', 'en': 'Finance'},
    {'id': 'app_help', 'km': 'របៀបប្រើ App', 'en': 'App Help'},
  ];

  List<String> get _quickQuestions => _role == 'app_help'
      ? [
          _t('តើបង្ហោះទំនិញដោយប្រើ Sesan AI យ៉ាងដូចម្តេច?',
              'How do I list a product using Sesan AI?'),
          _t('តើស្វែងរកទំនិញតាមរូប និងសម្លេងយ៉ាងដូចម្តេច?',
              'How do I search by photo or voice?'),
        ]
      : _role == 'sales'
          ? [
              _t('តើធ្វើដូចម្តេចឱ្យទំនិញកសិកម្មលក់ដាច់?',
                  'How can I sell farm products faster?'),
              _t('ជួយរៀបផែនការលក់ប្រចាំខែ',
                  'Help me create a monthly sales plan'),
            ]
          : _role == 'finance'
              ? [
                  _t('ជួយគណនាដើមទុន និងចំណេញ',
                      'Help estimate costs and profit'),
                  _t('តើត្រូវរៀបចំលុយសម្រាប់រដូវដាំដុះយ៉ាងណា?',
                      'How should I budget for a growing season?'),
                ]
              : [
                  _t('ដំណាំខ្ញុំមានស្លឹកលឿង តើគួរពិនិត្យអ្វីខ្លះ?',
                      'My crop has yellow leaves. What should I check?'),
                  _t('ជួយរៀបផែនការដាំដុះតាមរដូវ',
                      'Help me plan crops for the season'),
                ];

  @override
  void initState() {
    super.initState();
    if (_roles.any((role) => role['id'] == widget.initialRole)) {
      _role = widget.initialRole;
    }
    if (widget.initialPrompt.trim().isNotEmpty) {
      _controller.text = widget.initialPrompt.trim();
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
    _loadHistory();
    _initialProductImageFuture = _loadInitialProductImage();
  }

  Future<void> _loadInitialProductImage() async {
    final url = widget.initialImageUrl.trim();
    if (url.isEmpty) return;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty ||
          response.bodyBytes.length > 8 * 1024 * 1024) {
        return;
      }
      final rawContentType = response.headers['content-type'] ?? 'image/jpeg';
      final mime = rawContentType.split(';').first.trim().toLowerCase();
      final safeMime = <String>{'image/jpeg', 'image/png', 'image/webp'}
              .contains(mime)
          ? mime
          : 'image/jpeg';
      if (!mounted) return;
      setState(() {
        _pendingImageBytes = response.bodyBytes;
        _pendingImageData =
            'data:$safeMime;base64,${base64Encode(response.bodyBytes)}';
      });
    } catch (error) {
      debugPrint('Could not attach product image to Sesan AI: $error');
    }
  }

  Future<void> _loadHistory() async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('askFarmAssistant');
      final result = await callable.call(<String, dynamic>{
        'action': 'history',
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final rawMessages = (data['messages'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(rawMessages.map((raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            return _AssistantMessage(
              id: (item['id'] ?? '').toString(),
              text: (item['text'] ?? '').toString(),
              isUser: item['role'] == 'user',
              feedback: (item['feedback'] ?? '').toString(),
              imageUrl: (item['imageUrl'] ?? '').toString(),
              sources: ((item['sources'] as List?) ?? const [])
                  .map((rawSource) {
                    final source =
                        Map<String, dynamic>.from(rawSource as Map);
                    return _AssistantSource(
                      title: (source['title'] ?? '').toString(),
                      url: (source['url'] ?? '').toString(),
                    );
                  })
                  .where((source) => source.url.isNotEmpty)
                  .toList(),
            );
          }));
      });
      _scrollToBottom();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('លុបប្រវត្តិសន្ទនា?', 'Clear chat history?')),
        content: Text(_t(
          'សារ និងរូបភាពក្នុង Sesan AI Assistant នឹងត្រូវលុប។',
          'Messages and images in Sesan AI Assistant will be deleted.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('បោះបង់', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('លុប', 'Clear')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loadingHistory = true);
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('askFarmAssistant');
      await callable.call(<String, dynamic>{
        'action': 'clear_history',
      });
      if (mounted) setState(() => _messages.clear());
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  @override
  void dispose() {
    _voiceTimer?.cancel();
    _audioRecorder.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _chooseImage() async {
    if (_sending) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
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
          ],
        ),
      ),
    );
    if (source == null) return;
    final image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (image == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: _t('កាត់រូបភាព', 'Crop image'),
          toolbarColor: Colors.green,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: _t('កាត់រូបភាព', 'Crop image'),
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );
    if (cropped == null) return;
    final bytes = await cropped.readAsBytes();
    if (bytes.isEmpty || bytes.length > 4500000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('រូបធំពេក ឬមិនអាចអានបាន', 'Image is too large or unreadable'))),
        );
      }
      return;
    }
    const mime = 'image/jpeg';
    if (mounted) {
      setState(() {
        _pendingImageBytes = bytes;
        _pendingImageData = 'data:$mime;base64,${base64Encode(bytes)}';
      });
    }
  }

  Future<void> _startVoice() async {
    if (_sending || _recording) return;
    if (!await _audioRecorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('សូមអនុញ្ញាត Microphone ជាមុន', 'Please allow microphone access first'))),
        );
      }
      return;
    }
    final String path;
    if (kIsWeb) {
      path = '';
    } else {
      final directory = await getTemporaryDirectory();
      path = '${directory.path}/sesan_assistant_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }
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
    if (!mounted) return;
    setState(() => _recording = true);
    _voiceTimer?.cancel();
    _voiceTimer = Timer(const Duration(seconds: 7), _finishVoice);
  }

  Future<void> _finishVoice() async {
    if (!_recording) return;
    _voiceTimer?.cancel();
    if (mounted) setState(() => _recording = false);
    try {
      final path = await _audioRecorder.stop();
      if (path == null || path.isEmpty) throw StateError('Empty recording');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final bytes = await XFile(path).readAsBytes();
      if (bytes.isEmpty || bytes.length > 7500000) {
        throw StateError('Invalid recording');
      }
      final mime = kIsWeb ? 'audio/wav' : 'audio/m4a';
      await _send(
        audioData: 'data:$mime;base64,${base64Encode(bytes)}',
        displayText: _t('🎤 សារជាសម្លេង', '🎤 Voice message'),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('មិនអាចអានសម្លេងនេះបានទេ', 'Could not read this recording'))),
        );
      }
    }
  }

  Future<void> _send({
    String? preset,
    String? imageData,
    String? audioData,
    String? displayText,
  }) async {
    if (!_initialProductImageConsumed &&
        imageData == null &&
        widget.initialImageUrl.trim().isNotEmpty) {
      await _initialProductImageFuture;
    }
    _initialProductImageConsumed = true;

    final text = (preset ?? _controller.text).trim();
    final attachedImage = imageData ?? _pendingImageData;
    final attachedImageBytes = _pendingImageBytes;
    if ((text.isEmpty && attachedImage == null && audioData == null) || _sending) return;
    final shownText = displayText ??
        (text.isNotEmpty
            ? text
            : attachedImage != null
                ? _t('📷 សូមពិនិត្យរូបនេះ', '📷 Please check this image')
                : _t('🎤 សារជាសម្លេង', '🎤 Voice message'));
    final history = _messages
        .takeLast(12)
        .map((item) => {'role': item.isUser ? 'user' : 'assistant', 'content': item.text})
        .toList();
    late int sentMessageIndex;
    setState(() {
      sentMessageIndex = _messages.length;
      _messages.add(_AssistantMessage(
        text: shownText,
        isUser: true,
        imageBytes: attachedImageBytes,
      ));
      _sending = true;
      _controller.clear();
      _pendingImageBytes = null;
      _pendingImageData = null;
    });
    _scrollToBottom();
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('askFarmAssistant');
      final result = await callable.call({
        'message': text,
        'role': _role,
        'locale': _isEnglish ? 'en' : 'km',
        'history': history,
        if (attachedImage != null) 'image': attachedImage,
        if (audioData != null) 'audio': audioData,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final answer = (data['answer'] ?? '').toString().trim();
      final messageId = (data['messageId'] ?? '').toString();
      final sources = ((data['sources'] as List?) ?? const [])
          .map((rawSource) {
            final source = Map<String, dynamic>.from(rawSource as Map);
            return _AssistantSource(
              title: (source['title'] ?? '').toString(),
              url: (source['url'] ?? '').toString(),
            );
          })
          .where((source) => source.url.isNotEmpty)
          .toList();
      final transcript = (data['transcript'] ?? '').toString().trim();
      final remaining = int.tryParse((data['remainingCredits'] ?? '').toString());
      if (answer.isEmpty) throw StateError('Empty answer');
      if (mounted) {
        setState(() {
          if (transcript.isNotEmpty && sentMessageIndex < _messages.length) {
            _messages[sentMessageIndex] = _AssistantMessage(
              text: '🎤 $transcript',
              isUser: true,
            );
          }
          _remainingCredits = remaining ?? _remainingCredits;
          _messages.add(_AssistantMessage(
            id: messageId,
            text: answer,
            isUser: false,
            sources: sources,
          ));
        });
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(() => _messages.add(_AssistantMessage(
              text: error.message ??
                  _t('មិនអាចឆ្លើយបាននៅពេលនេះ សូមសាកម្តងទៀត។',
                      'Unable to answer right now. Please try again.'),
              isUser: false,
              isError: true,
            )));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _messages.add(_AssistantMessage(
              text: _t('មានបញ្ហាបណ្តាញ សូមសាកម្តងទៀត។',
                  'Network problem. Please try again.'),
              isUser: false,
              isError: true,
            )));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _submitFeedback(int index, String rating) async {
    if (index < 0 || index >= _messages.length) return;
    final item = _messages[index];
    if (item.id.isEmpty || item.isUser || item.feedback == rating) return;

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('askFarmAssistant');
      await callable.call(<String, dynamic>{
        'action': 'submit_feedback',
        'messageId': item.id,
        'rating': rating,
      });
      if (!mounted) return;
      setState(() {
        _messages[index] = _AssistantMessage(
          id: item.id,
          text: item.text,
          isUser: item.isUser,
          isError: item.isError,
          imageBytes: item.imageBytes,
          imageUrl: item.imageUrl,
          sources: item.sources,
          feedback: rating,
        );
      });
      final message = rating == 'helpful'
          ? _t('អរគុណសម្រាប់មតិយោបល់', 'Thanks for your feedback')
          : rating == 'reported'
              ? _t('បានផ្ញើរបាយការណ៍ទៅ Admin', 'Report sent to Admin')
              : _t('បានកត់ត្រាចម្លើយមិនត្រឹមត្រូវ', 'Incorrect answer recorded');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? _t(
            'មិនអាចរក្សាមតិយោបល់បាន',
            'Could not save feedback',
          )),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AiPackagesScreen(),
              ),
            ),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
          IconButton(
            tooltip: _t('លុបប្រវត្តិសន្ទនា', 'Clear chat history'),
            onPressed: _messages.isEmpty ? null : _clearHistory,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildRoleSelector(),
            Expanded(
              child: _loadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? _buildWelcome()
                      : _buildMessages(),
            ),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: Colors.green.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_remainingCredits != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _t('AI Credit នៅសល់៖ $_remainingCredits',
                    'AI credits remaining: $_remainingCredits'),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Siemreap',
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: _roles.map((role) {
              final selected = _role == role['id'];
              return ChoiceChip(
                selected: selected,
                label: Text(_isEnglish ? role['en']! : role['km']!),
                onSelected: (_) => setState(() => _role = role['id']!),
                selectedColor: Colors.green.shade600,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.green.shade900,
                  fontFamily: 'Siemreap',
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        CircleAvatar(
          radius: 38,
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.auto_awesome, size: 38, color: Colors.green.shade700),
        ),
        const SizedBox(height: 16),
        Text(
          _t('សួរខ្ញុំអំពីកសិកម្ម និងអាជីវកម្ម',
              'Ask about farming and agribusiness'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Siemreap',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _t('ប្រាប់ទីតាំង ប្រភេទដំណាំ ឬសត្វ ដំណាក់កាល និងបញ្ហាដែលកំពុងជួប ដើម្បីទទួលបានចម្លើយកាន់តែត្រឹមត្រូវ។',
              'Share your location, crop or animal, growth stage, and problem for a more useful answer.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, height: 1.5, fontFamily: 'Siemreap'),
        ),
        const SizedBox(height: 22),
        ..._quickQuestions.map((question) => Card(
              child: ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                title: Text(question, style: const TextStyle(fontFamily: 'Siemreap', fontSize: 13)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => _send(preset: question),
              ),
            )),
        const SizedBox(height: 12),
        Text(
          _t('ចម្លើយ AI គឺជាព័ត៌មានជំនួយ។ សូមពិនិត្យស្លាកថ្នាំ អ្នកជំនាញមូលដ្ឋាន និងលក្ខខណ្ឌជាក់ស្តែងមុនអនុវត្ត។',
              'AI answers are guidance. Check product labels, local experts, and actual conditions before acting.'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: 'Siemreap'),
        ),
      ],
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final item = _messages[index];
        return Align(
          alignment: item.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: item.isUser
                  ? Colors.green.shade600
                  : item.isError
                      ? Colors.red.shade50
                      : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.imageBytes != null || item.imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item.imageBytes != null
                        ? Image.memory(
                            item.imageBytes!,
                            width: 220,
                            height: 180,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            item.imageUrl,
                            width: 220,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 220,
                              height: 80,
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                ],
                SelectableText(
                  item.text.replaceAll('**', ''),
                  style: TextStyle(
                    color: item.isUser ? Colors.white : Colors.black87,
                    height: 1.5,
                    fontFamily: 'Siemreap',
                    fontSize: 13,
                  ),
                ),
                if (!item.isUser && item.sources.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: List.generate(item.sources.length, (index) {
                      final source = item.sources[index];
                      return OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(source.url);
                          if (uri != null) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.menu_book_outlined, size: 15),
                        label: Text(
                          _t('ប្រភព ${index + 1}', 'Source ${index + 1}'),
                          style: const TextStyle(
                            fontFamily: 'Siemreap',
                            fontSize: 11,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
                if (!item.isUser && !item.isError && item.id.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _t('មានប្រយោជន៍', 'Helpful'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _submitFeedback(index, 'helpful'),
                        icon: Icon(
                          item.feedback == 'helpful'
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          size: 18,
                          color: item.feedback == 'helpful'
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                      IconButton(
                        tooltip: _t('មិនត្រឹមត្រូវ', 'Not correct'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _submitFeedback(index, 'not_helpful'),
                        icon: Icon(
                          item.feedback == 'not_helpful'
                              ? Icons.thumb_down
                              : Icons.thumb_down_outlined,
                          size: 18,
                          color: item.feedback == 'not_helpful'
                              ? Colors.orange.shade800
                              : Colors.grey.shade600,
                        ),
                      ),
                      IconButton(
                        tooltip: _t('រាយការណ៍', 'Report'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _submitFeedback(index, 'reported'),
                        icon: Icon(
                          item.feedback == 'reported'
                              ? Icons.flag
                              : Icons.flag_outlined,
                          size: 18,
                          color: item.feedback == 'reported'
                              ? Colors.red.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingImageBytes != null)
            Container(
              height: 78,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(_pendingImageBytes!, width: 68, height: 68, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: -8,
                      top: -8,
                      child: InkWell(
                        onTap: () => setState(() {
                          _pendingImageBytes = null;
                          _pendingImageData = null;
                        }),
                        child: const CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_recording)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic, color: Colors.red, size: 18),
                  const SizedBox(width: 6),
                  Text(_t('កំពុងស្តាប់... វានឹងឈប់ដោយស្វ័យប្រវត្តិ',
                      'Listening... stops automatically')),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 9),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _sending ? null : _chooseImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    color: Colors.green.shade700,
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _sending ? null : (_recording ? _finishVoice : _startVoice),
                    icon: Icon(_recording ? Icons.stop_circle : Icons.mic_none_rounded),
                    color: _recording ? Colors.red : Colors.green.shade700,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _t('សរសេរសំណួរ...', 'Write a question...'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _sending ? null : () => _send(),
                    icon: const Icon(Icons.send_rounded),
                    color: Colors.green.shade700,
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

class _AssistantMessage {
  final String id;
  final String text;
  final bool isUser;
  final bool isError;
  final Uint8List? imageBytes;
  final String imageUrl;
  final List<_AssistantSource> sources;
  final String feedback;

  const _AssistantMessage({
    this.id = '',
    required this.text,
    required this.isUser,
    this.isError = false,
    this.imageBytes,
    this.imageUrl = '',
    this.sources = const [],
    this.feedback = '',
  });
}

class _AssistantSource {
  final String title;
  final String url;

  const _AssistantSource({
    required this.title,
    required this.url,
  });
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final values = toList();
    return values.skip(values.length > count ? values.length - count : 0);
  }
}
