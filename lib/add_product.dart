import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:my_app/location_picker.dart';
import 'package:my_app/map_picker_screen.dart';
import 'package:my_app/upload_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'main.dart'; // ដើម្បីឱ្យវាស្គាល់ navigatorKey
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ថែមជួរនេះចូលមេ!
import 'auction_add_screen.dart';
import 'location_data.dart' hide showLocationPicker;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';


class AddProductPage extends StatefulWidget {
  final String? productId;
  final Map<String, dynamic>? initialData;


  const AddProductPage({super.key, this.productId, this.initialData});


  @override
  State<AddProductPage> createState() => _AddProductPageState();
}


class _AddProductPageState extends State<AddProductPage> {
  // --- Controllers ---
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController phone1Controller = TextEditingController();
  final TextEditingController phone2Controller = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  double? selectedLat;
  double? selectedLng;
  bool? _shippingIncluded; // true = បូកថ្លៃផ្ញើ, false = មិនទាន់បូក

  // --- Media Variables ---
  List<XFile> selectedImages = [];
  XFile? selectedVideo;
  final ImagePicker _picker = ImagePicker();
  final formatter = NumberFormat('#,###');
  final UploadController uploadController = Get.put(UploadController());


  String? selectedCategory;
  String? selectedSubCategory; // ✅ បន្ថែមបន្ទាត់នេះ
  String? selectedSubSubCategory; // ✅ បន្ថែមបន្ទាត់នេះ (សម្រាប់ជាន់ទី 3)
  String selectedCurrency = '៛';
  List<String> categories = [
    'គ្រឿងចក្រ',
    'សម្ភារៈកសិកម្ម',
    'ពូជដំណាំ',
    'ពូជសត្វចិញ្ចឹម',
    'ជីនិងថ្នាំ',
    'បន្លែផ្លែឈើ',
    'ត្រីសាច់',
    'សេវាកម្ម',
    'ផ្សេងៗ',
  ];
  // បន្ថែមក្នុង add_product.dart (ជំនួស subCategories ចាស់)
  Map<String, dynamic> subCategories = {
    'គ្រឿងចក្រ': ['ទាំងអស់', 'ថ្មី', 'មួយទឹក', 'កាប់សាច់', 'គ្រឿងបន្លាស់'],


    'សម្ភារៈកសិកម្ម': {
      'ទាំងអស់': [],
      'ម៉ាស៊ីន': ['ទាំងអស់', 'ថ្មី', 'មួយទឹក', 'កាប់សាច់'],
      'ឧបករណ៍': ['ទាំងអស់', 'ថ្មី', 'មួយទឹក', 'កាប់សាច់'],
      'គ្រឿងបន្លាស់': ['ទាំងអស់', 'ថ្មី', 'មួយទឹក', 'កាប់សាច់'],
    },


    'ពូជដំណាំ': ['ទាំងអស់', 'ឈើហូបផ្លែ', 'បន្លែ', 'ផ្ការ', 'ឈើព្រៃ', 'ផ្សេងៗ'],


    'ពូជសត្វចិញ្ចឹម': [
      'ទាំងអស់',
      'គោ',
      'ក្របី',
      'ជ្រូក',
      'ចៀម',
      'ពពែ',
      'មាន់',
      'ទា',
      'ក្ងាន',
      'ក្រួច',
      'អណ្ដើក/កន្ឋាយ',
      'ត្រី',
      'កង្កែប',
      'ពស់',
      'ជន្លេន',
      'ផ្សេងៗ',
    ],


    'ជីនិងថ្នាំ': ['ទាំងអស់', 'ជី', 'ថ្នាំ', 'វីតាមីន', 'ចំណីសត្វ', 'ផ្សេងៗ'],


    'បន្លែផ្លែឈើ': [
      'ទាំងអស់',
      'បន្លែ',
      'ផ្លែឈើ',
      'គ្រឿងទេស',
      'អាហារផ្អាប់',
      'ស៊ុត',
      'ផ្សេងៗ',
    ],


    'ត្រីសាច់': [
      'ទាំងអស់',
      'ត្រី',
      'សាច់',
      'កង្កែប',
      'អណ្ដើក',
      'ពស់',
      'ក្ដាម',
      'ផ្សេងៗ',
    ],


    'សេវាកម្ម': [
      'ទាំងអស់',
      'សេវាកម្មសត្វ',
      'ដំណាំ',
      'ម៉ាស៊ីន',
      'គ្រឿងចក្រ',
      'ទឹក/ភ្លើង',
      'ហិរញ្ញវត្ថុ',
      'ច្បាប់',
      'ផ្សេងៗ',
    ],
    'ផ្សេងៗ': [
      'ទាំងអស់',
      'ដីកសិកម្ម',
      'កសិដ្ឋាន',
      'តំណាងចែកចាយ/ហ្វ្រែនឆាយ',
      'ផលិតផលឌីជីថល',
      'សៀវភៅកសិកម្ម',
      'ផ្សេងៗ',
    ],
  };


  @override
  void initState() {
    super.initState();
    CambodiaLocationService.load();
    if (widget.initialData != null) {
      nameController.text = widget.initialData!['product_name'] ?? '';
      descriptionController.text = widget.initialData!['description'] ?? '';
      priceController.text = widget.initialData!['price']?.toString() ?? '';
      phone1Controller.text = widget.initialData!['phone1'] ?? '';
      phone2Controller.text = widget.initialData!['phone2'] ?? '';
      locationController.text = widget.initialData!['location'] ?? '';
      selectedCategory = widget.initialData!['category'];
      selectedCurrency = widget.initialData!['currency'] ?? '\$';
      _shippingIncluded = widget.initialData!['shipping_included'] as bool?;
    }
  }


  Future<void> pickManyImages() async {
    // 🎯 កែសម្រួល Line នេះ៖ បន្ថែម maxWidth, maxHeight, imageQuality
    final List<XFile> images = await _picker.pickMultiImage(
      maxWidth: 1440, // កម្រិតច្បាស់សមល្មម
      maxHeight: 1440, // កម្រិតច្បាស់សមល្មម
      imageQuality: 85, // បន្ថយគុណភាពបន្តិច ដើម្បីឱ្យវារុញមកលឿន
    );


    if (images.isNotEmpty) {
      // ... កូដផ្សេងៗទៀតរបស់មេ ទុកដដែល ...
      List<XFile> allPicked = [...selectedImages, ...images];


      if (allPicked.length > 10) {
        // 🎯 កាត់យកត្រឹមតែ ១០ សន្លឹកដំបូងគត់
        setState(() {
          selectedImages = allPicked.sublist(0, 10);
        });


        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('យើងកាត់យកត្រឹម ១០ សន្លឹកដំបូងជូនមេ!')),
        );
      } else {
        setState(() {
          selectedImages = allPicked;
        });
      }
    }
  }


  Future<void> pickVideo() async {
    // 🎯 ប្រើឈ្មោះ pickVideo ឱ្យដូចកូដចាស់មេ
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60), // កែជា ៦០ វិនាទីតាមមេចង់បាន
    );


    if (video != null) {
      // 🎯 ឆែកឱ្យច្បាស់ ១០០% បើលើស ៦០ វិនាទី គឺមិនយកដាច់ខាត
      final info = await VideoCompress.getMediaInfo(video.path);
      if (info.duration != null && info.duration! > 61000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('វីដេអូមិនអាចលើសពី ៦០ វិនាទីឡើយ!')),
        );
        return;
      }
      setState(() => selectedVideo = video);
    }
  }


  // --- មុខងារបង្រួមរូបភាព (កែសម្រួលឱ្យកាន់តែសុវត្ថិភាព និងច្បាស់ល្អ) ---
  Future<File?> _compressImage(File file) async {
    try {
      final filePath = file.absolute.path;


      // 🎯 រកចំណុច (.) ចុងក្រោយគេបង្អស់ ដើម្បីកាត់ឈ្មោះ File ឱ្យត្រូវគ្រប់ប្រភេទ (png, jpg, heic)
      final lastIndex = filePath.lastIndexOf('.');


      // បង្កើត Path ថ្មីសម្រាប់រក្សាទុក File ដែលបង្រួមរួច
      final outPath = "${filePath.substring(0, lastIndex)}_compressed.jpg";


      // ចាប់ផ្ដើមបង្រួមរូបភាព
      var result = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        quality: 70, // បង្រួមសល់ ៧០% (ទំហំស្រាលខ្លាំង តែនៅតែច្បាស់ភ្នែក)
        minWidth: 1024, // កម្រិតទទឹងសមល្មមសម្រាប់បង្ហាញលើ App
        minHeight: 1024, // កម្រិតកម្ពស់សមល្មម
        format: CompressFormat
            .jpeg, // 🎯 បង្ខំឱ្យទៅជា JPEG ដើម្បីឱ្យ Firebase ងាយអាន
      );


      if (result == null) return null;


      return File(result.path);
    } catch (e) {
      // បើមានបញ្ហាពេលបង្រួម ឱ្យវាប្រើ File ដើមសិន ដើម្បីកុំឱ្យគាំងការបង្ហោះ
      return file;
    }
  }


  Future<File?> _compressVideo(File file) async {
    try {
      print("--- ចាប់ផ្ដើមបង្រួមវីដេអូ ---");
      print("ទំហំដើម៖ ${file.lengthSync() / (1024 * 1024)} MB");


      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,  // ប្ដូរពី LowQuality
        deleteOrigin: false,
        includeAudio: true,
      );


      if (info != null && info.file != null) {
        print(
          "បង្រួមរួចរាល់! ទំហំថ្មី៖ ${info.file!.lengthSync() / (1024 * 1024)} MB",
        );
        return info.file;
      }
    } catch (e) {
      print("កំហុសពេលបង្រួម៖ $e");
      VideoCompress.cancelCompression();
    }
    return null;
  }


  // --- នេះជាមុខងារ _uploadToStorage ដែលកែសម្រួលរួច (ផាសជួសកន្លែងចាស់) ---
  Future<String> _uploadToStorage(File file, String folder) async {
    File fileToUpload = file;


    // បើជារូបភាព ឱ្យវាបង្រួមសិន
    if (folder.contains('images')) {
      File? compressed = await _compressImage(file);
      if (compressed != null) {
        fileToUpload = compressed;
      }
    } else if (folder.contains('videos')) {
      File? compressed = await _compressVideo(file);


      if (compressed != null) {
        // 🎯 ឆែកមើល៖ បើ File ដែលបង្រួមហើយ បែរជាធំជាង File ដើម ឱ្យយក File ដើមវិញ
        if (compressed.lengthSync() > file.lengthSync()) {
          fileToUpload = file;
          print("យក File ដើមវិញ ព្រោះការបង្រួមធ្វើឱ្យឡើងទំហំ");
        } else {
          fileToUpload = compressed;
          print("យក File ដែលបង្រួមរួចទៅ Upload");
        }


        // ឆែកប្រវែងវីដេអូក្រោម ៦០ វិនាទី
        final info = await VideoCompress.getMediaInfo(fileToUpload.path);
        if (info.duration != null && info.duration! > 60000) {
          throw "វីដេអូវែងពេក! សូមជ្រើសរើសវីដេអូក្រោម ៦០ វិនាទី។";
        }
      }
    }


    String fileExtension = fileToUpload.path.split('.').last;
    String fileName =
        "${DateTime.now().millisecondsSinceEpoch}_${fileToUpload.path.split('/').last}";
    Reference ref = FirebaseStorage.instance
        .ref()
        .child(folder)
        .child(fileName);


    SettableMetadata metadata = SettableMetadata(
      contentType: folder.contains('videos')
          ? 'video/$fileExtension'
          : 'image/$fileExtension',
    );


    UploadTask uploadTask = ref.putFile(fileToUpload, metadata);
    TaskSnapshot snapshot = await uploadTask;


    if (folder.contains('videos')) await VideoCompress.deleteAllCache();


    return await snapshot.ref.getDownloadURL();
  }


  // --- ផាសជំនួសមុខងារ _uploadProduct ចាស់ដោយកូដខាងក្រោមនេះ ---


  // បន្ថែមមុខងារនេះនៅខាងក្រោម _uploadProduct (ក្រៅសញ្ញាដង្កៀប)
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('បញ្ហាបង្ហោះ'),
        content: Text('មិនអាចបង្ហោះបានទេ ដោយសារ៖ $message'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('យល់ព្រម'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productId != null ? 'កែប្រែទំនិញ' : 'បន្ថែមទំនិញថ្មី',
        ),
        backgroundColor: Colors.green,
        // 🎯 ដាក់ក្នុង actions: [] របស់ AppBar ក្នុងទំព័រ Add Product
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AuctionAddScreen()),
                ); // 🎯 ដាក់ Navigator ទៅកាន់ទំព័រ Request Exhibition របស់មេនៅទីនេះ
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  // ✨ ពណ៌មាសដេញ (Gold Gradient) ឱ្យមើលទៅមានតម្លៃ
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.stars_rounded, color: Colors.black, size: 18),
                    SizedBox(width: 4),
                    Text(
                      "ដាក់ដេញថ្លៃ",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent, // ឲ្យកូន Widget នៅតែដំណើរការ
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
            _buildMediaButton(
              onTap: () {
                if (selectedImages.length < 10) {
                  pickManyImages();
                }
              },
              icon: Icons.collections,
              label: selectedImages.length >= 10
                  ? "រូបភាពគ្រប់ចំនួនហើយ (១០/១០)"
                  : "រើសរូបភាព (${selectedImages.length}/10)",
              // 🎯 កែពណ៌ឱ្យទៅជាប្រផេះ បើគ្រប់ ១០ សន្លឹក
              color: selectedImages.length >= 10
                  ? Colors.grey.shade300
                  : Colors.blue.shade50,
              textColor: selectedImages.length >= 10
                  ? Colors.grey
                  : Colors.blue,
            ),
            const SizedBox(height: 10),
            // 🎯 បង្ហាញរូបភាព Preview ជាមួយនឹងប៊ូតុងលុប (Cancel)
            if (selectedImages.isNotEmpty)
              SizedBox(
                height: 110, // ថែមទំហំបន្តិចដើម្បីកុំឱ្យដាច់ប៊ូតុងលុប
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedImages.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 12, top: 10),
                    child: Stack(
                      clipBehavior: Clip.none, // ឱ្យប៊ូតុងលុបអាចលយចេញក្រៅបាន
                      children: [
                        // ១. បង្ហាញរូបថត
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(selectedImages[index].path),
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),


                        // ២. ប៊ូតុង Cancel (លុបរូប) - ដាក់នៅខាងស្តាំដៃលើរូប
                        Positioned(
                          top: -8,
                          right: -8,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedImages.removeAt(
                                  index,
                                ); // 🎯 លុបរូបចេញពី List ភ្លាម
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),


            const SizedBox(height: 15),


            // ប៊ូតុងរើសវីដេអូ
            _buildMediaButton(
              // កែជួរ ៤៨៧
              onTap: () => pickVideo(),
              icon: Icons.video_library,
              label: selectedVideo == null
                  ? "រើសវីដេអូបង្ហាញទំនិញ"
                  : "រើសវីដេអូរួចរាល់ ✅",
              color: Colors.orange.shade50,
              textColor: Colors.orange,
            ),


            const SizedBox(height: 20),
            _buildTextField('ឈ្មោះទំនិញ *', Icons.shopping_bag, nameController),
            const SizedBox(height: 10),
            _buildCategoryDropdown(),
            const SizedBox(height: 10),
            _buildPriceSection(),
            const SizedBox(height: 10),
            _buildTextField(
              'បរិយាយទំនិញ',
              Icons.description,
              descriptionController,
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            _buildPhoneSection(),
            const SizedBox(height: 10),


            /// ROW ទីតាំង និង MAP
            Row(
              children: [
                /// =========================
                /// LOCATION PICKER (រើសខេត្ត/ស្រុក/ឃុំ)
                /// =========================
                /// LOCATION PICKER (រៀបឱ្យស៊ីជាមួយ TextField ផ្សេងៗ)
                /// =========================
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () {
                      showLocationPicker(
                        context,
                        onSelected: (location) {
                          setState(() {
                            locationController.text = location.toString();
                          });
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(
                      10,
                    ), // កែមក ១០ ឱ្យស្មើ TextField លើៗ
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal:
                        12, // សារ៉េឱ្យស្មើ PrefixIcon របស់ TextField
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        // ✅ ១. លុប color: Colors.white ចោល (ឱ្យវាយកពណ៌តាម Theme App)
                        borderRadius: BorderRadius.circular(10),


                        // ✅ ២. សារ៉េពណ៌ Border ឱ្យស្រាលបំផុត (ដូច TextField ដើម)
                        border: Border.all(color: Colors.grey.shade400),


                        // ✅ ៣. បន្ថែមស្រមោលស្រាលៗ ដើម្បីឱ្យវាមាន "រង្វង់" និង "ជម្រៅ" ដូចគេ
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_city,
                            color: Colors
                                .green, // ប្រើពណ៌បៃតងឱ្យស៊ីជាមួយ Icon ក្នុង TextField ផ្សេងទៀត
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              locationController.text.isEmpty
                                  ? "ជ្រើសទីតាំង *"
                                  : locationController.text,
                              style: TextStyle(
                                fontSize: 16,
                                color: locationController.text.isEmpty
                                    ? Colors
                                    .grey
                                    .shade600 // ពណ៌អក្សរ Hint
                                    : Colors.black87,
                                fontFamily: 'Siemreap',
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),


                const SizedBox(width: 10),


                /// =========================
                /// MAP PICKER BUTTON (Coming Soon)
                /// =========================
                Expanded(
                  flex: 1,
                  child: Container(
                    // ប្តូរពី InkWell មក Container ធម្មតាដើម្បី Disable
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors
                          .grey
                          .shade200, // ពណ៌ប្រផេះបញ្ជាក់ថាប្រើមិនទាន់កើត
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, color: Colors.grey.shade500),
                        const SizedBox(height: 2),
                        const Text(
                          "Maps",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // ចប់ផ្នែករើសទីតាំង
            const SizedBox(height: 25),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () async {
                // 🎯 ថែម async នៅត្រង់នេះ
                // ១. ឆែកលក្ខខណ្ឌចាំបាច់ (Validation)
                if (selectedImages.isEmpty ||
                    selectedCategory == null ||
                    nameController.text.isEmpty ||
                    priceController.text.isEmpty ||
                    phone1Controller.text.isEmpty ||
                    locationController.text.isEmpty) {
                  Get.snackbar(
                    'ខ្វះព័ត៌មាន',
                    'សូមមេមេ ជួយបំពេញព័ត៌មាន និងដាក់រូបថតឱ្យគ្រប់សិន!',
                    backgroundColor: Colors.redAccent,
                    colorText: Colors.white,
                  );
                  return;
                }
                if (_shippingIncluded == null) {
                  Get.snackbar(
                    'ខ្វះព័ត៌មាន',
                    'សូមជ្រើសរើសថាតើតម្លៃនេះបូកថ្លៃផ្ញើរួចឬនៅ?',
                    backgroundColor: Colors.redAccent,
                    colorText: Colors.white,
                  );
                  return;
                }

                // 🎯 ២. ទាញព័ត៌មាន User (នេះជាកន្លែងដែលបាត់!)
                final prefs = await SharedPreferences.getInstance();
                final currentUser = FirebaseAuth.instance.currentUser;


                // ព្យាយាមយកពី Firebase បើអត់មានទើបយកពី SharedPreferences
                String uId =
                    currentUser?.uid ??
                        prefs.getString('user_uid') ??
                        "UNKNOWN";
                String uName =
                    currentUser?.displayName ??
                        prefs.getString('user_name') ??
                        "អ្នកប្រើប្រាស់ Sesan";
                String uPhoto =
                    currentUser?.photoURL ??
                        prefs.getString('user_photo') ??
                        "";


                // ៣. រៀបចំទិន្នន័យ (បន្ថែម seller_id, name, photo ចូល)
                Map<String, dynamic> dataFromForm = {
                  'product_name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'price': priceController.text.trim(),
                  'phone1': phone1Controller.text.trim(),
                  'phone2': phone2Controller.text.trim(),
                  'location': locationController.text.trim(),
                  'category': selectedCategory,
                  'sub_category':
                  selectedSubCategory ?? '', // ✅ បន្ថែមបន្ទាត់នេះ
                  'sub_sub_category':
                  selectedSubSubCategory ?? 'ទាំងអស់', // ✅ បន្ថែមបន្ទាត់នេះ
                  'currency': selectedCurrency,
                  'lat': selectedLat,
                  'lng': selectedLng,
                  // 🎯 បន្ថែម ៣ ជួរនេះដើម្បីបាត់ UNKNOWN
                  'seller_id': uId,
                  'seller_name': uName,
                  'seller_photo': uPhoto,
                  'shipping_included':
                  _shippingIncluded, // true = បូករួច, false = មិនទាន់បូក
                  'created_at':
                  FieldValue.serverTimestamp(), // ថែមថ្ងៃខែផុសផងមេ
                };


                // ៤. បញ្ជាឱ្យបង្ហោះក្រោយខ្នង (Background Upload)
                uploadController.startBackgroundUpload(
                  productId: widget.productId,
                  formData: dataFromForm,
                  selectedImages: List.from(selectedImages),
                  selectedVideo: selectedVideo,
                );


                // ៥. នាំផ្លូវទៅ Home និងបង្ហាញសារ
                Get.offAllNamed('/home');
                Get.snackbar(
                  '🚀 កំពុងបង្ហោះ...',
                  'ទំនិញរបស់មេកំពុងបង្ហោះហើយ!',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.black54,
                  colorText: Colors.white,
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'រក្សាទុកការផុស',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
        ),
    );
  }


  // --- Widgets ជំនួយសម្រាប់ UI ---
  Widget _buildMediaButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        minimumSize: const Size(double.infinity, 50),
        elevation: 0,
      ),
    );
  }


  Widget _buildTextField(
      String label,
      IconData icon,
      TextEditingController controller, {
        int maxLines = 1,
      }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }


  Widget _buildCategoryDropdown() {
    return Column(
      children: [
        // Category មេ
        DropdownButtonFormField<String>(
          value: selectedCategory,
          decoration: InputDecoration(
            labelText: 'ប្រភេទលក់ *',
            prefixIcon: const Icon(Icons.category, color: Colors.green),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (val) {
            setState(() {
              selectedCategory = val;
              selectedSubCategory = null;
              selectedSubSubCategory = null; // ✅ Reset ទាំងអស់
            });
          },
        ),


        // ✅ Sub Category Dropdown
        if (selectedCategory != null &&
            subCategories.containsKey(selectedCategory))
          _buildSubCategoryDropdown(),


        // ✅ Sub-Sub Category Dropdown (សម្រាប់តែ "សម្ភារៈកសិកម្ម")
        if (selectedCategory == 'សម្ភារៈកសិកម្ម' &&
            selectedSubCategory != null &&
            selectedSubCategory != 'ទាំងអស់')
          _buildSubSubCategoryDropdown(),
      ],
    );
  }


  // ✅ Sub Category Dropdown
  Widget _buildSubCategoryDropdown() {
    final subData = subCategories[selectedCategory];
    List<String> subList;


    if (subData is Map) {
      subList = subData.keys.cast<String>().toList();
    } else if (subData is List) {
      subList = subData.cast<String>();
    } else {
      return const SizedBox.shrink();
    }


    if (subList.isEmpty ||
        (subList.length == 1 && subList.first == 'ទាំងអស់')) {
      return const SizedBox.shrink();
    }


    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DropdownButtonFormField<String>(
        value: selectedSubCategory,
        decoration: InputDecoration(
          labelText: 'ប្រភេទរង (ស្រេចចិត្ត)',
          prefixIcon: const Icon(
            Icons.subdirectory_arrow_right,
            color: Colors.orange,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: subList
            .map((sub) => DropdownMenuItem(value: sub, child: Text(sub)))
            .toList(),
        onChanged: (val) {
          setState(() {
            selectedSubCategory = val;
            selectedSubSubCategory = null; // ✅ Reset Sub-Sub
          });
        },
      ),
    );
  }


  // ✅ Sub-Sub Category Dropdown (សម្រាប់តែ "សម្ភារៈកសិកម្ម")
  Widget _buildSubSubCategoryDropdown() {
    final subData = subCategories[selectedCategory];
    if (subData is! Map) return const SizedBox.shrink();


    final subSubList = subData[selectedSubCategory] as List<String>?;
    if (subSubList == null ||
        subSubList.isEmpty ||
        (subSubList.length == 1 && subSubList.first == 'ទាំងអស់')) {
      return const SizedBox.shrink();
    }


    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DropdownButtonFormField<String>(
        value: selectedSubSubCategory,
        decoration: InputDecoration(
          labelText: 'លក្ខខណ្ឌ (ស្រេចចិត្ត)',
          prefixIcon: const Icon(
            Icons.subdirectory_arrow_right,
            color: Colors.red,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: subSubList
            .map((sub) => DropdownMenuItem(value: sub, child: Text(sub)))
            .toList(),
        onChanged: (val) {
          setState(() => selectedSubSubCategory = val);
        },
      ),
    );
  }


  // ក្នុង _buildPriceSection បងដក Dropdown ចេញ ហើយប្រើតែសញ្ញារៀល
  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ប្រអប់តម្លៃដូចដើម
        TextField(
          controller: priceController,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            if (value.isNotEmpty) {
              String cleanNumber = value.replaceAll(',', '');
              String formatted = formatter.format(int.parse(cleanNumber));
              priceController.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.fromPosition(
                  TextPosition(offset: formatted.length),
                ),
              );
            }
          },
          decoration: InputDecoration(
            labelText: 'តម្លៃ (៛) *',
            prefixIcon: const Icon(Icons.money, color: Colors.green),
            suffixText: "៛",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        const SizedBox(height: 12),

        // ជម្រើសថ្លៃផ្ញើ (ជ្រើសយកមួយ)
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool?>(
                title: const Text(
                  'បានបូកទាំងថ្លៃផ្ញើ',
                  style: TextStyle(fontSize: 11, fontFamily: 'Siemreap'),
                ),
                value: true,
                groupValue: _shippingIncluded,
                onChanged: (val) {
                  setState(() => _shippingIncluded = val);
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: Colors.green,
              ),
            ),
            Expanded(
              child: RadioListTile<bool?>(
                title: const Text(
                  'មិនទាន់បូកថ្លៃផ្ញើ',
                  style: TextStyle(fontSize: 11, fontFamily: 'Siemreap'),
                ),
                value: false,
                groupValue: _shippingIncluded,
                onChanged: (val) {
                  setState(() => _shippingIncluded = val);
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhoneSection() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField('លេខទី១ *', Icons.phone, phone1Controller),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTextField(
            'លេខទី២',
            Icons.phone_android,
            phone2Controller,
          ),
        ),
      ],
    );
  }
}



