from pathlib import Path
import re

path = Path('lib/product_detail.dart')
text = path.read_text(encoding='utf-8')

replacement = r'''  Rect _sharePositionOrigin() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.size.width > 0 &&
        renderObject.size.height > 0) {
      final topLeft = renderObject.localToGlobal(Offset.zero);
      return topLeft & renderObject.size;
    }

    final size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(
      size.width / 2,
      size.height / 2,
      1,
      1,
    );
  }

  Future<void> _shareProduct() async {
    final String productId = (widget.product['id'] ?? '').toString().trim();
    if (productId.isEmpty) return;

    final Uri productUri = Uri.parse(
      'https://sesanshop.com/product/$productId',
    );

    // Share one canonical product URL so Facebook/Messenger can build the
    // Open Graph preview. iOS also needs a valid non-zero source rectangle.
    await Share.shareUri(
      productUri,
      sharePositionOrigin: _sharePositionOrigin(),
    );
  }

'''

pattern = re.compile(
    r"  Future<void> _shareProductWithWatermark\(\) async \{.*?\n  \}\n\n  void _showSaveOption",
    re.S,
)
text, count = pattern.subn(replacement + '  void _showSaveOption', text, count=1)
if count != 1:
    raise SystemExit(f'Expected one old share block, replaced {count}')

old_call = '_shareProductWithWatermark(); // ✅ ហៅ method ថ្មី'
if old_call not in text:
    raise SystemExit('Old share callback not found')
text = text.replace(old_call, '_shareProduct();', 1)

old_subtitle = "'ផ្ញើរូបភាពមាន QR Code និង Link',\n                    'Send an image with QR code and link',"
if old_subtitle in text:
    text = text.replace(
        old_subtitle,
        "'ចែករំលែក Link ទំនិញ',\n                    'Share the product link',",
        1,
    )

path.write_text(text, encoding='utf-8')
print('OK: iOS product sharing updated in lib/product_detail.dart')
