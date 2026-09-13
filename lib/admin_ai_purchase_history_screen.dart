import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminAiPurchaseHistoryScreen extends StatefulWidget {
  const AdminAiPurchaseHistoryScreen({super.key});

  @override
  State<AdminAiPurchaseHistoryScreen> createState() =>
      _AdminAiPurchaseHistoryScreenState();
}

class _AdminAiPurchaseHistoryScreenState
    extends State<AdminAiPurchaseHistoryScreen> {
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  List<Map<String, dynamic>> _purchases = const [];

  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('askFarmAssistant');
      final result = await callable.call(<String, dynamic>{
        'action': 'admin_subscription_history',
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final purchases = ((data['purchases'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return;
      setState(() => _purchases = purchases);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _error =
          error.message ?? _t('មិនអាចទាញប្រវត្តិបាន', 'Could not load history'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visiblePurchases {
    if (_filter == 'all') return _purchases;
    return _purchases
        .where((item) => (item['status'] ?? '').toString() == _filter)
        .toList();
  }

  int _count(String status) => _purchases
      .where((item) => (item['status'] ?? '').toString() == status)
      .length;

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return _t('បានអនុម័ត', 'Approved');
      case 'rejected':
        return _t('បានបដិសេធ', 'Rejected');
      default:
        return _t('កំពុងរង់ចាំ', 'Pending');
    }
  }

  String _date(dynamic value) {
    final ms = int.tryParse((value ?? 0).toString()) ?? 0;
    if (ms <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _price(dynamic value) {
    final number = int.tryParse((value ?? 0).toString()) ?? 0;
    final text = number.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return '${buffer.toString()} ៛';
  }

  Future<void> _openReceipt(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            'មិនអាចបើកវិក្កយបត្របាន',
            'Could not open the receipt',
          )),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF3),
      appBar: AppBar(
        title: Text(_t('ប្រវត្តិអ្នកទិញ AI', 'AI Purchase History')),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _t('ផ្ទុកឡើងវិញ', 'Refresh'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_error!),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      _summary(),
                      const SizedBox(height: 12),
                      _filters(),
                      const SizedBox(height: 12),
                      if (_visiblePurchases.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 70),
                          child: Center(
                            child: Text(
                              _t(
                                'មិនទាន់មានប្រវត្តិទិញកញ្ចប់',
                                'No AI package purchases yet',
                              ),
                              style: const TextStyle(
                                fontFamily: 'Siemreap',
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._visiblePurchases.map(_purchaseCard),
                    ],
                  ),
                ),
    );
  }

  Widget _summary() {
    return Row(
      children: [
        Expanded(child: _summaryItem(_t('ទាំងអស់', 'All'), _purchases.length, Colors.blue)),
        const SizedBox(width: 7),
        Expanded(child: _summaryItem(_t('បានទិញ', 'Approved'), _count('approved'), Colors.green)),
        const SizedBox(width: 7),
        Expanded(child: _summaryItem(_t('បដិសេធ', 'Rejected'), _count('rejected'), Colors.red)),
      ],
    );
  }

  Widget _summaryItem(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text('$value', style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w800)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Siemreap', fontSize: 10)),
        ],
      ),
    );
  }

  Widget _filters() {
    final items = <String, String>{
      'all': _t('ទាំងអស់', 'All'),
      'approved': _t('បានទិញ', 'Approved'),
      'pending': _t('រង់ចាំ', 'Pending'),
      'rejected': _t('បដិសេធ', 'Rejected'),
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.entries.map((entry) {
          final selected = _filter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              selected: selected,
              label: Text(entry.value,
                  style: const TextStyle(fontFamily: 'Siemreap', fontSize: 11)),
              onSelected: (_) => setState(() => _filter = entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _purchaseCard(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'pending').toString();
    final color = _statusColor(status);
    final name = (item['name'] ?? '').toString().trim();
    final phone = (item['phone'] ?? '').toString().trim();
    final plan = (item['plan'] ?? '').toString().toUpperCase();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.10),
                  child: Icon(Icons.workspace_premium_outlined, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? (phone.isEmpty ? 'User' : phone) : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$plan · ${item['credits'] ?? 0} Credits · ${_price(item['price'])}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
                  child: Text(_statusLabel(status),
                      style: TextStyle(color: color, fontFamily: 'Siemreap', fontWeight: FontWeight.w700, fontSize: 9.5)),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text('Phone: $phone · Sesan ID: ${item['sesanId'] ?? ''}',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
            Text('${_t('បានស្នើ', 'Requested')}: ${_date(item['submittedAtMs'])}',
                style: const TextStyle(fontFamily: 'Siemreap', fontSize: 10, color: Colors.black54)),
            if ((item['reviewedAtMs'] ?? 0).toString() != '0')
              Text('${_t('បានពិនិត្យ', 'Reviewed')}: ${_date(item['reviewedAtMs'])}',
                  style: const TextStyle(fontFamily: 'Siemreap', fontSize: 10, color: Colors.black54)),
            if ((item['receiptUrl'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openReceipt((item['receiptUrl'] ?? '').toString()),
                  icon: const Icon(Icons.receipt_long_outlined, size: 17),
                  label: Text(_t('មើលវិក្កយបត្រ', 'View receipt'),
                      style: const TextStyle(fontFamily: 'Siemreap', fontSize: 11)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
