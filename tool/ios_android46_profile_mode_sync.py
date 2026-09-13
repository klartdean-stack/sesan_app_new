from pathlib import Path

p = Path('lib/profile_screen_legacy.dart')
s = p.read_text(encoding='utf-8')

# Imports needed by the Android 46 profile parity cards.
anchor = "import 'package:my_app/admin_marketplace_analytics_screen.dart';\n"
extra = (
    "import 'package:my_app/admin_support_inbox_screen.dart';\n"
    "import 'package:my_app/ai_packages_screen.dart';\n"
    "import 'package:my_app/sesan_ai_assistant_screen.dart';\n"
    "import 'package:my_app/support_chat_screen.dart';\n"
)
if "admin_support_inbox_screen.dart" not in s:
    if anchor not in s:
        raise SystemExit('profile import anchor not found')
    s = s.replace(anchor, anchor + extra, 1)

# Add the Android-style User/Seller mode state.
state_anchor = "  bool _isInvestor = false; // ✅ បន្ថែមបន្ទាត់នេះ\n"
if "bool _isSellerMode" not in s:
    if state_anchor not in s:
        raise SystemExit('profile state anchor not found')
    s = s.replace(state_anchor, state_anchor + "  bool _isSellerMode = false;\n", 1)

# Replace the legacy title with a compact mode-aware title.
old_title = """        title: const Text(\n          'គណនី និងការគ្រប់គ្រងប្រាក់',\n          style: TextStyle(fontFamily: 'KHMEROS', fontSize: 18),\n        ),"""
new_title = """        title: Text(\n          _isSellerMode\n              ? 'គណនី និងការគ្រប់គ្រងប្រាក់'\n              : 'គណនី',\n          maxLines: 1,\n          overflow: TextOverflow.ellipsis,\n          style: const TextStyle(fontFamily: 'KHMEROS', fontSize: 15),\n        ),"""
if old_title in s:
    s = s.replace(old_title, new_title, 1)
elif "_isSellerMode\n              ? 'គណនី និងការគ្រប់គ្រងប្រាក់'" not in s:
    raise SystemExit('profile title anchor not found')

# Replace the old seller-order app-bar badge with Android 46's mode switch.
start = s.find("        actions: [\n          StreamBuilder<QuerySnapshot>(")
end_marker = "        ],\n      ),\n      body: StreamBuilder<DocumentSnapshot>("
end = s.find(end_marker, start) if start != -1 else -1
if start != -1 and end != -1:
    new_actions = """        actions: [\n          Padding(\n            padding: const EdgeInsets.only(right: 10),\n            child: Tooltip(\n              message: _isSellerMode\n                  ? 'ប្តូរទៅរបៀបអ្នកប្រើ / Switch to User Mode'\n                  : 'ប្តូរទៅរបៀបអ្នកលក់ / Switch to Seller Mode',\n              child: IconButton(\n                onPressed: () => setState(() => _isSellerMode = !_isSellerMode),\n                icon: Icon(\n                  _isSellerMode\n                      ? Icons.person_outline_rounded\n                      : Icons.storefront_outlined,\n                  color: Colors.white,\n                  size: 24,\n                ),\n              ),\n            ),\n          ),\n"""
    s = s[:start] + new_actions + s[end:]
elif "Switch to Seller Mode" not in s:
    raise SystemExit('profile actions block not found')

# Add the mode-specific quick section directly below the profile header. This
# gives iOS the same primary separation as Android 46 while retaining legacy
# cards until the rest of the large profile is fully split in later parity work.
header_anchor = """                _buildHeader(name, photoUrl, balance, isFrozen),\n                const SizedBox(height: 20),"""
mode_section = """                _buildHeader(name, photoUrl, balance, isFrozen),\n                const SizedBox(height: 14),\n                Padding(\n                  padding: const EdgeInsets.symmetric(horizontal: 15),\n                  child: Column(\n                    children: [\n                      _buildMenuCard(\n                        title: 'Sesan AI ជំនួយការ / Sesan AI Assistant',\n                        subtitle: 'សួរអំពីកសិកម្ម ការលក់ និងហិរញ្ញវត្ថុ',\n                        icon: Icons.auto_awesome_rounded,\n                        color: Colors.green,\n                        onTap: () => Navigator.push(\n                          context,\n                          MaterialPageRoute(\n                            builder: (_) => const SesanAiAssistantScreen(),\n                          ),\n                        ),\n                      ),\n                      if (!_isSellerMode)\n                        _buildMenuCard(\n                          title: 'កញ្ចប់ Sesan AI / Sesan AI Packages',\n                          subtitle: 'មើល Credit តម្លៃ និងស្នើសុំជាវកញ្ចប់',\n                          icon: Icons.workspace_premium_outlined,\n                          color: Colors.deepPurple,\n                          onTap: () => Navigator.push(\n                            context,\n                            MaterialPageRoute(\n                              builder: (_) => const AiPackagesScreen(),\n                            ),\n                          ),\n                        ),\n                      if (!_isSellerMode)\n                        _buildMenuCard(\n                          title: 'ជំនួយ និង Support / Help & Support',\n                          subtitle: 'ឆាតជាមួយ Sesan Support',\n                          icon: Icons.support_agent_rounded,\n                          color: Colors.blue,\n                          onTap: () => Navigator.push(\n                            context,\n                            MaterialPageRoute(\n                              builder: (_) => const SupportChatScreen(),\n                            ),\n                          ),\n                        ),\n                      if (_isSellerMode)\n                        _buildMenuCard(\n                          title: 'មជ្ឈមណ្ឌលហិរញ្ញវត្ថុ / Finance Center',\n                          subtitle: 'មើលរបាយការណ៍លុយចូល និងលុយចេញ',\n                          icon: Icons.account_balance_wallet,\n                          color: Colors.purple,\n                          onTap: () => Navigator.push(\n                            context,\n                            MaterialPageRoute(\n                              builder: (_) => SellerAccountingScreen(\n                                sellerId: _loggedUid ?? '',\n                              ),\n                            ),\n                          ),\n                        ),\n                      if (_isSellerMode)\n                        StreamBuilder<QuerySnapshot>(\n                          stream: _orderStream,\n                          builder: (context, snapshot) {\n                            final count = snapshot.hasData\n                                ? snapshot.data!.docs.length\n                                : 0;\n                            return Stack(\n                              clipBehavior: Clip.none,\n                              children: [\n                                _buildMenuCard(\n                                  title: 'ការបញ្ជាទិញរបស់អ្នកលក់ / Seller Orders',\n                                  subtitle: 'គ្រប់គ្រង និងតាមដានការបញ្ជាទិញរបស់អ្នក',\n                                  icon: Icons.receipt_long_rounded,\n                                  color: Colors.blueGrey,\n                                  onTap: () => Navigator.push(\n                                    context,\n                                    MaterialPageRoute(\n                                      builder: (_) => OrderManagementScreen(\n                                        sellerId: _loggedUid ?? '',\n                                      ),\n                                    ),\n                                  ),\n                                ),\n                                if (count > 0)\n                                  Positioned(\n                                    right: 38,\n                                    top: 10,\n                                    child: Container(\n                                      padding: const EdgeInsets.symmetric(\n                                        horizontal: 6,\n                                        vertical: 2,\n                                      ),\n                                      decoration: BoxDecoration(\n                                        color: Colors.red,\n                                        borderRadius: BorderRadius.circular(11),\n                                      ),\n                                      child: Text(\n                                        count > 99 ? '99+' : '$count',\n                                        style: const TextStyle(\n                                          color: Colors.white,\n                                          fontSize: 10,\n                                          fontWeight: FontWeight.bold,\n                                        ),\n                                      ),\n                                    ),\n                                  ),\n                              ],\n                            );\n                          },\n                        ),\n                      if (_isSellerMode && _loggedUid == adminUID)\n                        _buildMenuCard(\n                          title: 'ប្រអប់សារ Support / Support Inbox',\n                          subtitle: 'ឆ្លើយតបសំណួរ និងបញ្ហារបស់អ្នកប្រើប្រាស់',\n                          icon: Icons.mark_unread_chat_alt_outlined,\n                          color: Colors.green,\n                          onTap: () => Navigator.push(\n                            context,\n                            MaterialPageRoute(\n                              builder: (_) => const AdminSupportInboxScreen(),\n                            ),\n                          ),\n                        ),\n                    ],\n                  ),\n                ),\n                const SizedBox(height: 20),"""
if "ការបញ្ជាទិញរបស់អ្នកលក់ / Seller Orders" not in s:
    if header_anchor not in s:
        raise SystemExit('profile header anchor not found')
    s = s.replace(header_anchor, mode_section, 1)

p.write_text(s, encoding='utf-8')
print('iOS profile User/Seller mode parity patch applied')
