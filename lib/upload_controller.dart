import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // ✅ បន្ថែម
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
// ✅ wrap imports ដែល Web មិន support
import 'package:flutter_image_compress/flutter_image_compress.dart'
if (dart.library.html) 'web_stub.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_compress/video_compress.dart'
if (dart.library.html) 'web_stub.dart';


class UploadController extends GetxController {
  var isUploading = false.obs;
  var uploadProgress = 0.0.obs;


  Future<File?> _compressImage(File file) async {
    // ✅ skip compression នៅ Web
    if (kIsWeb) return file;
    try {
      final filePath = file.absolute.path;
      final lastIndex = filePath.lastIndexOf('.');
      final outPath =
          '${filePath.substring(0, lastIndex)}_${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
      var result = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );
      return result != null ? File(result.path) : file;
    } catch (e) {
      return file;
    }
  }


  Future<File?> _compressVideo(File file) async {
    // ✅ skip compression នៅ Web
    if (kIsWeb) return file;
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,  // ប្ដូរពី LowQuality
        deleteOrigin: false,
        includeAudio: true,
      );
      return info?.file;
    } catch (e) {
      VideoCompress.cancelCompression();
      return null;
    }
  }


  Future<void> startBackgroundUpload({
    required String? productId,
    required Map<String, dynamic> formData,
    required List<XFile> selectedImages,
    XFile? selectedVideo,
  }) async {
    if (isUploading.value) return;
    isUploading.value = true;
    uploadProgress.value = 0.05;


    try {
      List<String> imageUrls = [];
      String? videoUrl;


      // ✅ ទាញ seller info — Web ប្រើ FirebaseAuth ឬ SharedPreferences
      String currentUserName = 'មិនមានឈ្មោះ';
      String currentUserPhoto = '';
      String? currentUid;


      if (kIsWeb) {
        // Web: ប្រើ FirebaseAuth
        final user = FirebaseAuth.instance.currentUser;
        currentUid = user?.uid;
      } else {
        // Mobile: ប្រើ SharedPreferences
        final prefs = await _getPrefs();
        currentUid = prefs['user_uid'];
        currentUserName = prefs['user_name'] ?? 'មិនមានឈ្មោះ';
        currentUserPhoto = prefs['user_photo'] ?? '';
      }


      if (currentUid != null && currentUid.isNotEmpty) {
        try {
          var userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .get();
          if (userDoc.exists) {
            currentUserName = userDoc.data()?['name'] ?? currentUserName;
            currentUserPhoto = userDoc.data()?['photoUrl'] ?? currentUserPhoto;
          }
        } catch (e) {
          debugPrint('Fetch user error: $e');
        }
      }


      // Upload images
      for (int i = 0; i < selectedImages.length; i++) {
        String fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${selectedImages[i].name}';
        Reference ref = FirebaseStorage.instance.ref().child(
          'products/images/$fileName',
        );


        if (kIsWeb) {
          // ✅ Web ប្រើ putData
          final bytes = await selectedImages[i].readAsBytes();
          await ref.putData(bytes);
        } else {
          File fileToUpload = File(selectedImages[i].path);
          File? compressed = await _compressImage(fileToUpload);
          await ref.putFile(compressed ?? fileToUpload);
        }


        imageUrls.add(await ref.getDownloadURL());
        uploadProgress.value = 0.1 + ((i + 1) / selectedImages.length * 0.5);
      }
      // Upload video
      if (selectedVideo != null) {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}_video.mp4';
        Reference ref = FirebaseStorage.instance.ref().child(
          'products/videos/$fileName',
        );


        if (kIsWeb) {
          // ✅ Web ប្រើ putData
          final bytes = await selectedVideo.readAsBytes();
          await ref.putData(bytes);
        } else {
          File fileToUpload = File(selectedVideo.path);
          File? compressed = await _compressVideo(fileToUpload);
          await ref.putFile(compressed ?? fileToUpload);
          await VideoCompress.deleteAllCache();
        }


        videoUrl = await ref.getDownloadURL();
        uploadProgress.value = 0.9;
      }


      Map<String, dynamic> finalData = {
        'seller_id': formData['seller_id'] ?? currentUid ?? 'UNKNOWN',
        'seller_name': formData['seller_name'] ?? currentUserName,
        'seller_photo': formData['seller_photo'] ?? currentUserPhoto,
        'product_name': formData['product_name'],
        'description': formData['description'],
        'price': formData['price'],
        'phone1': formData['phone1'],
        'phone2': formData['phone2'],
        'seller_phone': formData['phone1'],
        'location': formData['location'],
        'category': formData['category'],
        'sub_category': formData['sub_category'] ?? 'ទាំងអស់', // ✅ បន្ថែម
        'sub_sub_category':
        formData['sub_sub_category'] ?? 'ទាំងអស់', // ✅ បន្ថែម
        'currency': formData['currency'],
        'shipping_included':
        formData['shipping_included'], // ✅ បញ្ចូលថាតើបូកថ្លៃផ្ញើឬអត់
        'lat': formData['lat'],
        'lng': formData['lng'],
        'image_urls': imageUrls,
        'video_url': videoUrl,
        'updated_at': FieldValue.serverTimestamp(),
      };


      if (productId == null) {
        finalData['created_at'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('products').add(finalData);
      } else {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .update(finalData);
      }


      uploadProgress.value = 1.0;


      Get.snackbar(
        '🎉 រក្សាទុកជោគជ័យ!',
        "ទំនិញ '${finalData['product_name']}' ត្រូវបានដាក់លក់ហើយ!",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      uploadProgress.value = 0.0;
      debugPrint('Upload error: $e');
      Get.snackbar(
        '❌ បរាជ័យ',
        'ការបង្ហោះមានបញ្ហា៖ $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isUploading.value = false;
      Future.delayed(
        const Duration(seconds: 3),
            () => uploadProgress.value = 0.0,
      );
    }
  }


  // ✅ helper ទាញ SharedPreferences (Mobile only)
  Future<Map<String, String?>> _getPrefs() async {
    if (kIsWeb) return {};
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return {
        'user_uid': prefs.getString('user_uid'),
        'user_name': prefs.getString('user_name'),
        'user_photo': prefs.getString('user_photo'),
      };
    } catch (e) {
      return {};
    }
  }
}



