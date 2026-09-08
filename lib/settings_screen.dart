import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'edit_profile_screen.dart';
import 'blocked_list_screen.dart';
import 'delete_account_screen.dart';
import 'localized_text.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _appVersion = '1.0.0';
  static const String _buildNumber = '54';
  String _selectedLanguage = 'km';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_language') ?? Get.locale?.languageCode ?? 'km';
    if (mounted) setState(() => _selectedLanguage = code);
  }

  Future<void> _changeLanguage(String code) async {
    if (_selectedLanguage == code) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    await Get.updateLocale(code == 'en' ? const Locale('en', 'US') : const Locale('km', 'KH'));
    if (!mounted) return;
    setState(() => _selectedLanguage = code);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(appText(context, km: 'បានប្តូរភាសាដោយជោគជ័យ។', en: 'Language changed successfully.')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: Text(appText(context, km: 'ការកំណត់', en: 'Settings'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _section(appText(context, km: 'ភាសា', en: 'Language')),
          Text(appText(context, km: 'ជ្រើសរើសភាសាសម្រាប់ Sesan App', en: 'Choose the language for Sesan App'), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 16),
          _languageCard(code: 'km', title: 'ខ្មែរ', subtitle: 'ប្រើកម្មវិធីជាភាសាខ្មែរ', flag: '🇰🇭'),
          const SizedBox(height: 12),
          _languageCard(code: 'en', title: 'English', subtitle: 'Use Sesan App in English', flag: '🇬🇧'),
          const SizedBox(height: 28),
          _section(appText(context, km: 'គណនី និងឯកជនភាព', en: 'Account & privacy')),
          _settingsCard(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2F1), child: Icon(Icons.edit_note, color: Colors.teal)),
            title: appText(context, km: 'កែព័ត៌មានផ្ទាល់ខ្លួន', en: 'Edit profile'),
            subtitle: appText(context, km: 'កែឈ្មោះ រូបភាព និងព័ត៌មានគណនី', en: 'Update your account information'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          const SizedBox(height: 12),
          _settingsCard(
            leading: const CircleAvatar(backgroundColor: Color(0xFFFFEBEE), child: Icon(Icons.shield_outlined, color: Colors.redAccent)),
            title: appText(context, km: 'គ្រប់គ្រង Block និង Report', en: 'Blocked & reported profiles'),
            subtitle: appText(context, km: 'មើលបញ្ជី ដោះ Block និងគ្រប់គ្រង Report របស់អ្នក', en: 'View blocked users and manage your reports'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedListScreen())),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.red.shade200)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(backgroundColor: Colors.red.shade100, child: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700)),
              title: Text(appText(context, km: 'លុបគណនី', en: 'Delete account'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red.shade800)),
              subtitle: Text(appText(context, km: 'អាចស្ដារគណនីវិញក្នុងរយៈពេល 15 ថ្ងៃ', en: 'Recoverable for 15 days'), style: const TextStyle(fontSize: 12)),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red.shade600),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteAccountScreen())),
            ),
          ),
          const SizedBox(height: 28),
          _section(appText(context, km: 'អំពីកម្មវិធី', en: 'ABOUT APP')),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE1E5E1))),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const CircleAvatar(backgroundColor: Color(0xFFEAF7EA), child: Icon(Icons.info_outline, color: Colors.green)),
              title: const Text('Sesan App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('${appText(context, km: 'កំណែ', en: 'Version')} $_appVersion  •  ${appText(context, km: 'Build', en: 'Build')} $_buildNumber', style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.verified_outlined, size: 20, color: Colors.green),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text('© 2026 Sesan', style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _section(String text) => Text(text, style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: .4));

  Widget _settingsCard({required Widget leading, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE1E5E1))),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: leading,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _languageCard({required String code, required String title, required String subtitle, required String flag}) {
    final selected = _selectedLanguage == code;
    return Material(
      color: selected ? const Color(0xFFEAF7EA) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _changeLanguage(code),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? Colors.green : const Color(0xFFE1E5E1), width: selected ? 1.5 : 1),
          ),
          child: Row(children: [
            Text(flag, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ])),
            Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? Colors.green : Colors.grey[400]),
          ]),
        ),
      ),
    );
  }
}
