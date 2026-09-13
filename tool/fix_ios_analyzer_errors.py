from pathlib import Path

# 1) Chat: appText(context, ...) is runtime work and cannot be inside const.
p = Path('lib/chat_screen_legacy.dart')
s = p.read_text(encoding='utf-8')
s = s.replace(
    '''      return const SizedBox(\n        width: 100,\n        height: 40,\n        child: Center(\n          child: Text(appText(context, km: "កំពុងផ្ញើ...", en: "Sending..."), style: const TextStyle(fontSize: 10)),\n        ),\n      );''',
    '''      return SizedBox(\n        width: 100,\n        height: 40,\n        child: Center(\n          child: Text(\n            appText(context, km: "កំពុងផ្ញើ...", en: "Sending..."),\n            style: const TextStyle(fontSize: 10),\n          ),\n        ),\n      );''',
)
p.write_text(s, encoding='utf-8')

# 2) Linux CI is case-sensitive; file is shareholder_dividend_history.dart.
p = Path('lib/investor_dashboard_screen.dart')
s = p.read_text(encoding='utf-8')
s = s.replace(
    "import 'package:my_app/Shareholder_dividend_history.dart';",
    "import 'package:my_app/shareholder_dividend_history.dart';",
)
p.write_text(s, encoding='utf-8')

# 3) iOS source does not contain Android's LanguageSwitcher widget. Keep the
# language capability by using GetX LanguageController directly.
p = Path('lib/signup_screen.dart')
s = p.read_text(encoding='utf-8')
old = '''                const Align(\n                  alignment: Alignment.centerRight,\n                  child: LanguageSwitcher(),\n                ),'''
new = '''                Align(\n                  alignment: Alignment.centerRight,\n                  child: TextButton.icon(\n                    onPressed: () {\n                      final controller = Get.find<LanguageController>();\n                      final isEnglish =\n                          Localizations.localeOf(context).languageCode == 'en';\n                      controller.changeLanguage(isEnglish ? 'km' : 'en');\n                    },\n                    icon: const Icon(Icons.language, size: 18),\n                    label: Text(\n                      Localizations.localeOf(context).languageCode == 'en'\n                          ? 'ខ្មែរ'\n                          : 'English',\n                    ),\n                  ),\n                ),'''
if old not in s:
    raise SystemExit('signup language switch anchor not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

print('fixed current iOS analyzer errors')
