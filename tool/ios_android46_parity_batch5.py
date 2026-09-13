from pathlib import Path


def replace_once(path, old, new, marker, label):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if marker in text:
        print(f'{label}: already applied')
        return
    if old not in text:
        raise SystemExit(f'{label}: anchor not found in {path}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')
    print(f'{label}: applied')


# Auction date/time pickers: Android 46 uses a light picker so dates remain readable.
replace_once(
    'lib/auction_add_screen.dart',
    '''        data: ThemeData.dark().copyWith(\n          colorScheme: const ColorScheme.dark(\n            primary: _accentBlue,\n            surface: _card,\n          ),\n        ),''',
    '''        data: ThemeData.light().copyWith(\n          colorScheme: const ColorScheme.light(\n            primary: _accent,\n            onPrimary: Colors.white,\n            surface: Colors.white,\n            onSurface: _text,\n          ),\n        ),''',
    'onPrimary: Colors.white',
    'auction date picker visibility',
)

# The same dark block occurs a second time for time picker.
p = Path('lib/auction_add_screen.dart')
text = p.read_text(encoding='utf-8')
old = '''        data: ThemeData.dark().copyWith(\n          colorScheme: const ColorScheme.dark(\n            primary: _accentBlue,\n            surface: _card,\n          ),\n        ),'''
new = '''        data: ThemeData.light().copyWith(\n          colorScheme: const ColorScheme.light(\n            primary: _accent,\n            onPrimary: Colors.white,\n            surface: Colors.white,\n            onSurface: _text,\n          ),\n        ),'''
if old in text:
    text = text.replace(old, new, 1)
p.write_text(text, encoding='utf-8')
print('auction time picker visibility: applied')

# Simplify image picker panel where the older iOS UI still uses the tall empty state.
p = Path('lib/auction_add_screen.dart')
text = p.read_text(encoding='utf-8')
text = text.replace(
    'height: _productImages.isEmpty ? 140 : 120,',
    'height: 120,',
    1,
)
# Remove the optional explanatory note if this baseline contains it.
text = text.replace(
    """                  const SizedBox(height: 4),\n                  Text(\n                    'auction_images_note'.tr,\n                    style: TextStyle(color: _textMuted, fontSize: 12),\n                  ),\n""",
    '',
    1,
)
p.write_text(text, encoding='utf-8')
print('auction image picker compacted')

# Seller phone reveal should only rebuild the phone widget, not the full page.
p = Path('lib/seller_profile_screen.dart')
text = p.read_text(encoding='utf-8')
if 'final ValueNotifier<bool> _showSellerPhoneNotifier' not in text:
    text = text.replace(
        '  bool _showSellerPhone = false;\n',
        '  final ValueNotifier<bool> _showSellerPhoneNotifier = ValueNotifier<bool>(false);\n',
        1,
    )

# Add dispose if the class currently has no dispose override near initState.
if '_showSellerPhoneNotifier.dispose();' not in text:
    anchor = '''  @override\n  void initState() {\n    super.initState();\n    _loadUserId();\n  }\n\n'''
    addition = '''  @override\n  void dispose() {\n    _showSellerPhoneNotifier.dispose();\n    super.dispose();\n  }\n\n'''
    if anchor not in text:
        raise SystemExit('seller initState anchor not found')
    text = text.replace(anchor, anchor + addition, 1)

old_phone = '''                              child: Row(\n                                children: [\n                                  Icon(Icons.phone, color: Colors.green[700], size: 14),\n                                  const SizedBox(width: 4),\n                                  Expanded(\n                                    child: Text(\n                                      _showSellerPhone\n                                          ? phone\n                                          : _maskSellerPhoneForDisplay(phone),\n                                      maxLines: 1,\n                                      overflow: TextOverflow.ellipsis,\n                                      style: TextStyle(\n                                        color: Colors.green[800],\n                                        fontWeight: FontWeight.bold,\n                                        fontSize: 11,\n                                      ),\n                                    ),\n                                  ),\n                                  IconButton(\n                                    onPressed: () => setState(\n                                      () => _showSellerPhone = !_showSellerPhone,\n                                    ),\n                                    icon: Icon(\n                                      _showSellerPhone\n                                          ? Icons.visibility_off\n                                          : Icons.visibility,\n                                      size: 15,\n                                    ),\n                                    tooltip: _showSellerPhone ? 'លាក់លេខ' : 'បង្ហាញលេខ',\n                                    padding: EdgeInsets.zero,\n                                    constraints: const BoxConstraints(\n                                      minWidth: 28,\n                                      minHeight: 28,\n                                    ),\n                                    visualDensity: VisualDensity.compact,\n                                  ),\n                                ],\n                              ),'''
new_phone = '''                              child: ValueListenableBuilder<bool>(\n                                valueListenable: _showSellerPhoneNotifier,\n                                builder: (context, showPhone, _) => Row(\n                                  children: [\n                                    Icon(Icons.phone, color: Colors.green[700], size: 14),\n                                    const SizedBox(width: 4),\n                                    Expanded(\n                                      child: Text(\n                                        showPhone\n                                            ? phone\n                                            : _maskSellerPhoneForDisplay(phone),\n                                        maxLines: 1,\n                                        overflow: TextOverflow.ellipsis,\n                                        style: TextStyle(\n                                          color: Colors.green[800],\n                                          fontWeight: FontWeight.bold,\n                                          fontSize: 11,\n                                        ),\n                                      ),\n                                    ),\n                                    IconButton(\n                                      onPressed: () =>\n                                          _showSellerPhoneNotifier.value = !showPhone,\n                                      icon: Icon(\n                                        showPhone\n                                            ? Icons.visibility_off\n                                            : Icons.visibility,\n                                        size: 15,\n                                      ),\n                                      tooltip: showPhone ? 'លាក់លេខ' : 'បង្ហាញលេខ',\n                                      padding: EdgeInsets.zero,\n                                      constraints: const BoxConstraints(\n                                        minWidth: 28,\n                                        minHeight: 28,\n                                      ),\n                                      visualDensity: VisualDensity.compact,\n                                    ),\n                                  ],\n                                ),\n                              ),'''
if 'valueListenable: _showSellerPhoneNotifier' not in text:
    if old_phone not in text:
        raise SystemExit('seller phone control anchor not found')
    text = text.replace(old_phone, new_phone, 1)

p.write_text(text, encoding='utf-8')
print('seller phone reveal optimized')
print('iOS Android 46 parity batch 5 complete')
