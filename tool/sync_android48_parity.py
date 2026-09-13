from pathlib import Path
import os
import re

ANDROID_SOURCE_DIR = Path(os.environ.get('ANDROID_SOURCE_DIR', '/tmp/sesan_app_android'))

SYNC_FILES = [
    'lib/sesan_ai_assistant_screen.dart',
    'lib/ai_packages_screen.dart',
    'lib/admin_ai_dashboard_screen.dart',
    'lib/admin_ai_purchase_history_screen.dart',
]

for rel in SYNC_FILES:
    source = ANDROID_SOURCE_DIR / rel
    if not source.exists():
        raise SystemExit(f'Android source file not found: {source}')
    print(f'Syncing {rel} from Android latest...')
    Path(rel).write_text(source.read_text(encoding='utf-8'), encoding='utf-8')

# Preserve the iOS guest-login UI, but apply the latest Android session fix:
# do not wipe SharedPreferences before a new Firebase login has succeeded.
login_path = Path('lib/login_screen.dart')
login = login_path.read_text(encoding='utf-8')
old_login_block = re.compile(
    r"\n\s*final prefsBeforeLogin = await SharedPreferences\.getInstance\(\);\n"
    r"\s*final savedLanguage = prefsBeforeLogin\.getString\('app_language'\);\n"
    r"\s*final savedRememberPhone = prefsBeforeLogin\.getBool\('remember_phone'\) \?\? false;\n"
    r"\s*final savedPhone = prefsBeforeLogin\.getString\('remembered_phone'\);\n"
    r"\n\s*await prefsBeforeLogin\.clear\(\);\n"
    r"\s*if \(savedLanguage != null\) \{\n"
    r"\s*await prefsBeforeLogin\.setString\('app_language', savedLanguage\);\n"
    r"\s*\}\n"
    r"\s*if \(savedRememberPhone && savedPhone != null && savedPhone\.isNotEmpty\) \{\n"
    r"\s*await prefsBeforeLogin\.setBool\('remember_phone', true\);\n"
    r"\s*await prefsBeforeLogin\.setString\('remembered_phone', savedPhone\);\n"
    r"\s*\}\n"
    r"\s*UserService\.clearCache\(\);",
    re.MULTILINE,
)
login2, count = old_login_block.subn(
    "\n\n    // Keep the existing session/settings until the new login succeeds.\n"
    "    // This matches the latest Android behavior and prevents temporary\n"
    "    // login failures from unexpectedly signing out an existing session.\n"
    "    UserService.clearCache();",
    login,
    count=1,
)
if count:
    login_path.write_text(login2, encoding='utf-8')
    print('Patched login session preservation.')
else:
    print('Login session preservation patch already applied or source changed.')

# Expose the Android AI admin dashboard from the iOS seller/admin profile.
profile_path = Path('lib/profile_screen_legacy.dart')
profile = profile_path.read_text(encoding='utf-8')

admin_import = "import 'admin_ai_dashboard_screen.dart';\n"
if admin_import not in profile:
    marker = "import 'admin_marketplace_analytics_screen.dart';\n"
    if marker not in profile:
        raise SystemExit('Profile import marker not found')
    profile = profile.replace(marker, marker + admin_import, 1)

if 'const AdminAiDashboardScreen()' not in profile:
    marketplace_marker = '''                      if (_loggedUid == adminUID)\n                        _buildMenuCard(\n                          title: \"វិភាគ Marketplace / Marketplace Analytics\",'''
    if marketplace_marker not in profile:
        raise SystemExit('Marketplace admin card marker not found')
    ai_card = '''                      if (_loggedUid == adminUID)\n                        _buildMenuCard(\n                          title: 'គ្រប់គ្រង Sesan AI / Sesan AI Dashboard',\n                          subtitle: 'ការប្រើប្រាស់ Credit សំណើជាវ និងមតិយោបល់',\n                          icon: Icons.auto_awesome_rounded,\n                          color: Colors.deepPurple,\n                          onTap: () => Navigator.push(\n                            context,\n                            MaterialPageRoute(\n                              builder: (context) => const AdminAiDashboardScreen(),\n                            ),\n                          ),\n                        ),\n\n'''
    profile = profile.replace(marketplace_marker, ai_card + marketplace_marker, 1)

profile_path.write_text(profile, encoding='utf-8')
print('Profile AI admin parity applied.')
