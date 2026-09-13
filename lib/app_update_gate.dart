import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateGate extends StatefulWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  bool _checking = true;
  bool _updateRequired = false;
  bool _forceUpdate = false;
  String _storeUrl = '';
  String _titleKm = 'មានកំណែថ្មី';
  String _titleEn = 'New update available';
  String _messageKm = 'សូមអាប់ដេត Sesan App ដើម្បីទទួលបានកំណែថ្មីបំផុត។';
  String _messageEn = 'Please update Sesan App to get the latest version.';

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    if (kIsWeb) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults(const {
        // Keep iOS disabled by default until an App Store URL/build is configured.
        'ios_latest_build': 0,
        'ios_minimum_build': 0,
        'ios_force_update': false,
        'ios_store_url': '',
        'update_title_km': 'មានកំណែថ្មី',
        'update_title_en': 'New update available',
        'update_message_km': 'សូមអាប់ដេត Sesan App ដើម្បីទទួលបានកំណែថ្មីបំផុត។',
        'update_message_en': 'Please update Sesan App to get the latest version.',
      });
      await remoteConfig.fetchAndActivate();

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final latestBuild = remoteConfig.getInt('ios_latest_build');
      final minimumBuild = remoteConfig.getInt('ios_minimum_build');
      final forceSwitch = remoteConfig.getBool('ios_force_update');
      final storeUrl = remoteConfig.getString('ios_store_url').trim();

      final needsUpdate = latestBuild > 0 && currentBuild < latestBuild;
      final mustUpdate = needsUpdate &&
          (currentBuild < minimumBuild || forceSwitch);

      if (!mounted) return;
      setState(() {
        _checking = false;
        _updateRequired = needsUpdate;
        _forceUpdate = mustUpdate;
        _storeUrl = storeUrl;
        _titleKm = _valueOrDefault(
          remoteConfig.getString('update_title_km'),
          _titleKm,
        );
        _titleEn = _valueOrDefault(
          remoteConfig.getString('update_title_en'),
          _titleEn,
        );
        _messageKm = _valueOrDefault(
          remoteConfig.getString('update_message_km'),
          _messageKm,
        );
        _messageEn = _valueOrDefault(
          remoteConfig.getString('update_message_en'),
          _messageEn,
        );
      });
    } catch (e) {
      debugPrint('iOS Remote Config update check failed: $e');
      // A network/config failure must never block app launch.
      if (mounted) setState(() => _checking = false);
    }
  }

  String _valueOrDefault(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value.trim();

  Future<void> _openStore() async {
    if (_storeUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'en'
                ? 'The App Store update link is not available yet.'
                : 'តំណ App Store សម្រាប់អាប់ដេតមិនទាន់មាននៅឡើយទេ។',
          ),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(_storeUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    if (!_updateRequired) return widget.child;

    final isEnglish =
        Localizations.maybeLocaleOf(context)?.languageCode == 'en';
    final title = isEnglish ? _titleEn : _titleKm;
    final message = isEnglish ? _messageEn : _messageKm;

    return PopScope(
      canPop: !_forceUpdate,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.system_update_rounded,
                    size: 82,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _openStore,
                      icon: const Icon(Icons.download_rounded),
                      label: Text(
                        isEnglish ? 'Update now' : 'អាប់ដេតឥឡូវនេះ',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  if (!_forceUpdate) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => setState(() => _updateRequired = false),
                      child: Text(isEnglish ? 'Later' : 'ពេលក្រោយ'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
