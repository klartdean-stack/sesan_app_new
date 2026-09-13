import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_ai_purchase_history_screen.dart';

class AdminAiDashboardScreen extends StatefulWidget {
  const AdminAiDashboardScreen({super.key});

  @override
  State<AdminAiDashboardScreen> createState() => _AdminAiDashboardScreenState();
}

class _AdminAiDashboardScreenState extends State<AdminAiDashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _totals = const {};
  List<Map<String, dynamic>> _feedback = const [];
  List<Map<String, dynamic>> _subscriptionRequests = const [];

  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('askFarmAssistant');
      final result = await callable.call(<String, dynamic>{'action': 'admin_dashboard'});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      setState(() {
        _totals = Map<String, dynamic>.from((data['totals'] as Map?) ?? const {});
        _feedback = ((data['feedback'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _subscriptionRequests = ((data['subscriptionRequests'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? _t('មិនអាចទាញទិន្នន័យ AI បាន', 'Could not load AI data'));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reviewSubscription(Map<String, dynamic> item, String decision) async {
    final approved = decision == 'approved';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t(approved ? 'អនុម័តកញ្ចប់នេះ?' : 'បដិសេធសំណើនេះ?', approved ? 'Approve this package?' : 'Reject this request?')),
        content: Text('${(item['name'] ?? item['phone'] ?? '').toString()} · ${(item['plan'] ?? '').toString().toUpperCase()}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('បោះបង់', 'Cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: approved ? Colors.green : Colors.red),
            child: Text(_t(approved ? 'អនុម័ត' : 'បដិសេធ', approved ? 'Approve' : 'Reject')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('askFarmAssistant');
      await callable.call(<String, dynamic>{
        'action': 'admin_subscription_action',
        'userId': (item['userId'] ?? '').toString(),
        'decision': decision,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(approved ? 'បានបើកកញ្ចប់ជោគជ័យ' : 'បានបដិសេធសំណើ', approved ? 'Package activated' : 'Request rejected')),
        backgroundColor: approved ? Colors.green : Colors.orange,
      ));
      await _load();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Request failed'), backgroundColor: Colors.red));
    }
  }

  Future<void> _openReceipt(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('មិនអាចបើកវិក្កយបត្រ', 'Could not open receipt'))));
    }
  }

  int _number(String key) => int.tryParse((_totals[key] ?? 0).toString()) ?? 0;

  String _timeText(dynamic value) {
    final ms = int.tryParse((value ?? 0).toString()) ?? 0;
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Color _ratingColor(String rating) => rating == 'helpful'
      ? Colors.green : rating == 'reported' ? Colors.red : rating == 'not_helpful' ? Colors.orange : Colors.grey;

  String _ratingLabel(String rating) => rating == 'helpful'
      ? _t('មានប្រយោជន៍', 'Helpful')
      : rating == 'reported' ? _t('បានរាយការណ៍', 'Reported')
      : rating == 'not_helpful' ? _t('មិនត្រឹមត្រូវ', 'Not correct') : rating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF3),
      appBar: AppBar(
        title: Text(_t('គ្រប់គ្រង Sesan AI', 'Sesan AI Dashboard')),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _t('ប្រវត្តិអ្នកទិញ AI', 'AI purchase history'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAiPurchaseHistoryScreen())),
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: FilledButton(onPressed: _load, child: Text(_error!)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      Text(_t('ការប្រើប្រាស់ថ្ងៃនេះ', "Today's usage"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 4 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.65,
                        mainAxisSpacing: 9,
                        crossAxisSpacing: 9,
                        children: [
                          _statCard(_t('អ្នកប្រើ AI', 'AI users'), _number('activeUsers'), Icons.people_alt_outlined, Colors.blue),
                          _statCard(_t('Credit បានប្រើ', 'Credits used'), _number('credits'), Icons.bolt_outlined, Colors.amber.shade800),
                          _statCard('Text', _number('text'), Icons.chat_bubble_outline, Colors.green),
                          _statCard('Voice', _number('voice'), Icons.mic_none_rounded, Colors.purple),
                          _statCard('Image', _number('image'), Icons.image_outlined, Colors.teal),
                          _statCard(_t('ឯកសារក្រសួង', 'Ministry research'), _number('ministryResearch'), Icons.menu_book_outlined, Colors.indigo),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(_t('សំណើជាវកញ្ចប់ AI', 'AI subscription requests'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 9),
                      if (_subscriptionRequests.isEmpty)
                        Card(child: Padding(padding: const EdgeInsets.all(18), child: Center(child: Text(_t('មិនទាន់មានសំណើថ្មី', 'No pending requests')))))
                      else
                        ..._subscriptionRequests.map(_subscriptionCard),
                      const SizedBox(height: 20),
                      Text(_t('មតិយោបល់', 'Feedback'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 9),
                      Row(children: [
                        Expanded(child: _feedbackSummary(_t('ល្អ', 'Helpful'), _number('helpful'), Colors.green)),
                        const SizedBox(width: 7),
                        Expanded(child: _feedbackSummary(_t('ខុស', 'Incorrect'), _number('notHelpful'), Colors.orange)),
                        const SizedBox(width: 7),
                        Expanded(child: _feedbackSummary(_t('រាយការណ៍', 'Reported'), _number('reported'), Colors.red)),
                      ]),
                      const SizedBox(height: 14),
                      if (_feedback.isEmpty)
                        Card(child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(_t('មិនទាន់មានមតិយោបល់', 'No feedback yet')))))
                      else
                        ..._feedback.map(_feedbackCard),
                    ],
                  ),
                ),
    );
  }

  Widget _statCard(String title, int value, IconData icon, Color color) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(11),
      child: Row(children: [
        CircleAvatar(backgroundColor: color.withOpacity(0.11), child: Icon(icon, color: color, size: 19)),
        const SizedBox(width: 9),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Color(0xFF626762))),
        ])),
      ]),
    ),
  );

  Widget _feedbackSummary(String title, int value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text('$value', style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800)),
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
    ]),
  );

  Widget _subscriptionCard(Map<String, dynamic> item) {
    final plan = (item['plan'] ?? '').toString().toUpperCase();
    final credits = int.tryParse((item['credits'] ?? 0).toString()) ?? 0;
    final price = int.tryParse((item['price'] ?? 0).toString()) ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(child: Icon(Icons.workspace_premium_outlined)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((item['name'] ?? item['phone'] ?? 'User').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('$plan · $credits credits · $price ៛', style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w700, fontSize: 12)),
            ])),
            Text(_timeText(item['submittedAtMs']), style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
          ]),
          const SizedBox(height: 8),
          Text('Phone: ${(item['phone'] ?? '').toString()}   Sesan ID: ${(item['sesanId'] ?? '').toString()}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => _openReceipt((item['receiptUrl'] ?? '').toString()),
            icon: const Icon(Icons.receipt_long_outlined, size: 17),
            label: Text(_t('មើលវិក្កយបត្រ', 'View receipt')),
          )),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _reviewSubscription(item, 'rejected'), icon: const Icon(Icons.close_rounded), label: Text(_t('បដិសេធ', 'Reject')))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(onPressed: () => _reviewSubscription(item, 'approved'), icon: const Icon(Icons.check_rounded), label: Text(_t('អនុម័ត', 'Approve')))),
          ]),
        ]),
      ),
    );
  }

  Widget _feedbackCard(Map<String, dynamic> item) {
    final rating = (item['rating'] ?? '').toString();
    final color = _ratingColor(rating);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(rating == 'helpful' ? Icons.thumb_up_outlined : rating == 'not_helpful' ? Icons.thumb_down_outlined : Icons.flag_outlined, color: color, size: 18),
            const SizedBox(width: 7),
            Expanded(child: Text(_ratingLabel(rating), style: TextStyle(color: color, fontWeight: FontWeight.w700))),
            Text(_timeText(item['createdAtMs']), style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
          ]),
          const SizedBox(height: 7),
          Text((item['answerPreview'] ?? '').toString(), maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.45)),
          const SizedBox(height: 5),
          Text('UID: ${(item['uid'] ?? '').toString()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
        ]),
      ),
    );
  }
}
