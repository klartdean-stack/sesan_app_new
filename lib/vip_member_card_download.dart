import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Android V51 parity helper for exporting the visible SESAN VIP member card.
/// Wrap the card with [VipMemberCardDownload] and use the built-in download button.
class VipMemberCardDownload extends StatefulWidget {
  final Widget card;

  const VipMemberCardDownload({super.key, required this.card});

  @override
  State<VipMemberCardDownload> createState() => _VipMemberCardDownloadState();
}

class _VipMemberCardDownloadState extends State<VipMemberCardDownload> {
  final GlobalKey _cardKey = GlobalKey();
  bool _saving = false;

  Future<void> _saveCard() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('VIP member card is not ready');
      }

      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }
      if (!await Gal.hasAccess()) {
        throw Exception('Gallery permission denied');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Unable to create VIP member card image');
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/sesan_vip_member_card_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      await Gal.putImage(file.path);

      if (!mounted) return;
      final en = Localizations.localeOf(context).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            en
                ? 'Sesan VIP member card saved to Gallery.'
                : 'បានរក្សាកាតសមាជិក SESAN VIP ទៅ Gallery រួចរាល់។',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final en = Localizations.localeOf(context).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            en
                ? 'Could not save the VIP member card: $e'
                : 'មិនអាចរក្សាកាតសមាជិក VIP បានទេ៖ $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final en = Localizations.localeOf(context).languageCode == 'en';
    return Column(
      children: [
        RepaintBoundary(key: _cardKey, child: widget.card),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _saveCard,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 20),
            label: Text(
              en
                  ? 'Download my Sesan VIP member card'
                  : 'ទាញយកកាតសមាជិក SESAN VIP របស់ខ្ញុំ',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Siemreap',
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFFB300),
              side: const BorderSide(color: Color(0xFFFFB300)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
