import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AiPackagesScreen extends StatefulWidget {
  const AiPackagesScreen({super.key});

  @override
  State<AiPackagesScreen> createState() => _AiPackagesScreenState();
}

class _AiPackagesScreenState extends State<AiPackagesScreen> {
  static const _abaUrl = 'https://pay.ababank.com/oRF8/oizn40j9';

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String _activePlan = 'free';
  String _activeStatus = 'inactive';
  int _expiresAtMs = 0;
  int _creditLimit = 10;
  int _remainingCredits = 10;
  String _pendingPlan = '';
  String _requestStatus = '';
  String _requestReceiptUrl = '';
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
      final result = await callable.call(<String, dynamic>{'action': 'packages'});
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
            int.tryParse((entitlement['creditLimit'] ?? 10).toString()) ?? 10;
        _remainingCredits = int.tryParse(
              (entitlement['remainingCredits'] ?? _creditLimit).toString(),
            ) ??
            _creditLimit;
        _pendingPlan = (request['plan'] ?? '').toString();
        _requestStatus = (request['status'] ?? '').toString();
        _requestReceiptUrl = (request['receiptUrl'] ?? '').toString();
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? e.code);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _price(dynamic value) {
    final n = int.tryParse((value ?? 0).toString()) ?? 0;
    final digits = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return '${out.toString()} ៛';
  }

  String _date(int ms) {
    if (ms <= 0) return '';
    final value = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  int _planRank(String plan) {
    switch (plan) {
      case 'starter':
        return 1;
      case 'pro':
        return 2;
      case 'business':
        return 3;
      default:
        return 0;
    }
  }

  bool get _renewalIsOpen {
    if (_activeStatus != 'active' || _activePlan == 'free') return true;
    final remaining = _expiresAtMs - DateTime.now().millisecondsSinceEpoch;
    return _remainingCredits <= 0 ||
        remaining <= const Duration(days: 7).inMilliseconds;
  }

  Future<void> _openAba() async {
    await launchUrl(Uri.parse(_abaUrl), mode: LaunchMode.externalApplication);
  }

  void _showTopMessage(String message, {bool isError = false}) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.of(overlayContext).padding.top + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isError ? Colors.red.shade700 : Colors.green.shade700,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Siemreap',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  Future<void> _saveQrToGallery() async {
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      if (!await Gal.hasAccess()) {
        throw Exception(
          _t(
            'សូមអនុញ្ញាតឱ្យ App រក្សាទុករូបភាពក្នុង Gallery',
            'Please allow the app to save images to Gallery.',
          ),
        );
      }
      final data = await rootBundle.load('assets/aba_qr.png');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sesan_aba_qr.png');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      await Gal.putImage(file.path);
      if (mounted) {
        _showTopMessage(
          _t('បានរក្សាទុក QR ក្នុង Gallery រួចរាល់!', 'QR saved to Gallery successfully!'),
        );
      }
    } catch (e) {
      if (mounted) {
        _showTopMessage(
          _t('មិនអាចរក្សាទុក QR បាន: $e', 'Unable to save QR: $e'),
          isError: true,
        );
      }
    }
  }

  Future<void> _showReceipt() async {
    if (_requestReceiptUrl.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t('វិក្កយបត្រដែលបានផ្ញើ', 'Submitted receipt'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: Image.network(_requestReceiptUrl, fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestPlan(
    String plan,
    Map<String, dynamic> package,
  ) async {
    File? receipt;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              18 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _t(
                      'ជាវកញ្ចប់ ${plan.toUpperCase()}',
                      'Subscribe to ${plan.toUpperCase()}',
                    ),
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${package['credits']} Credits • ${package['days']} ${_t('ថ្ងៃ', 'days')} • ${_price(package['price'])}',
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onLongPress: _saveQrToGallery,
                    child: Image.asset('assets/aba_qr.png', height: 175),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('ចុចយូរលើ QR ដើម្បីរក្សាទុក', 'Long-press the QR to save it'),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openAba,
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: Text(_t('បើក ABA Mobile', 'Open ABA Mobile')),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _submitting
                        ? null
                        : () async {
                            final image = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                              maxWidth: 1800,
                            );
                            if (image != null) {
                              setSheetState(() => receipt = File(image.path));
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      height: receipt == null ? 120 : 190,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: receipt == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: Colors.green,
                                  size: 34,
                                ),
                                const SizedBox(height: 6),
                                Text(_t('ភ្ជាប់រូបបង្កាន់ដៃបង់ប្រាក់', 'Attach payment receipt')),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.file(receipt!, fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: receipt == null || _submitting
                          ? null
                          : () async {
                              setSheetState(() => _submitting = true);
                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) {
                                  throw StateError(_t('សូម Login ជាមុន', 'Please sign in first'));
                                }
                                final ref = FirebaseStorage.instance
                                    .ref()
                                    .child(
                                      'ai_subscription_receipts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg',
                                    );
                                await ref.putFile(
                                  receipt!,
                                  SettableMetadata(contentType: 'image/jpeg'),
                                );
                                final receiptUrl = await ref.getDownloadURL();
                                final callable = FirebaseFunctions.instanceFor(
                                  region: 'asia-southeast1',
                                ).httpsCallable('askFarmAssistant');
                                await callable.call(<String, dynamic>{
                                  'action': 'submit_subscription',
                                  'plan': plan,
                                  'receiptUrl': receiptUrl,
                                });
                                if (!mounted) return;
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                _showTopMessage(
                                  _t('បានផ្ញើសំណើជាវទៅ Admin', 'Subscription request sent to Admin'),
                                );
                                await _load();
                              } catch (e) {
                                if (mounted) {
                                  _showTopMessage(e.toString(), isError: true);
                                }
                              } finally {
                                _submitting = false;
                                if (sheetContext.mounted) setSheetState(() {});
                              }
                            },
                      icon: _submitting
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_t('ផ្ញើសំណើជាវ', 'Submit subscription request')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF3),
      appBar: AppBar(
        title: Text(_t('កញ្ចប់ Sesan AI', 'Sesan AI Packages')),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: FilledButton(
                    onPressed: _load,
                    child: Text(_t('សាកម្ដងទៀត', 'Try again')),
                  ),
                )
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
                      Text(
                        _t(
                          'សំណើទិញត្រូវបាន Admin ពិនិត្យមុនបើកកញ្ចប់។ Credit មិនអាចដកជាប្រាក់វិញបានទេ។',
                          'Purchases are reviewed by Admin before activation. AI credits are non-refundable.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending
                      ? _t('កំពុងរង់ចាំ Admin', 'Awaiting Admin review')
                      : active
                          ? _t('កញ្ចប់កំពុងប្រើ', 'Active package')
                          : _t('កញ្ចប់បច្ចុប្បន្ន', 'Current package'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  (pending ? _pendingPlan : _activePlan).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                if (active && _expiresAtMs > 0)
                  Text(
                    '${_t('Credit នៅសល់', 'Credits left')}: $_remainingCredits/$_creditLimit · ${_t('ផុតកំណត់', 'Expires')}: ${_date(_expiresAtMs)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                if (_requestReceiptUrl.isNotEmpty)
                  TextButton.icon(
                    onPressed: _showReceipt,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: Text(_t('មើលវិក្កយបត្រ', 'View receipt')),
                  ),
              ],
            ),
          ),
          if (pending) const Icon(Icons.schedule_rounded, color: Colors.white),
        ],
      ),
    );
  }

  Widget _freeCard() {
    return _planShell(
      Colors.grey,
      ListTile(
        leading: const Icon(Icons.eco_outlined, color: Colors.green),
        title: const Text('FREE', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(_t('10 Credits ក្នុងមួយថ្ងៃ', '10 credits per day')),
        trailing: _activePlan == 'free'
            ? Chip(label: Text(_t('កំពុងប្រើ', 'Active')))
            : null,
      ),
    );
  }

  Widget _packageCard(String plan, Map<String, dynamic> package) {
    final colors = <String, Color>{
      'starter': Colors.blue,
      'pro': Colors.deepPurple,
      'business': Colors.orange.shade800,
    };
    final color = colors[plan] ?? Colors.green;
    final pending = _requestStatus == 'pending';
    final hasActive = _activeStatus == 'active' && _activePlan != 'free';
    final active = hasActive && _activePlan == plan;
    final isUpgrade = hasActive && _planRank(plan) > _planRank(_activePlan);
    final canPurchase =
        !pending && (!hasActive || isUpgrade || (active && _renewalIsOpen));

    return _planShell(
      color,
      Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: color),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text('${package['credits']} Credits • ${package['days']} ${_t('ថ្ងៃ', 'days')}'),
                  Text(
                    _price(package['price']),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (active && !_renewalIsOpen)
              Icon(Icons.verified_rounded, color: color)
            else
              FilledButton(
                onPressed: canPurchase ? () => _requestPlan(plan, package) : null,
                style: FilledButton.styleFrom(backgroundColor: color),
                child: Text(active ? _t('ជាវបន្ត', 'Renew') : _t('ជាវ', 'Buy')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _planShell(Color color, Widget child) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: color.withOpacity(0.18)),
      ),
      child: child,
    );
  }
}
