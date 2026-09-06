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
  String _selectedLanguage = 'km';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _selectedLanguage = prefs.getString('app_language') ?? 'km');
  }

  Future<void> _changeLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    await Get.updateLocale(code == 'en' ? const Locale('en', 'US') : const Locale('km', 'KH'));
    if (mounted) setState(() => _selectedLanguage = code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: Text(appText(context, km: 'ការកំណត់', en: 'Settings')),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _section(appText(context, km: 'ភាសា', en: 'Language')),
          _languageCard('km', '🇰🇭', 'ខ្មែរ'),
          const SizedBox(height: 10),
          _languageCard('en', '🇬🇧', 'English'),
          const SizedBox(height: 24),
          _section(appText(context, km: 'គណនី និងឯកជនភាព', en: 'Account & privacy')),
          _card(
            Icons.edit_note,
            appText(context, km: 'កែព័ត៌មានផ្ទាល់ខ្លួន', en: 'Edit profile'),
            appText(context, km: 'កែឈ្មោះ រូបភាព និងព័ត៌មានគណនី', en: 'Update your account information'),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          const SizedBox(height: 10),
          _card(
            Icons.shield_outlined,
            appText(context, km: 'គ្រប់គ្រង Block និង Report', en: 'Blocked & reported profiles'),
            appText(context, km: 'មើល និងដោះ Block អ្នកប្រើ', en: 'View blocked users and reports'),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedListScreen())),
          ),
          const SizedBox(height: 10),
          _card(
            Icons.delete_forever_outlined,
            appText(context, km: 'លុបគណនី', en: 'Delete account'),
            appText(context, km: 'អាចស្ដារវិញក្នុងរយៈពេល 15 ថ្ងៃ', en: 'Recoverable for 15 days'),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteAccountScreen())),
            danger: true,
          ),
        ],
      ),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green[800])),
  );

  Widget _languageCard(String code, String flag, String title) {
    final selected = _selectedLanguage == code;
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Text(flag, style: const TextStyle(fontSize: 27)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? Colors.green : Colors.grey),
        onTap: () => _changeLanguage(code),
      ),
    );
  }

  Widget _card(IconData icon, String title, String subtitle, VoidCallback onTap, {bool danger = false}) {
    return Card(
      elevation: 0,
      color: danger ? Colors.red.shade50 : Colors.white,
      child: ListTile(
        leading: Icon(icon, color: danger ? Colors.red : Colors.green[700]),
        title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: danger ? Colors.red.shade800 : null)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 15),
        onTap: onTap,
      ),
    );
  }
}
