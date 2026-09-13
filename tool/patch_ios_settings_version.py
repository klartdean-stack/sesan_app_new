from pathlib import Path

settings_path = Path('lib/settings_screen.dart')
text = settings_path.read_text(encoding='utf-8')

if "package:package_info_plus/package_info_plus.dart" not in text:
    text = text.replace(
        "import 'package:shared_preferences/shared_preferences.dart';\n",
        "import 'package:shared_preferences/shared_preferences.dart';\nimport 'package:package_info_plus/package_info_plus.dart';\n",
        1,
    )

text = text.replace(
    "  static const String _appVersion = '1.0.0';\n  static const String _buildNumber = '54';",
    "  String _appVersion = '';\n  String _buildNumber = '';",
    1,
)

if '_loadAppVersion();' not in text:
    text = text.replace(
        "    _loadSettings();\n  }",
        "    _loadSettings();\n    _loadAppVersion();\n  }\n\n  Future<void> _loadAppVersion() async {\n    final packageInfo = await PackageInfo.fromPlatform();\n    if (!mounted) return;\n    setState(() {\n      _appVersion = packageInfo.version;\n      _buildNumber = packageInfo.buildNumber;\n    });\n  }",
        1,
    )

settings_path.write_text(text, encoding='utf-8')

pubspec_path = Path('pubspec.yaml')
pubspec = pubspec_path.read_text(encoding='utf-8')
if '  package_info_plus:' not in pubspec:
    pubspec = pubspec.replace(
        '  shared_preferences: ^2.2.3\n',
        '  shared_preferences: ^2.2.3\n  package_info_plus: ^8.0.2\n',
        1,
    )
pubspec_path.write_text(pubspec, encoding='utf-8')
