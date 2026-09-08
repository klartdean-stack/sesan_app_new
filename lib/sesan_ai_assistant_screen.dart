import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'ai_packages_screen.dart';

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
  State<SesanAiAssistantScreen> createState() => _SesanAiAssistantScreenState();
}

class _SesanAiAssistantScreenState extends State<SesanAiAssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _sending = false;
  bool _loadingHistory = true;
  String? _initialImageData;
  int? _remainingCredits;

  bool get _en => Localizations.localeOf(context).languageCode == 'en';
  String _t(String km, String en) => _en ? en : km;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialPrompt.trim();
    _loadHistory();
    _loadInitialImage();
  }

  Future<void> _loadInitialImage() async {
    final url = widget.initialImageUrl.trim();
    if (url.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300 || response.bodyBytes.isEmpty || response.bodyBytes.length > 8 * 1024 * 1024) return;
      final type = (response.headers['content-type'] ?? 'image/jpeg').split(';').first;
      _initialImageData = 'data:$type;base64,${base64Encode(response.bodyBytes)}';
    } catch (_) {}
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
          ..addAll(raw.map((e) => Map<String, dynamic>.from(e as Map)));
      });
    } catch (_) {
      // History is optional; new questions can still be sent.
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _messages.add({'role': 'user', 'text': text});
      _controller.clear();
    });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('askFarmAssistant');
      final payload = <String, dynamic>{
        'action': 'ask',
        'message': text,
        'role': widget.initialRole,
      };
      if (_initialImageData != null) {
        payload['imageData'] = _initialImageData;
        _initialImageData = null;
      }
      final result = await callable.call(payload);
      final data = Map<String, dynamic>.from(result.data as Map);
      final answer = (data['answer'] ?? data['message'] ?? '').toString();
      final credits = int.tryParse((data['remainingCredits'] ?? '').toString());
      if (!mounted) return;
      setState(() {
        if (answer.isNotEmpty) _messages.add({'role': 'assistant', 'text': answer});
        if (credits != null) _remainingCredits = credits;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(_scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final exhausted = e.code == 'resource-exhausted' || e.code == 'failed-precondition';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message ?? _t('មិនអាចសួរ AI បាន', 'Could not ask AI')),
        action: exhausted
            ? SnackBarAction(
                label: _t('កញ្ចប់ AI', 'AI plans'),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AiPackagesScreen())),
              )
            : null,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text('Sesan AI Assistant'),
        actions: [
          if (_remainingCredits != null)
            Center(child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('$_remainingCredits Credits', style: const TextStyle(fontSize: 11)),
            )),
          IconButton(
            tooltip: _t('កញ្ចប់ AI', 'AI plans'),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AiPackagesScreen())),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final mine = (m['role'] ?? '') == 'user';
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 340),
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: mine ? Colors.green.shade100 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text((m['text'] ?? '').toString(),
                              style: const TextStyle(fontFamily: 'Siemreap', height: 1.45)),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: _t('សួរ Sesan AI...', 'Ask Sesan AI...'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
