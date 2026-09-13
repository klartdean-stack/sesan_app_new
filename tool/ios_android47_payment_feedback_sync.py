from pathlib import Path


def patch_vip():
    p = Path('lib/vip_membership_screen.dart')
    s = p.read_text(encoding='utf-8')
    changed = False

    marker = '// Android47 parity: top payment feedback'
    if marker not in s:
        anchor = '  Future<void> _downloadQR() async {\n'
        if anchor in s:
            helper = '''  // Android47 parity: top payment feedback
  void _showTopMessage(String message, {bool isError = false}) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.of(overlayContext).padding.top + 12,
        left: 16,
        right: 16,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, -24 * (1 - value)),
              child: child,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isError
                    ? const Color(0xFFDA3633)
                    : const Color(0xFF238636),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Siemreap',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

'''
            s = s.replace(anchor, helper + anchor, 1)
            changed = True

    old = '''  Future<void> _downloadQR() async {
    try {
      final byteData = await rootBundle.load('assets/aba_qr.png');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/aba_qr_download.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      await Gal.putImage(file.path);
      _showSnack('✅ បានរក្សាទុកក្នុង Gallery!', isError: false);
    } catch (e) {
      _showSnack('❌ មិនអាចរក្សាទុក: $e', isError: true);
    }
  }
'''
    new = '''  Future<void> _downloadQR() async {
    try {
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }
      if (!await Gal.hasAccess()) {
        throw Exception('Gallery permission denied');
      }
      final byteData = await rootBundle.load('assets/aba_qr.png');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/aba_qr_download.png');
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
      await Gal.putImage(file.path);
      if (!mounted) return;
      _showTopMessage('✅ បានរក្សាទុកក្នុង Gallery!');
    } catch (e) {
      if (!mounted) return;
      _showTopMessage('❌ មិនអាចរក្សាទុក: $e', isError: true);
    }
  }
'''
    if old in s:
        s = s.replace(old, new, 1)
        changed = True

    p.write_text(s, encoding='utf-8')
    print(f'vip payment feedback changed={changed}')


patch_vip()
