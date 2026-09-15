import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminRefundScreen extends StatefulWidget {
  const AdminRefundScreen({super.key});

  @override
  State<AdminRefundScreen> createState() => _AdminRefundScreenState();
}

class _AdminRefundScreenState extends State<AdminRefundScreen> {
  final _money = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('គ្រប់គ្រង Refund', style: TextStyle(fontFamily: 'Siemreap', fontSize: 16)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('complaints').where('status', whereIn: const ['pending', 'reviewing']).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('មានបញ្ហា៖ ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.toList()..sort((a, b) {
            final ad = (a.data() as Map<String, dynamic>)['time'];
            final bd = (b.data() as Map<String, dynamic>)['time'];
            final am = ad is Timestamp ? ad.millisecondsSinceEpoch : 0;
            final bm = bd is Timestamp ? bd.millisecondsSinceEpoch : 0;
            return bm.compareTo(am);
          });
          if (docs.isEmpty) return const Center(child: Text('មិនមានសំណើ Refund ដែលកំពុងរង់ចាំ', style: TextStyle(fontFamily: 'Siemreap')));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFFFEBEE), child: Icon(Icons.currency_exchange, color: Colors.red)),
                  title: Text(data['product_name']?.toString() ?? 'សំណើ Refund', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold)),
                  subtitle: Text('Order: ${data['order_id'] ?? '-'}\nមូលហេតុ៖ ${data['reason'] ?? '-'}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Siemreap', fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RefundCaseScreen(complaintId: doc.id, complaint: data))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RefundCaseScreen extends StatefulWidget {
  final String complaintId;
  final Map<String, dynamic> complaint;
  const RefundCaseScreen({super.key, required this.complaintId, required this.complaint});

  @override
  State<RefundCaseScreen> createState() => _RefundCaseScreenState();
}

class _RefundCaseScreenState extends State<RefundCaseScreen> {
  final _money = NumberFormat('#,###');
  final _noteController = TextEditingController();
  final Map<int, TextEditingController> _qty = {};
  final Set<int> _selected = {};
  String _liableParty = 'seller';
  bool _busy = false;

  String get _orderId => (widget.complaint['order_id'] ?? widget.complaint['orderId'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.complaint['reason']?.toString() ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final c in _qty.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _process(Map<String, dynamic> order) async {
    if (_selected.isEmpty) { _snack('សូមជ្រើសទំនិញដែលត្រូវ Refund'); return; }
    if (_noteController.text.trim().isEmpty) { _snack('សូមបញ្ចូលមូលហេតុ'); return; }
    final items = (order['items'] as List? ?? const []);
    final choices = <Map<String, dynamic>>[];
    for (final index in _selected) {
      final ordered = ((items[index] as Map?)?['quantity'] as num?)?.toInt() ?? 1;
      final qty = int.tryParse(_qty[index]?.text.trim() ?? '') ?? 0;
      if (qty <= 0 || qty > ordered) { _snack('ចំនួន Refund មិនត្រឹមត្រូវ'); return; }
      choices.add({'index': index, 'refundQty': qty});
    }
    setState(() => _busy = true);
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      final preview = await functions.httpsCallable('secureAdminPreviewRefund').call({'orderId': _orderId, 'items': choices, 'liableParty': _liableParty});
      if (!mounted) return;
      final p = Map<String, dynamic>.from(preview.data as Map);
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ផ្ទៀងផ្ទាត់មុន Refund', style: TextStyle(fontFamily: 'Siemreap')),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _summary('Buyer ទទួល', p['buyerReceives']),
            _summary('សេវារដ្ឋបាល 7%', p['adminFee']),
            _summary('Commission ត្រូវលុប', p['commissionReversed']),
            const SizedBox(height: 10),
            const Text('ប្រតិបត្តិការនេះមិនអាចចុចស្ទួនបានទេ។', style: TextStyle(fontFamily: 'Siemreap', color: Colors.red, fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('បោះបង់')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(dialogContext, true), child: const Text('បញ្ជាក់ និង Refund')),
          ],
        ),
      );
      if (ok != true) return;
      final result = await functions.httpsCallable('secureAdminProcessRefund').call({'orderId': _orderId, 'complaintId': widget.complaintId, 'items': choices, 'liableParty': _liableParty, 'reason': _noteController.text.trim()});
      if (!mounted) return;
      final data = Map<String, dynamic>.from(result.data as Map);
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Refund ជោគជ័យ', style: TextStyle(fontFamily: 'Siemreap')),
        content: Text('បានបង្វិល ${_money.format(data['refundAmount'] ?? 0)}៛ ទៅ Buyer', style: const TextStyle(fontFamily: 'Siemreap')),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('យល់ព្រម'))],
      ));
      if (mounted) Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) { _snack(e.message ?? e.code); }
    catch (e) { _snack('Refund បរាជ័យ៖ $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Widget _summary(String label, dynamic amount) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Siemreap'))), Text('${_money.format(amount ?? 0)}៛', style: const TextStyle(fontWeight: FontWeight.bold))]));
  void _snack(String message) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ពិនិត្យករណី Refund', style: TextStyle(fontFamily: 'Siemreap', fontSize: 16)), backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('orders').doc(_orderId).get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('មានបញ្ហា៖ ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) return const Center(child: Text('រកមិនឃើញ Order'));
          final order = snapshot.data!.data() as Map<String, dynamic>;
          final items = order['items'] as List? ?? const [];
          return ListView(padding: const EdgeInsets.all(12), children: [
            _infoCard(), const SizedBox(height: 12),
            const Text('ជ្រើសទំនិញ និងចំនួនដែលត្រូវ Refund', style: TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold)), const SizedBox(height: 8),
            ...List.generate(items.length, (index) {
              final item = Map<String, dynamic>.from(items[index] as Map);
              final ordered = (item['quantity'] as num?)?.toInt() ?? 1;
              _qty.putIfAbsent(index, () => TextEditingController(text: '$ordered'));
              final price = (item['price'] as num?) ?? 0;
              return Card(child: CheckboxListTile(
                value: _selected.contains(index),
                onChanged: (value) => setState(() { value == true ? _selected.add(index) : _selected.remove(index); }),
                title: Text(item['product_name']?.toString() ?? item['name']?.toString() ?? 'ទំនិញ', style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.w600)),
                subtitle: Row(children: [Expanded(child: Text('បានទិញ $ordered × ${_money.format(price)}៛')), SizedBox(width: 72, child: TextField(controller: _qty[index], enabled: _selected.contains(index), keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'Refund', isDense: true)))]),
              ));
            }),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _liableParty,
              decoration: const InputDecoration(labelText: 'អ្នកទទួលខុសត្រូវ', border: OutlineInputBorder()),
              items: const [DropdownMenuItem(value: 'seller', child: Text('អ្នកលក់')), DropdownMenuItem(value: 'buyer', child: Text('អ្នកទិញ')), DropdownMenuItem(value: 'carrier', child: Text('ក្រុមដឹកជញ្ជូន')), DropdownMenuItem(value: 'sesan', child: Text('ប្រព័ន្ធ Sesan'))],
              onChanged: (v) => setState(() => _liableParty = v ?? 'seller'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _noteController, maxLines: 3, decoration: const InputDecoration(labelText: 'មូលហេតុ និងកំណត់សម្គាល់ Admin', border: OutlineInputBorder())),
            const SizedBox(height: 18),
            SizedBox(height: 50, child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: _busy ? null : () => _process(order),
              icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.currency_exchange),
              label: const Text('ពិនិត្យចំនួន និងដំណើរការ Refund', style: TextStyle(fontFamily: 'Siemreap')),
            )),
          ]);
        },
      ),
    );
  }

  Widget _infoCard() => Card(color: const Color(0xFFFFF8E1), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Order: $_orderId', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4),
    Text('Buyer: ${widget.complaint['customer_name'] ?? '-'}'), Text('Seller: ${widget.complaint['seller_name'] ?? '-'}'),
    Text('បណ្ដឹង៖ ${widget.complaint['reason'] ?? '-'}', style: const TextStyle(fontFamily: 'Siemreap')),
  ])));
}
