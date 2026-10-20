from pathlib import Path
import re


def patch_product_share() -> None:
    path = Path('lib/product_detail.dart')
    text = path.read_text(encoding='utf-8')

    if 'Future<void> _shareProductWithWatermark()' in text:
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
            raise RuntimeError(f'Product share block replacement failed: {count}')

    text = text.replace(
        '_shareProductWithWatermark(); // ✅ ហៅ method ថ្មី',
        '_shareProduct();',
        1,
    )
    text = text.replace(
        "'ផ្ញើរូបភាពមាន QR Code និង Link',\n                    'Send an image with QR code and link',",
        "'ចែករំលែក Link ទំនិញ',\n                    'Share the product link',",
        1,
    )

    if 'Future<void> _shareProduct()' not in text:
        raise RuntimeError('New product share method is missing')
    if 'sharePositionOrigin: _sharePositionOrigin()' not in text:
        raise RuntimeError('iOS share source rect is missing')

    path.write_text(text, encoding='utf-8')


def patch_product_list_search() -> None:
    path = Path('lib/product_list.dart')
    text = path.read_text(encoding='utf-8')

    if "import 'product_search_v51.dart';" not in text:
        text = text.replace(
            "import 'product_detail.dart';\n",
            "import 'product_detail.dart';\nimport 'product_search_v51.dart';\n",
            1,
        )

    controller_anchor = "  final TextEditingController _searchController = TextEditingController();\n"
    if 'ProductSearchV51Controller? _searchAiController;' not in text:
        controller_block = controller_anchor + r'''  ProductSearchV51Controller? _searchAiController;

  ProductSearchV51Controller get _searchAi =>
      _searchAiController ??= ProductSearchV51Controller(
        context,
        onStateChanged: () {
          if (mounted) setState(() {});
        },
      );
'''
        if controller_anchor not in text:
            raise RuntimeError('Search controller anchor not found')
        text = text.replace(controller_anchor, controller_block, 1)

    if 'Future<void> _applyHomeStyleSearchResult' not in text:
        methods = r'''
  Future<void> _applyHomeStyleSearchResult(String value) async {
    if (!mounted || value.trim().isEmpty) return;
    final primary = value.split('|').first.trim();
    _searchController.text = primary;
    _searchController.selection = TextSelection.collapsed(offset: primary.length);
    setState(() => _currentSearch = value.toLowerCase());
  }

  Future<void> _smartScanLikeHome() async {
    if (_searchAiController?.busy == true) return;

    final image = await Navigator.push<XFile?>(
      context,
      MaterialPageRoute(builder: (_) => const SmartScanScreen()),
    );
    if (image == null || !mounted) return;

    final result = await _searchAi.searchSelectedImage(image);
    if (result != null) {
      await _applyHomeStyleSearchResult(result);
    }
    if (mounted) setState(() {});
  }

  Future<void> _voiceSearchLikeHome() async {
    final ai = _searchAi;
    if (ai.recording || ai.busy) return;

    await ai.startVoice(onResult: _applyHomeStyleSearchResult);
    if (mounted) setState(() {});
  }

'''
        anchor = '  Future<void> _showLocationFilter() async {'
        if anchor not in text:
            raise RuntimeError('Location filter anchor not found')
        text = text.replace(anchor, methods + anchor, 1)

    old_shell = '''                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),'''
    new_shell = '''                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),'''
    if old_shell in text:
        text = text.replace(old_shell, new_shell, 1)

    text = text.replace(
        "                      hintStyle: const TextStyle(fontFamily: 'Siemreap', fontSize: 12),",
        "                      hintStyle: const TextStyle(fontFamily: 'Siemreap', fontSize: 13),",
        1,
    )
    text = text.replace(
        '                      suffixIconConstraints: const BoxConstraints.tightFor(width: 94, height: 45),',
        '                      suffixIconConstraints: const BoxConstraints.tightFor(width: 96, height: 48),',
        1,
    )

    if '_smartScanLikeHome' in text and 'Icons.image_search_rounded' in text:
        suffix_pattern = re.compile(
            r"                      suffixIcon: Row\(\n.*?                      \),\n                      border: InputBorder.none,",
            re.S,
        )
        suffix_replacement = r'''                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: InkResponse(
                              radius: 24,
                              onTap: _searchAiController?.busy == true
                                  ? null
                                  : _smartScanLikeHome,
                              child: Center(
                                child: _searchAiController?.busy == true
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(
                                        Icons.center_focus_strong_rounded,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: InkResponse(
                              radius: 24,
                              onTap: (_searchAiController?.busy == true ||
                                      _searchAiController?.recording == true)
                                  ? null
                                  : _voiceSearchLikeHome,
                              child: Center(
                                child: Icon(
                                  Icons.mic_rounded,
                                  color: _searchAiController?.recording == true
                                      ? Colors.red
                                      : Colors.green,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      border: InputBorder.none,'''
        text, count = suffix_pattern.subn(suffix_replacement, text, count=1)
        if count != 1:
            raise RuntimeError(f'Search suffix replacement failed: {count}')

    text = text.replace(
        '                      contentPadding: const EdgeInsets.symmetric(vertical: 10),',
        '                      contentPadding: const EdgeInsets.symmetric(vertical: 9),',
        1,
    )

    dispose_anchor = '''    _searchController.dispose();
    _searchAudioRecorder.dispose();'''
    if dispose_anchor in text and '_searchAiController?.dispose();' not in text:
        text = text.replace(
            dispose_anchor,
            '''    _searchController.dispose();
    _searchAiController?.dispose();
    _searchAudioRecorder.dispose();''',
            1,
        )

    required = [
        'ProductSearchV51Controller',
        '_smartScanLikeHome',
        '_voiceSearchLikeHome',
        'Icons.center_focus_strong_rounded',
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f'Missing list-search marker: {marker}')

    path.write_text(text, encoding='utf-8')


def patch_auction_media_order() -> None:
    path = Path('lib/auction_detail_screen.dart')
    text = path.read_text(encoding='utf-8')

    old_media = '''                        List<Map<String, dynamic>> mediaItems = [];
                        if (videoUrl.isNotEmpty) mediaItems.add({'type': 'video', 'url': videoUrl});
                        for (var img in images) {
                          mediaItems.add({'type': 'image', 'url': img.toString()});
                        }'''
    new_media = '''                        final List<Map<String, dynamic>> mediaItems = [];
                        for (final img in images) {
                          mediaItems.add({
                            'type': 'image',
                            'url': img.toString(),
                          });
                        }
                        if (videoUrl.isNotEmpty) {
                          mediaItems.add({'type': 'video', 'url': videoUrl});
                        }'''

    if old_media in text:
        text = text.replace(old_media, new_media, 1)

    text = text.replace(
        'final isVideo = videoUrl.isNotEmpty && i == 0;',
        'final isVideo = videoUrl.isNotEmpty && i == totalItems - 1;',
        1,
    )

    if "i == totalItems - 1" not in text:
        raise RuntimeError('Auction video indicator was not moved to the last page')

    path.write_text(text, encoding='utf-8')


def bump_build_66() -> None:
    path = Path('pubspec.yaml')
    text = path.read_text(encoding='utf-8')
    if 'version: 1.1.3+65' in text:
        text = text.replace('version: 1.1.3+65', 'version: 1.1.3+66', 1)
    elif 'version: 1.1.3+66' not in text:
        raise RuntimeError('Unexpected pubspec version; expected 1.1.3+65 or 1.1.3+66')
    path.write_text(text, encoding='utf-8')


def main() -> None:
    patch_product_share()
    patch_product_list_search()
    patch_auction_media_order()
    bump_build_66()
    print('OK: iOS parity fixes applied')
    print(' - Product share: canonical Sesan product link + iOS source rect')
    print(' - Product list search: Home Smart Scan + Home voice controller/UI')
    print(' - Auction detail: images first, video last')
    print(' - Version: 1.1.3+66')


if __name__ == '__main__':
    main()
