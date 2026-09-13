from pathlib import Path

path = Path('lib/profile_screen_legacy.dart')
text = path.read_text(encoding='utf-8')

import_line = "import 'admin_ai_dashboard_screen.dart';\n"
if import_line not in text:
    marker = "import 'admin_marketplace_analytics_screen.dart';\n"
    if marker not in text:
        raise SystemExit('admin marketplace import marker not found')
    text = text.replace(marker, marker + import_line, 1)

if 'const AdminAiDashboardScreen()' not in text:
    marker = '''                      if (_loggedUid == adminUID)\n                        _buildMenuCard(\n                          title: \"វិភាគ Marketplace / Marketplace Analytics\",'''
    if marker not in text:
        raise SystemExit('marketplace card marker not found')
    card = '''                      if (_loggedUid == adminUID)\n                        _buildMenuCard(\n                          title: 'គ្រប់គ្រង Sesan AI / Sesan AI Dashboard',\n                          subtitle: 'ការប្រើប្រាស់ Credit សំណើជាវ និងមតិយោបល់',\n                          icon: Icons.auto_awesome_rounded,\n                          color: Colors.deepPurple,\n                          onTap: () => Navigator.push(\n                            context,\n                            MaterialPageRoute(\n                              builder: (context) => const AdminAiDashboardScreen(),\n                            ),\n                          ),\n                        ),\n\n'''
    text = text.replace(marker, card + marker, 1)

path.write_text(text, encoding='utf-8')
