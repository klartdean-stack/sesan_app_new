import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_deletion_service.dart';
import 'localized_text.dart';
import 'login_screen.dart';
import 'user_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  bool _understood = false;
  bool _hidePassword = true;
  bool _isDeleting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (!_understood || _passwordController.text.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_uid') ?? '';
    if (uid.isEmpty) return;

    setState(() => _isDeleting = true);
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userDoc = await userRef.get();
      final savedPassword = (userDoc.data()?['password'] ?? '').toString().trim();
      if (savedPassword != _passwordController.text.trim()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(appText(context, km: 'លេខសម្ងាត់មិនត្រឹមត្រូវ', en: 'Incorrect password')),
          backgroundColor: Colors.red,
        ));
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(appText(context, km: 'បញ្ជាក់ការលុបគណនី', en: 'Confirm account deletion')),
          content: Text(appText(
            context,
            km: 'គណនី និង Content របស់អ្នកនឹងបាត់ពី App។ អ្នកអាច Login ដើម្បីស្ដារវិញក្នុងរយៈពេល 15 ថ្ងៃ។',
            en: 'Your account and content will disappear from the app. You can sign in and restore everything within 15 days.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(appText(context, km: 'បោះបង់', en: 'Cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(appText(context, km: 'លុបគណនី', en: 'Delete account')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final now = DateTime.now();
      final deadline = now.add(const Duration(days: 15));
      final archivedCount = await AccountDeletionService.archiveOwnedContent(uid);
      await userRef.set({
        'accountStatus': 'pending_deletion',
        'isDeleted': true,
        'deletedAt': Timestamp.fromDate(now),
        'restoreDeadline': Timestamp.fromDate(deadline),
        'archivedContentCount': archivedCount,
      }, SetOptions(merge: true));

      final language = prefs.getString('app_language');
      await prefs.clear();
      if (language != null) await prefs.setString('app_language', language);
      UserService.clearCache();
      if (!mounted) return;
      Get.offAll(() => const LoginScreen());
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appText(context, km: 'លុបគណនី', en: 'Delete account')),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              appText(
                context,
                km: '• Profile និង Content របស់អ្នកនឹងបាត់ពី App\n• Products, Pre-order, Wanted និង Auction នឹងត្រូវ Archive\n• អាចស្ដារគណនី និង Content វិញក្នុង 15 ថ្ងៃ\n• ក្រោយ 15 ថ្ងៃ មិនអាចស្ដារវិញបានទេ',
                en: '• Your profile and content disappear from the app\n• Products, pre-orders, wanted posts and auctions are archived\n• Account and content can be restored within 15 days\n• Recovery is unavailable after 15 days',
              ),
              style: const TextStyle(fontSize: 12, height: 1.7),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: _hidePassword,
            decoration: InputDecoration(
              labelText: appText(context, km: 'បញ្ចូលលេខសម្ងាត់', en: 'Enter password'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          CheckboxListTile(
            value: _understood,
            onChanged: (value) => setState(() => _understood = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.red,
            title: Text(appText(
              context,
              km: 'ខ្ញុំយល់ពីរយៈពេលស្ដារ 15 ថ្ងៃ',
              en: 'I understand the 15-day recovery period',
            )),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isDeleting ? null : _deleteAccount,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            icon: _isDeleting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.delete_forever),
            label: Text(appText(context, km: 'លុបគណនី', en: 'Delete account')),
          ),
        ],
      ),
    );
  }
}
