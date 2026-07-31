import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadHelper {
  static Future<void> saveQRImage(String imageUrl) async {
    try {
      // ១. ទាញយករូបភាពពី Link មកទុកជា File បណ្ដោះអាសន្ន
      String tempPath = (await getTemporaryDirectory()).path;
      String filePath = '$tempPath/khqr_payment.png';

      await Dio().download(imageUrl, filePath);

      // ២. Save ចូលក្នុង Gallery ទូរស័ព្ទ
      await Gal.putImage(filePath);

      print("រក្សាទុករូបភាពជោគជ័យ!");
    } catch (e) {
      print("Error saving image: $e");
      rethrow; // បោះ Error ទៅខាងក្រៅដើម្បីឱ្យអេក្រង់បង្ហាញ SnackBar
    }
  }
}
