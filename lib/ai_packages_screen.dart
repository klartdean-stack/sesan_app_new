import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

/// Sesan AI package/credit status for iOS.
/// Subscription purchasing remains server-driven; this screen intentionally
/// avoids duplicating Android-only payment handling while keeping AI usable.
class AiPackagesScreen extends StatefulWidget {
  const AiPackagesScreen({super.key});

  @override
  State<AiPackagesScreen> createState() => _AiPackagesScreenState();
}

class _AiPackagesScreenState extends State<AiPackagesScreen> {
  bool _loading = true;
  String? _error;
  String _activePlan = 'free';
  String _activeStatus = 'inactive';
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
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('askFarmAssistant');
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
      if (!mounted) return;
      setState(() {
        _packages = packages;
        _activePlan = (entitlement['plan'] ?? 'free').toString();
        _activeStatus = (entitlement['status'] ?? 'inactive').toString();
        _creditLimit = int.tryParse((entitlement['creditLimit'] ?? 100).toString()) ?? 100;
        _remainingCredits = int.tryParse(
              (entitlement['remainingCredits'] ?? _creditLimit).toString(),
            ) ?? _creditLimit;
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_t('មិនអាចទាញព័ត៌មានកញ្ចប់ AI បាន',
                            'Could not load AI packages')),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: Text(_t('សាកម្ដងទៀត', 'Try again'))),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_t('កញ្ចប់បច្ចុប្បន្ន', 'Current plan'),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(_activePlan.toUpperCase(),
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                              Text(_activeStatus),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: _creditLimit <= 0
                                    ? 0
                                    : (_remainingCredits / _creditLimit).clamp(0.0, 1.0),
                              ),
                              const SizedBox(height: 6),
                              Text('$_remainingCredits / $_creditLimit Credits'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._packages.entries.map((entry) {
                        final p = entry.value;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.auto_awesome, color: Colors.green),
                            title: Text(entry.key.toUpperCase()),
                            subtitle: Text('${p['credits'] ?? '-'} Credits • ${p['days'] ?? '-'} ${_t('ថ្ងៃ', 'days')}'),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
