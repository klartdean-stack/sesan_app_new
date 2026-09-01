import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class AiPackagesScreen extends StatefulWidget {
  const AiPackagesScreen({super.key});

  @override
  State<AiPackagesScreen> createState() => _AiPackagesScreenState();
}

class _AiPackagesScreenState extends State<AiPackagesScreen> {
  static const _abaUrl = 'https://pay.ababank.com/oRF8/lq8jgwzb';

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String _activePlan = 'free';
  String _activeStatus = 'inactive';
  int _expiresAtMs = 0;
  String _pendingPlan = '';
  String _requestStatus = '';
  String _requestReceiptUrl = '';
  int _creditLimit = 100;
  int _remainingCredits = 100;
  Map<String, Map<String, dynamic>> _packages = const {};

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
        'action': 'packages',
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final rawPackages = Map<String, dynamic>.from(
        (data['packages'] as Map?) ?? const {},
      );
      final packages = <String, Map<String, dynamic>>{};
      rawPackages.forEach((key, value) {
        packages[key] = Map<String, dynamic>.from(value as Map);
      });
      final entitlement = Map<String, dynamic>.from(
        (data['entitlement'] as Map?) ?? const {},
      );
      final request = Map<String, dynamic>.from(
        (data['request'] as Map?) ?? const {},
      );
      if (!mounted) return;
      setState(() {
        _packages = packages;
        _activePlan = (entitlement['plan'] ?? 'free').toString();
        _activeStatus = (entitlement['status'] ?? 'inactive').toString();
        _expiresAtMs =
            int.tryParse((entitlement['expiresAtMs'] ?? 0).toString()) ?? 0;
        _creditLimit =
            int.tryParse((entitlement['creditLimit'] ?? 100).toString()) ?? 100;
        _remainingCredits = int.tryParse(
              (entitlement['remainingCredits'] ?? _creditLimit).toString(),
            ) ??
            _creditLimit;
        _pendingPlan = (request['plan'] ?? '').toString();
        _requestStatus = (request['status'] ?? '').toString();
        _requestReceiptUrl = (request['receiptUrl'] ?? '').toString();
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message ??
            _t('មិនអាចទាញកញ្ចប់ AI បាន', 'Could not load AI packages');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _price(dynamic value) {
    final number = int.tryParse((value ?? 0).toString()) ?? 0;
    final digits = number.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${buffer.toString()} ៛';
  }

  String _date(int ms) {
    if (ms <= 0) return '';
    final value = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  Future<void> _showSubmittedReceipt() async {
    if (_requestReceiptUrl.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t('វិក្កយបត្រដែលបានផ្ញើ', 'Submitted receipt'),
                        style: const TextStyle(
                          fontFamily: 'Siemreap',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    _requestReceiptUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Padding(
                            padding: EdgeInsets.all(50),
                            child: CircularProgressIndicator(),
                          ),
                    errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        _t(
                          'មិនអាចបើកវិក្កយបត្របាន',
                          'Could not open the receipt',
                        ),
                        style: const TextStyle(fontFamily: 'Siemreap'),
                      ),
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

  int _planRank(String plan) {
    switch (plan) {
      case 'starter': return 1;
      case 'pro': return 2;
      case 'business': return 3;
      default: return 0;
    }
  }

  bool get _renewalIsOpen {
    if (_activeStatus != 'active' || _activePlan == 'free') return true;
    final remainingTime = _expiresAtMs - DateTime.now().millisecondsSinceEpoch;
    return _remainingCredits <= 0 ||
        remainingTime <= const Duration(days: 7).inMilliseconds;
  }

  Future<void> _openAba() async {
    await launchUrl(Uri.parse(_abaUrl), mode: LaunchMode.externalApplication);
  }

  Future<void> _requestPlan(String plan, Map<String, dynamic> package) async {
    File? receipt;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18, 16, 18, 18 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 14),
                    Text(_t('ជាវកញ្ចប់ ${plan.toUpperCase()}', 'Subscribe to ${plan.toUpperCase()}'), style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.w800, fontSize: 19)),
                    const SizedBox(height: 5),
                    Text('${package['credits']} Credits • ${package['days']} ${_t('ថ្ងៃ', 'days')} • ${_price(package['price'])}', style: const TextStyle(fontFamily: 'Siemreap', color: Colors.grey)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.shade100)),
                      child: Image.asset('assets/aba_qr.png', height: 175, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox(height: 175, child: Center(child: Icon(Icons.qr_code_2_rounded, size: 120, color: Colors.black54)))),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(onPressed: _openAba, icon: const Icon(Icons.open_in_new_rounded, size: 17), label: Text(_t('បើក ABA Mobile', 'Open ABA Mobile'), style: const TextStyle(fontFamily: 'Siemreap'))),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _submitting ? null : () async {
                        final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
                        if (image != null) setSheetState(() => receipt = File(image.path));
                      },
                      child: Container(
                        width: double.infinity,
                        height: receipt == null ? 120 : 190,
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: receipt == null ? Colors.green.shade200 : Colors.green)),
                        child: receipt == null
                            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.add_photo_alternate_outlined, color: Colors.green, size: 34),
                                const SizedBox(height: 6),
                                Text(_t('ភ្ជាប់រូបបង្កាន់ដៃបង់ប្រាក់', 'Attach payment receipt'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 12)),
                              ])
                            : ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(receipt!, width: double.infinity, fit: BoxFit.cover)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: receipt == null || _submitting ? null : () async {
                          setSheetState(() => _submitting = true);
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) throw StateError('Please sign in first');
                            final ref = FirebaseStorage.instance.ref().child('ai_subscription_receipts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
                            await ref.putFile(receipt!, SettableMetadata(contentType: 'image/jpeg'));
                            final receiptUrl = await ref.getDownloadURL();
                            final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable('askFarmAssistant');
                            await callable.call(<String, dynamic>{'action': 'submit_subscription', 'plan': plan, 'receiptUrl': receiptUrl});
                            if (!mounted) return;
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(_t('បានផ្ញើសំណើជាវទៅ Admin', 'Subscription request sent to Admin'), style: const TextStyle(fontFamily: 'Siemreap')), backgroundColor: Colors.green));
                            await _load();
                          } on FirebaseFunctionsException catch (error) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(error.message ?? _t('មិនអាចផ្ញើសំណើបាន', 'Could not submit request')), backgroundColor: Colors.red));
                          } catch (error) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(error.toString()), backgroundColor: Colors.red));
                          } finally {
                            _submitting = false;
                            if (sheetContext.mounted) setSheetState(() {});
                          }
                        },
                        icon: _submitting ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                        label: Text(_t('ផ្ញើសំណើជាវ', 'Submit subscription request'), style: const TextStyle(fontFamily: 'Siemreap')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF3),
      appBar: AppBar(title: Text(_t('កញ្ចប់ Sesan AI', 'Sesan AI Packages')), backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: FilledButton(onPressed: _load, child: Text(_t('សាកម្ដងទៀត', 'Try again'))))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      _statusCard(),
                      const SizedBox(height: 12),
                      _freeCard(),
                      ...['starter', 'pro', 'business'].map((plan) {
                        final package = _packages[plan];
                        if (package == null) return const SizedBox.shrink();
                        return _packageCard(plan, package);
                      }),
                      const SizedBox(height: 10),
                      Text(_t('សំណើទិញត្រូវបាន Admin ពិនិត្យមុនបើកកញ្ចប់។ Credit មិនអាចដកជាប្រាក់វិញបានទេ។', 'Purchases are reviewed by Admin before activation. AI credits are non-refundable.'), textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Siemreap', fontSize: 10, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
    );
  }

  Widget _statusCard() {
    final pending = _requestStatus == 'pending';
    final active = _activeStatus == 'active' && _activePlan != 'free';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.shade700, Colors.green.shade500]), borderRadius: BorderRadius.circular(17)),
      child: Row(children: [
        const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.auto_awesome, color: Colors.white)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pending ? _t('កំពុងរង់ចាំ Admin', 'Awaiting Admin review') : active ? _t('កញ្ចប់កំពុងប្រើ', 'Active package') : _requestStatus == 'rejected' ? _t('សំណើមុនត្រូវបានបដិសេធ', 'Previous request was rejected') : _t('កញ្ចប់បច្ចុប្បន្ន', 'Current package'), style: const TextStyle(fontFamily: 'Siemreap', color: Colors.white70, fontSize: 11)),
          Text(pending ? _pendingPlan.toUpperCase() : _activePlan.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          if (active && _expiresAtMs > 0) Text('${_t('Credit នៅសល់', 'Credits left')}: $_remainingCredits/$_creditLimit · ${_t('ផុតកំណត់', 'Expires')}: ${_date(_expiresAtMs)}', style: const TextStyle(fontFamily: 'Siemreap', color: Colors.white70, fontSize: 10)),
          if (_requestReceiptUrl.isNotEmpty) TextButton.icon(onPressed: _showSubmittedReceipt, style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact), icon: const Icon(Icons.receipt_long_outlined, size: 16), label: Text(_t('មើលវិក្កយបត្រដែលបានផ្ញើ', 'View submitted receipt'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 10.5))),
        ])),
        if (pending) const Icon(Icons.schedule_rounded, color: Colors.white),
      ]),
    );
  }

  Widget _freeCard() => _planCardShell(
        color: Colors.grey,
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFFF0F2F0), child: Icon(Icons.eco_outlined, color: Colors.green)),
          title: const Text('FREE', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(_t('100 Credits ក្នុងមួយថ្ងៃ', '100 credits per day'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 11)),
          trailing: _activePlan == 'free' ? Chip(label: Text(_t('កំពុងប្រើ', 'Active'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 10))) : null,
        ),
      );

  Widget _packageCard(String plan, Map<String, dynamic> package) {
    final colors = <String, Color>{'starter': Colors.blue, 'pro': Colors.deepPurple, 'business': Colors.orange.shade800};
    final color = colors[plan] ?? Colors.green;
    final pending = _requestStatus == 'pending';
    final hasActivePackage = _activeStatus == 'active' && _activePlan != 'free';
    final active = hasActivePackage && _activePlan == plan;
    final isUpgrade = hasActivePackage && _planRank(plan) > _planRank(_activePlan);
    final canPurchase = !pending && (!hasActivePackage || isUpgrade || (active && _renewalIsOpen));
    return _planCardShell(
      color: color,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
        child: Row(children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.10), child: Icon(Icons.auto_awesome_rounded, color: color)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(plan.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
            Text('${package['credits']} Credits • ${package['days']} ${_t('ថ្ងៃ', 'days')}', style: const TextStyle(fontFamily: 'Siemreap', fontSize: 11)),
            Text(_price(package['price']), style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.w700, fontSize: 14)),
          ])),
          if (active && !_renewalIsOpen)
            Icon(Icons.verified_rounded, color: color)
          else
            FilledButton(onPressed: canPurchase ? () => _requestPlan(plan, package) : null, style: FilledButton.styleFrom(backgroundColor: color, visualDensity: VisualDensity.compact), child: Text(active ? _t('ជាវបន្ត', 'Renew') : _t('ជាវ', 'Buy'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 11))),
        ]),
      ),
    );
  }

  Widget _planCardShell({required Color color, required Widget child}) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: color.withOpacity(0.18))),
        child: child,
      );
}
