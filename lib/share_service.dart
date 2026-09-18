// services/share_service.dart
import 'package:intl/intl.dart';


class ShareService {
  static Future<String> shareProduct(Map<String, dynamic> product) async {
    final String productId = product['id'] ?? '';
    final String productName = product['product_name'] ?? 'ទំនិញថ្មី';
    final String location = product['location'] ?? 'ភ្នំពេញ';


    String priceString = (product['price'] ?? '0').toString().replaceAll(
      ',',
      '',
    );
    double priceValue = double.tryParse(priceString) ?? 0;
    String price = NumberFormat('#,###').format(priceValue);
    String currency = product['currency']?.toString() ?? '៛';


    return '''
🛍️ $productName
💰 តម្លៃ៖ $price $currency
📍 $location


🔗 មើលទំនិញក្នុង App៖
https://sesanshop.com/product/$productId


📲 មិនទាន់មាន App? ទាញយកទីនេះ៖
https://play.google.com/store/apps/details?id=com.sesan.app''';
  }


  static Future<String> shareShop({
    required String sellerId,
    required String sellerName,
    String? sesanId,
  }) async {
    return '''
🏪 $sellerName
${sesanId != null ? '🆔 Sesan ID: $sesanId\n' : ''}
🔗 មើលហាងក្នុង App៖
https://sesanshop.com/shop/$sellerId


📲 មិនទាន់មាន App? ទាញយកទីនេះ៖
Android: https://play.google.com/store/apps/details?id=com.sesan.app
iOS: https://apps.apple.com/app/sesan-app/idXXXXXXXXXX''';
  }
}



