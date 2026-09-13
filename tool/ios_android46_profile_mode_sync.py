from pathlib import Path
import re

p = Path('lib/profile_screen_legacy.dart')
s = p.read_text(encoding='utf-8')


def insert_after(anchor: str, addition: str, marker: str):
    global s
    if marker in s:
        return
    if anchor not in s:
        raise SystemExit(f'anchor not found: {anchor[:60]}')
    s = s.replace(anchor, anchor + addition, 1)


# Imports used by the Android 46 account experience. All of these screens
# already exist on the iOS parity branch.
import_anchor = "import 'package:my_app/admin_marketplace_analytics_screen.dart';\n"
imports = (
    "import 'package:my_app/admin_support_inbox_screen.dart';\n"
    "import 'package:my_app/ai_packages_screen.dart';\n"
    "import 'package:my_app/sesan_ai_assistant_screen.dart';\n"
    "import 'package:my_app/support_chat_screen.dart';\n"
)
insert_after(import_anchor, imports, "admin_support_inbox_screen.dart")

# User Mode / Seller Mode state.
if 'bool _isSellerMode' not in s:
    m = re.search(r"(\s+bool _isInvestor\s*=\s*false;[^\n]*\n)", s)
    if not m:
        raise SystemExit('investor state anchor not found')
    s = s[:m.end()] + '  bool _isSellerMode = false;\n' + s[m.end():]

# Compact mode-aware title.
s = re.sub(
    r"title:\s*const Text\(\s*'គណនី និងការគ្រប់គ្រងប្រាក់',\s*style:\s*TextStyle\(fontFamily: 'KHMEROS', fontSize: 18\),\s*\),",
    """title: Text(
          _isSellerMode ? 'គណនី និងការគ្រប់គ្រងប្រាក់' : 'គណនី',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'KHMEROS', fontSize: 15),
        ),""",
    s,
    count=1,
    flags=re.S,
)

# Replace the old order badge in the AppBar with the same User/Seller switch
# used on Android 46. Seller order count is shown as a card below instead.
if 'Switch to Seller Mode' not in s:
    pattern = re.compile(
        r"\s*actions:\s*\[\s*StreamBuilder<QuerySnapshot>\(.*?\n\s*\],\s*\n\s*\),\s*\n\s*body:\s*StreamBuilder<DocumentSnapshot>\(",
        re.S,
    )
    replacement = """
        actions: [
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
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>("""
    s, count = pattern.subn(replacement, s, count=1)
    if count != 1:
        raise SystemExit('app bar action block not found')

# Android 46 primary mode section. This deliberately sits above the legacy
# account cards, preserving existing iOS features while making the primary
# User/Seller navigation identical in purpose to Android.
if 'Android46 profile mode section' not in s:
    anchor = '                _buildHeader(name, photoUrl, balance, isFrozen),\n'
    if anchor not in s:
        raise SystemExit('profile header anchor not found')
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
                          MaterialPageRoute(
                            builder: (_) => const SesanAiAssistantScreen(),
                          ),
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
                            MaterialPageRoute(
                              builder: (_) => const AiPackagesScreen(),
                            ),
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
                            MaterialPageRoute(
                              builder: (_) => const SupportChatScreen(),
                            ),
                          ),
                        ),
                      if (_isSellerMode) ...[
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
                        StreamBuilder<QuerySnapshot>(
                          stream: _orderStream,
                          builder: (context, snapshot) {
                            final count = snapshot.hasData
                                ? snapshot.data!.docs.length
                                : 0;
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
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
                      ],
                      if (_isSellerMode && _loggedUid == adminUID)
                        _buildMenuCard(
                          title: 'ប្រអប់សារ Support / Support Inbox',
                          subtitle: 'ឆ្លើយតបសំណួរ និងបញ្ហារបស់អ្នកប្រើប្រាស់',
                          icon: Icons.mark_unread_chat_alt_outlined,
                          color: Colors.green,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminSupportInboxScreen(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
"""
    s = s.replace(anchor, anchor + section, 1)

p.write_text(s, encoding='utf-8')
print('iOS profile User/Seller mode parity patch applied')
