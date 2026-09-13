from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if new in text:
        print(f'{label}: already applied')
        return
    if old not in text:
        raise SystemExit(f'{label}: anchor not found in {path}')
    text = text.replace(old, new, 1)
    p.write_text(text, encoding='utf-8')
    print(f'{label}: applied')


# 1) Cart checkout total contrast (Android Build 46 parity)
replace_once(
    'lib/cart_screen.dart',
    "style: const TextStyle(color: Colors.red),",
    "style: const TextStyle(color: Colors.white),",
    'cart total contrast',
)

# 2) Auction creation: collapse 3 steps into 2 steps.
replace_once(
    'lib/auction_add_screen.dart',
    """  bool get _step2Valid => _selectedPackage != null;\n\n\n  void _nextStep() {\n    if (_currentStep == 0 && !_step0Valid) {\n      _showErrorSnack('សូមបំពេញឈ្មោះទំនិញ និងរូបភាព');\n      return;\n    }\n    if (_currentStep == 1 && !_step1Valid) {\n      _showErrorSnack('សូមបំពេញតម្លៃ និងថ្ងៃបញ្ចប់');\n      return;\n    }\n    if (_currentStep == 2 && !_step2Valid) {\n      _showErrorSnack('សូមជ្រើសរើសកញ្ចប់សេវា');\n      return;\n    }\n    if (_currentStep < 2) {\n      setState(() => _currentStep++);\n      _fadeCtrl\n        ..reset()\n        ..forward();\n    } else {\n      _showPaymentDialog();\n    }\n  }\n""",
    """  void _nextStep() {\n    if (_currentStep == 0 && !_step0Valid) {\n      _showErrorSnack('សូមបំពេញឈ្មោះទំនិញ និងរូបភាព');\n      return;\n    }\n    if (_currentStep == 1 && !_step1Valid) {\n      _showErrorSnack('សូមបំពេញតម្លៃ និងថ្ងៃបញ្ចប់');\n      return;\n    }\n    if (_currentStep == 1 && _selectedPackage == null) {\n      _showErrorSnack('សូមជ្រើសរើសកញ្ចប់សេវា');\n      return;\n    }\n    if (_currentStep == 0) {\n      setState(() => _currentStep = 1);\n      _fadeCtrl\n        ..reset()\n        ..forward();\n    } else {\n      _showPaymentDialog();\n    }\n  }\n""",
    'auction two-step navigation',
)

replace_once(
    'lib/auction_add_screen.dart',
    "final steps = ['ទំនិញ', 'តម្លៃ', 'សេវា'];",
    "final steps = ['ទំនិញ', 'តម្លៃ និងសេវា'];",
    'auction two-step indicator',
)

replace_once(
    'lib/auction_add_screen.dart',
    """      case 1:\n        return _buildStep1();\n      case 2:\n        return _buildStep2();\n""",
    """      case 1:\n        return Column(\n          children: [\n            _buildStep1(),\n            _buildStep2(),\n          ],\n        );\n""",
    'auction combine price and service',
)

replace_once(
    'lib/auction_add_screen.dart',
    "hint: 'ឧ. រទេះគោសាឡី',",
    "hint: Get.locale?.languageCode == 'km' ? 'ឧ. ម៉ាស៊ីនច្រូតស្រូវ' : 'e.g. Rice harvester',",
    'auction product example',
)

replace_once(
    'lib/auction_add_screen.dart',
    """          icon: Icons.description_outlined,\n          maxLines: 4,\n""",
    """          icon: Icons.description_outlined,\n          keyboard: TextInputType.multiline,\n          textInputAction: TextInputAction.newline,\n          maxLines: 4,\n""",
    'auction multiline description',
)

replace_once(
    'lib/auction_add_screen.dart',
    "_currentStep == 2 ? 'បន្តការបង់ប្រាក់' : 'បន្ទាប់',",
    "_currentStep == 1 ? 'បន្តការបង់ប្រាក់' : 'បន្ទាប់',",
    'auction payment button step',
)

replace_once(
    'lib/auction_add_screen.dart',
    """    int maxLines = 1,\n    String? Function(String?)? validator,\n""",
    """    int maxLines = 1,\n    TextInputAction? textInputAction,\n    String? Function(String?)? validator,\n""",
    'auction textInputAction parameter',
)

replace_once(
    'lib/auction_add_screen.dart',
    """      keyboardType: keyboard,\n      maxLines: maxLines,\n""",
    """      keyboardType: keyboard,\n      textInputAction: textInputAction,\n      maxLines: maxLines,\n""",
    'auction textInputAction wiring',
)

print('iOS Android 46 parity batch 1 complete')
