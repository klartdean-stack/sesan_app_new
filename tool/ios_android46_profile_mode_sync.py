from pathlib import Path

p = Path('lib/profile_screen_legacy.dart')
s = p.read_text(encoding='utf-8')
changed = False

# Imports for screens already present on the iOS parity branch.
imports = (
    "import 'admin_support_inbox_screen.dart';\n"
    "import 'ai_packages_screen.dart';\n"
    "import 'sesan_ai_assistant_screen.dart';\n"
    "import 'support_chat_screen.dart';\n"
)
if "import 'admin_support_inbox_screen.dart';" not in s:
    anchor = "import 'admin_marketplace_analytics_screen.dart';\n"
    if anchor in s:
        s = s.replace(anchor, anchor + imports, 1)
        changed = True

# User/Seller mode state.
if 'bool _isSellerMode' not in s:
    state_pos = s.find('  bool _isInvestor = false;')
    if state_pos >= 0:
        line_end = s.find('\n', state_pos)
        s = s[:line_end + 1] + '  bool _isSellerMode = false;\n' + s[line_end + 1:]
        changed = True

# Mode-aware title.
old_title = """        title: const Text(
          'គណនី និងការគ្រប់គ្រងប្រាក់',
          style: TextStyle(fontFamily: 'KHMEROS', fontSize: 18),
        ),"""
new_title = """        title: Text(
          _isSellerMode ? 'គណនី និងការគ្រប់គ្រងប្រាក់' : 'គណនី',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'KHMEROS', fontSize: 15),
        ),"""
if old_title in s:
    s = s.replace(old_title, new_title, 1)
    changed = True

# Replace old seller order icon with mode switch.
if 'Switch to Seller Mode' not in s:
    start = s.find('        actions: [\n          StreamBuilder<QuerySnapshot>(')
    end_marker = '        ],\n      ),\n      body: StreamBuilder<DocumentSnapshot>('
    end = s.find(end_marker, start) if start >= 0 else -1
    if start >= 0 and end >= 0:
        block = """        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Tooltip(
              message: _isSellerMode
                  ? 'ប្តូរទៅរបៀបអ្នកប្រើ / Switch to User Mode'
                  : 'ប្តូរទៅរបៀបអ្នកលក់ / Switch to Seller Mode',
              child: IconButton(
                onPressed: () => setState(() => _isSellerMode = !_isSellerMode),
                icon: Icon(
                  _isSellerMode
                      ? Icons.person_outline_rounded
                      : Icons.storefront_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
"""
        s = s[:start] + block + s[end:]
        changed = True

# Primary Android 46 mode cards above legacy cards.
marker = '// Android46 profile mode section'
header = '                _buildHeader(name, photoUrl, balance, isFrozen),\n'
if marker not in s and header in s:
    section = """                // Android46 profile mode section
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    children: [
                      _buildMenuCard(
                        title: 'Sesan AI ជំនួយការ / Sesan AI Assistant',
                        subtitle: 'សួរអំពីកសិកម្ម ការលក់ និងហិរញ្ញវត្ថុ',
                        icon: Icons.auto_awesome_rounded,
                        color: Colors.green,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SesanAiAssistantScreen()),
                        ),
                      ),
                      if (!_isSellerMode)
                        _buildMenuCard(
                          title: 'កញ្ចប់ Sesan AI / Sesan AI Packages',
                          subtitle: 'មើល Credit តម្លៃ និងស្នើសុំជាវកញ្ចប់',
                          icon: Icons.workspace_premium_outlined,
                          color: Colors.deepPurple,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AiPackagesScreen()),
                          ),
                        ),
                      if (!_isSellerMode)
                        _buildMenuCard(
                          title: 'ជំនួយ / Help & Support',
                          subtitle: 'ឆាតជាមួយ Sesan Support / Chat with Sesan Support',
                          icon: Icons.support_agent_rounded,
                          color: Colors.blue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SupportChatScreen()),
                          ),
                        ),
                      if (_isSellerMode)
                        _buildMenuCard(
                          title: 'មជ្ឈមណ្ឌលហិរញ្ញវត្ថុ / Finance Center',
                          subtitle: 'មើលរបាយការណ៍លុយចូល និងលុយចេញ',
                          icon: Icons.account_balance_wallet,
                          color: Colors.purple,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellerAccountingScreen(
                                sellerId: _loggedUid ?? '',
                              ),
                            ),
                          ),
                        ),
                      if (_isSellerMode)
                        StreamBuilder<QuerySnapshot>(
                          stream: _orderStream,
                          builder: (context, snapshot) {
                            final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _buildMenuCard(
                                  title: 'ការបញ្ជាទិញរបស់អ្នកលក់ / Seller Orders',
                                  subtitle: 'គ្រប់គ្រង និងតាមដានការបញ្ជាទិញរបស់អ្នក',
                                  icon: Icons.receipt_long_rounded,
                                  color: Colors.blueGrey,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OrderManagementScreen(
                                        sellerId: _loggedUid ?? '',
                                      ),
                                    ),
                                  ),
                                ),
                                if (count > 0)
                                  Positioned(
                                    right: 38,
                                    top: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Text(
                                        count > 99 ? '99+' : '$count',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      if (_isSellerMode && _loggedUid == adminUID)
                        _buildMenuCard(
                          title: 'ប្រអប់សារ Support / Support Inbox',
                          subtitle: 'ឆ្លើយតបសំណួរ និងបញ្ហារបស់អ្នកប្រើប្រាស់',
                          icon: Icons.mark_unread_chat_alt_outlined,
                          color: Colors.green,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminSupportInboxScreen()),
                          ),
                        ),
                    ],
                  ),
                ),
"""
    s = s.replace(header, header + section, 1)
    changed = True

p.write_text(s, encoding='utf-8')
print('profile parity changed=' + str(changed))
