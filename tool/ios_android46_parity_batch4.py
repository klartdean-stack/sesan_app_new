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


def insert_before(path, anchor, addition, marker, label):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if marker in text:
        print(f'{label}: already applied')
        return
    if anchor not in text:
        raise SystemExit(f'{label}: anchor not found in {path}')
    p.write_text(text.replace(anchor, addition + anchor, 1), encoding='utf-8')
    print(f'{label}: applied')


top_message_auction = '''  // Android Build 46 parity: QR result above payment dialog\n  void _showTopMessage(String message, {bool isError = false}) {\n    final overlay = Overlay.of(context, rootOverlay: true);\n    late final OverlayEntry entry;\n    entry = OverlayEntry(\n      builder: (overlayContext) => Positioned(\n        top: MediaQuery.of(overlayContext).padding.top + 12,\n        left: 16,\n        right: 16,\n        child: Material(\n          color: Colors.transparent,\n          child: Container(\n            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),\n            decoration: BoxDecoration(\n              color: isError ? const Color(0xFFDA3633) : const Color(0xFF238636),\n              borderRadius: BorderRadius.circular(14),\n              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],\n            ),\n            child: Row(\n              children: [\n                Icon(\n                  isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,\n                  color: Colors.white,\n                  size: 21,\n                ),\n                const SizedBox(width: 10),\n                Expanded(\n                  child: Text(\n                    message,\n                    style: const TextStyle(\n                      color: Colors.white,\n                      fontFamily: 'Siemreap',\n                      fontWeight: FontWeight.w600,\n                      fontSize: 13,\n                    ),\n                  ),\n                ),\n              ],\n            ),\n          ),\n        ),\n      ),\n    );\n    overlay.insert(entry);\n    Future.delayed(const Duration(seconds: 3), () {\n      if (entry.mounted) entry.remove();\n    });\n  }\n\n'''

insert_before(
    'lib/auction_add_screen.dart',
    '  Future<void> _downloadQR() async {\n',
    top_message_auction,
    'Android Build 46 parity: QR result above payment dialog',
    'auction top overlay',
)

replace_once(
    'lib/auction_add_screen.dart',
    '''  Future<void> _downloadQR() async {\n    try {\n      final byteData = await rootBundle.load('assets/aba_qr.png');\n      final tempDir = await getTemporaryDirectory();\n      final file = File('${tempDir.path}/aba_qr_download.png');\n      await file.writeAsBytes(\n        byteData.buffer.asUint8List(\n          byteData.offsetInBytes,\n          byteData.lengthInBytes,\n        ),\n      );\n      await Gal.putImage(file.path);\n      _showSuccessSnack('✅ បានរក្សាទុកក្នុង Gallery រួចរាល់!');\n    } catch (e) {\n      _showErrorSnack('❌ មិនអាចរក្សាទុកបាន: $e');\n    }\n  }\n''',
    '''  Future<void> _downloadQR() async {\n    try {\n      if (!await Gal.hasAccess()) {\n        await Gal.requestAccess();\n      }\n      if (!await Gal.hasAccess()) {\n        throw Exception('Gallery permission denied');\n      }\n      final byteData = await rootBundle.load('assets/aba_qr.png');\n      final tempDir = await getTemporaryDirectory();\n      final file = File('${tempDir.path}/aba_qr_download.png');\n      await file.writeAsBytes(\n        byteData.buffer.asUint8List(\n          byteData.offsetInBytes,\n          byteData.lengthInBytes,\n        ),\n      );\n      await Gal.putImage(file.path);\n      if (!mounted) return;\n      _showTopMessage('✅ បានរក្សាទុកក្នុង Gallery រួចរាល់!');\n    } catch (e) {\n      if (!mounted) return;\n      _showTopMessage('❌ មិនអាចរក្សាទុកបាន: $e', isError: true);\n    }\n  }\n''',
    "throw Exception('Gallery permission denied')",
    'auction gallery permission and overlay',
)

shop_overlay = '''  // Android Build 46 parity: QR result above payment dialog\n  void _showTopMessage(String message, {bool isError = false}) {\n    final overlay = Overlay.of(context, rootOverlay: true);\n    late final OverlayEntry entry;\n    entry = OverlayEntry(\n      builder: (overlayContext) => Positioned(\n        top: MediaQuery.of(overlayContext).padding.top + 12,\n        left: 16,\n        right: 16,\n        child: Material(\n          color: Colors.transparent,\n          child: Container(\n            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),\n            decoration: BoxDecoration(\n              color: isError ? redColor : const Color(0xFF238636),\n              borderRadius: BorderRadius.circular(14),\n              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],\n            ),\n            child: Row(\n              children: [\n                Icon(\n                  isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,\n                  color: Colors.white,\n                  size: 21,\n                ),\n                const SizedBox(width: 10),\n                Expanded(\n                  child: Text(\n                    message,\n                    style: const TextStyle(\n                      color: Colors.white,\n                      fontFamily: 'Siemreap',\n                      fontWeight: FontWeight.w600,\n                      fontSize: 13,\n                    ),\n                  ),\n                ),\n              ],\n            ),\n          ),\n        ),\n      ),\n    );\n    overlay.insert(entry);\n    Future.delayed(const Duration(seconds: 3), () {\n      if (entry.mounted) entry.remove();\n    });\n  }\n\n'''
insert_before(
    'lib/shop_upgrade_screen.dart',
    '  Future<void> _downloadQR(BuildContext rootContext) async {\n',
    shop_overlay,
    'Android Build 46 parity: QR result above payment dialog',
    'shop top overlay',
)

replace_once(
    'lib/shop_upgrade_screen.dart',
    '''  Future<void> _downloadQR(BuildContext rootContext) async {\n    try {\n      final byteData = await rootBundle.load('assets/aba_qr.png');''',
    '''  Future<void> _downloadQR(BuildContext rootContext) async {\n    try {\n      if (!await Gal.hasAccess()) {\n        await Gal.requestAccess();\n      }\n      if (!await Gal.hasAccess()) {\n        throw Exception('សូមអនុញ្ញាតឱ្យ App រក្សាទុករូបភាពក្នុង Gallery');\n      }\n      final byteData = await rootBundle.load('assets/aba_qr.png');''',
    "throw Exception('សូមអនុញ្ញាតឱ្យ App រក្សាទុករូបភាពក្នុង Gallery')",
    'shop gallery permission',
)

p = Path('lib/shop_upgrade_screen.dart')
text = p.read_text(encoding='utf-8')
old_success = '''      ScaffoldMessenger.of(rootContext).showSnackBar(\n        SnackBar(\n          content: const Text('✅ បានរក្សាទុកក្នុង Gallery រួចរាល់!',\n              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),\n          backgroundColor: const Color(0xFF238636),\n          behavior: SnackBarBehavior.floating,\n          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),\n          margin: const EdgeInsets.all(16),\n        ),\n      );'''
if old_success in text:
    text = text.replace(old_success, "      _showTopMessage('✅ បានរក្សាទុកក្នុង Gallery រួចរាល់!');", 1)
old_error = '''      ScaffoldMessenger.of(rootContext).showSnackBar(\n        SnackBar(\n          content: Text('❌ មិនអាចរក្សាទុកបាន: $e',\n              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),\n          backgroundColor: redColor,\n          behavior: SnackBarBehavior.floating,\n          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),\n          margin: const EdgeInsets.all(16),\n        ),\n      );'''
if old_error in text:
    text = text.replace(old_error, "      _showTopMessage('❌ មិនអាចរក្សាទុកបាន: $e', isError: true);", 1)
# Haptic long-press parity.
text = text.replace(
    'onLongPress: () => _downloadQR(rootContext)',
    'onLongPress: () async {\n            await HapticFeedback.mediumImpact();\n            await _downloadQR(rootContext);\n          }',
    1,
)
p.write_text(text, encoding='utf-8')
print('shop QR feedback: applied')

print('iOS Android 46 payment QR parity batch complete')
