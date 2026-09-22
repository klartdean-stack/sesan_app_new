import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'marketplace_analytics_service.dart';

class ProductDetailMarketplaceActions {
  ProductDetailMarketplaceActions({
    required this.product,
    required this.currentUserId,
  });

  final Map<String, dynamic> product;
  final String? currentUserId;

  String get buyerId =>
      currentUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
  String get sellerId => (product['seller_id'] ?? '').toString();
  String get productId => (product['id'] ?? '').toString();

  Future<void> logPhoneReveal() => MarketplaceAnalyticsService.logEvent(
        type: 'phone_reveal',
        buyerId: buyerId,
        sellerId: sellerId,
        productId: productId,
        source: 'product_detail',
      );

  Future<void> logSellerChat() => MarketplaceAnalyticsService.logEvent(
        type: 'chat_seller',
        buyerId: buyerId,
        sellerId: sellerId,
        productId: productId,
        source: 'product_detail',
      );

  Future<void> logAddToCart() => MarketplaceAnalyticsService.logEvent(
        type: 'add_to_cart',
        buyerId: buyerId,
        sellerId: sellerId,
        productId: productId,
        source: 'product_detail',
      );
}

class SellerPhonePrivacyTile extends StatefulWidget {
  const SellerPhonePrivacyTile({
    super.key,
    required this.phone,
    required this.onReveal,
    this.secondary = false,
  });

  final String phone;
  final Future<void> Function() onReveal;
  final bool secondary;

  @override
  State<SellerPhonePrivacyTile> createState() =>
      _SellerPhonePrivacyTileState();
}

class _SellerPhonePrivacyTileState extends State<SellerPhonePrivacyTile> {
  bool _revealed = false;
  Timer? _hideTimer;

  String _mask(String phone) {
    final value = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (value.isEmpty) return '';
    if (value.length <= 3) return 'XXX';
    return '${value.substring(0, value.length - 3)}XXX';
  }

  Future<void> _reveal() async {
    if (widget.phone.trim().isEmpty) return;
    _hideTimer?.cancel();
    if (mounted) setState(() => _revealed = true);
    await widget.onReveal();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _revealed = false);
    });
  }

  void _hide() {
    _hideTimer?.cancel();
    if (mounted) setState(() => _revealed = false);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.phone.trim();
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final shown = phone.isEmpty
        ? (isEnglish ? 'No phone number' : 'អត់មានលេខ')
        : (_revealed ? phone : _mask(phone));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 34,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                widget.secondary ? Icons.phone_android : Icons.phone,
                color: Colors.orange,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    shown,
                    key: ValueKey<String>(shown),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (phone.isNotEmpty)
                  Text(
                    _revealed
                        ? (isEnglish
                            ? 'Hidden again automatically in 5 seconds'
                            : 'លេខនឹងលាក់វិញដោយស្វ័យប្រវត្តិក្នុង 5 វិនាទី')
                        : (isEnglish
                            ? 'Chat or order through the Sesan cart'
                            : 'សូមឆាត ឬទិញតាមកន្ត្រកក្នុង Sesan'),
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'Siemreap',
                    ),
                  ),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: _revealed ? _hide : _reveal,
                icon: Icon(
                  _revealed ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                tooltip: _revealed
                    ? (isEnglish ? 'Hide' : 'លាក់លេខ')
                    : (isEnglish ? 'Show number' : 'បង្ហាញលេខ'),
              ),
            ),
        ],
      ),
    );
  }
}
