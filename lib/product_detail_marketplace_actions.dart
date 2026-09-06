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

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        widget.secondary ? Icons.phone_android : Icons.phone,
        color: Colors.orange,
      ),
      title: Text(shown),
      subtitle: phone.isEmpty
          ? null
          : Text(
              _revealed
                  ? (isEnglish
                      ? 'Hidden again automatically in 5 seconds'
                      : 'លេខនឹងលាក់វិញដោយស្វ័យប្រវត្តិក្នុង 5 វិនាទី')
                  : (isEnglish
                      ? 'Chat or order through the Sesan cart'
                      : 'សូមឆាត ឬទិញតាមកន្ត្រកក្នុង Sesan'),
              style: const TextStyle(fontSize: 11, fontFamily: 'Siemreap'),
            ),
      trailing: phone.isEmpty
          ? null
          : TextButton.icon(
              onPressed: _revealed ? null : _reveal,
              icon: Icon(
                _revealed ? Icons.visibility_off_outlined : Icons.visibility,
                size: 17,
              ),
              label: Text(
                _revealed
                    ? (isEnglish ? 'Shown' : 'បានបង្ហាញ')
                    : (isEnglish ? 'Show number' : 'បង្ហាញលេខ'),
                style: const TextStyle(fontSize: 11, fontFamily: 'Siemreap'),
              ),
            ),
    );
  }
}
