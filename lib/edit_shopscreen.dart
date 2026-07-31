import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class EditShopScreen extends StatefulWidget {
  const EditShopScreen({super.key});

  @override
  State<EditShopScreen> createState() => _EditShopScreenState();
}

class _EditShopScreenState extends State<EditShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String _userId = '';
  bool _isLoading = false;
  bool _isDataLoading = true;

  // រូបភាព
  File? _profileImage;
  File? _coverImage;
  String? _profileImageUrl;
  String? _coverImageUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    try {
      // ✅ ប្រើ SharedPreferences ជំនួស FirebaseAuth
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('user_uid');

      if (mounted) {
        if (uid != null && uid.isNotEmpty) {
          setState(() {
            _userId = uid;
          });
          await _loadCurrentData(); // ✅ ទាញទិន្នន័យចាស់មកបង្ហាញ
        } else {
          setState(() => _isDataLoading = false);
          _showError("រកមិនឃើញ User ឡើយ សូម Login ម្តងទៀត");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDataLoading = false);
        _showError("Error: $e");
      }
    }
  }

  // ✅ ទាញទិន្នន័យចាស់មកបង្ហាញ (មិន clear)
  Future<void> _loadCurrentData() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();

      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          // ✅ ប្រើ key ត្រឹមត្រូវ
          _nameController.text = data['name'] ?? '';           // ✅ name
          _bioController.text = data['bio'] ?? '';
          _phoneController.text = data['phone'] ?? '';         // ✅ phone
          _addressController.text = data['address'] ?? '';
          _profileImageUrl = data['photoUrl'];                 // ✅ photoUrl
          _coverImageUrl = data['coverUrl'];                   // ✅ coverUrl (ជំនួស cover_image)
          _isDataLoading = false;
        });
      } else {
        if (mounted) {
          setState(() => _isDataLoading = false);
        }
      }
    } catch (e) {
      debugPrint("Load Data Error: $e");
      if (mounted) {
        setState(() => _isDataLoading = false);
        _showError("មិនអាចផ្ទុកទិន្នន័យបាន");
      }
    }
  }

  // ✅ រើសរូបភាព
  Future<void> _pickImage(bool isProfile) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: isProfile ? 400 : 800,
        maxHeight: isProfile ? 400 : 400,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          if (isProfile) {
            _profileImage = File(pickedFile.path);
          } else {
            _coverImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      _showError("មិនអាចរើសរូបភាពបាន");
    }
  }

  // ✅ បង្រួមរូបភាព
  Future<File?> _compressImage(File file, bool isProfile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          "${tempDir.path}/${isProfile ? 'profile' : 'cover'}_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: isProfile ? 300 : 800,
        minHeight: isProfile ? 300 : 400,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      debugPrint("Compress Error: $e");
      return file;
    }
  }

  // ✅ បង្ហោះរូបភាព
  Future<String?> _uploadImage(File file, bool isProfile) async {
    try {
      File? compressedFile = await _compressImage(file, isProfile);
      if (compressedFile == null) return null;

      String fileName =
          "${isProfile ? 'profile' : 'cover'}_${_userId}_${DateTime.now().millisecondsSinceEpoch}.jpg";
      Reference ref = FirebaseStorage.instance.ref().child(
        'shop_images/$fileName',
      );

      await ref.putFile(compressedFile);
      String downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Upload Error: $e");
      return null;
    }
  }

  // ✅ រក្សាទុកការផ្លាស់ប្តូរ
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userId.isEmpty) {
      _showError("សូម Login មុននឹងរក្សាទុក");
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? newProfileUrl;
      String? newCoverUrl;

      if (_profileImage != null) {
        newProfileUrl = await _uploadImage(_profileImage!, true);
      }
      if (_coverImage != null) {
        newCoverUrl = await _uploadImage(_coverImage!, false);
      }

      // ✅ ប្រើ key ត្រឹមត្រូវតាម collection users
      Map<String, dynamic> updateData = {
        'name': _nameController.text.trim(),      // ✅ name
        'bio': _bioController.text.trim(),
        'phone': _phoneController.text.trim(),    // ✅ phone
        'address': _addressController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // ✅ កែ key ឱ្យត្រឹមត្រូវ
      if (newProfileUrl != null) {
        updateData['photoUrl'] = newProfileUrl;  // ✅ photoUrl (ជំនួស profile_image)
      }
      if (newCoverUrl != null) {
        updateData['coverUrl'] = newCoverUrl;    // ✅ coverUrl (ជំនួស cover_image)
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .set(updateData, SetOptions(merge: true));

      // ✅ រក្សាទិន្នន័យដែលបានបញ្ចូល (មិន clear)
      if (mounted) {
        // ធ្វើបច្ចុប្បន្នភាព URL ថ្មី
        setState(() {
          if (newProfileUrl != null) {
            _profileImageUrl = newProfileUrl;
            _profileImage = null; // លុបតែ file ក្នុងមូលដ្ឋាន
          }
          if (newCoverUrl != null) {
            _coverImageUrl = newCoverUrl;
            _coverImage = null; // លុបតែ file ក្នុងមូលដ្ឋាន
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ បានរក្សាទុកការផ្លាស់ប្តូរ"),
            backgroundColor: Colors.green,
          ),
        );

        // ✅ ត្រឡប់ទៅទំព័រមុនវិញ (ដោយមិន pop ទិន្នន័យ)
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Save Error: $e");
      if (mounted) _showError("មិនអាចរក្សាទុកបាន: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ បង្ហាញកំហុស
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          "កែសម្រួលហាង",
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Siemreap'),
        ),
        centerTitle: true,
        actions: [
          _isLoading
              ? const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
              : IconButton(
            onPressed: _saveChanges,
            icon: const Icon(Icons.check, color: Colors.green),
          ),
        ],
      ),
      body: _isDataLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("កំពុងផ្ទុកទិន្នន័យ..."),
          ],
        ),
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Cover Image
            _buildCoverImageSection(),
            const SizedBox(height: 16),

            // Profile Image
            _buildProfileImageSection(),
            const SizedBox(height: 24),

            // Shop Name
            _buildTextField(
              controller: _nameController,
              label: "ឈ្មោះហាង *",
              hint: "បញ្ចូលឈ្មោះហាង",
              icon: Icons.store,
              validator: (v) => v!.isEmpty ? "សូមបញ្ចូលឈ្មោះហាង" : null,
            ),
            const SizedBox(height: 16),

            // Phone
            _buildTextField(
              controller: _phoneController,
              label: "លេខទូរស័ព្ទ *",
              hint: "012 345 678",
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (v) =>
              v!.isEmpty ? "សូមបញ្ចូលលេខទូរស័ព្ទ" : null,
            ),
            const SizedBox(height: 16),

            // Address
            _buildTextField(
              controller: _addressController,
              label: "អាសយដ្ឋាន",
              hint: "បញ្ចូលអាសយដ្ឋានហាង",
              icon: Icons.location_on,
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Bio
            _buildTextField(
              controller: _bioController,
              label: "ជីវប្រវត្តិហាង (Bio)",
              hint: "រៀបរាប់ពីហាងរបស់អ្នក ឬផលិតផលដែលលក់...",
              icon: Icons.description,
              maxLines: 4,
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveChanges,
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(
                  _isLoading
                      ? "កំពុងរក្សាទុក..."
                      : "រក្សាទុកការផ្លាស់ប្តូរ",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Siemreap',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  // ✅ Cover Image Section (មិន clear ទិន្នន័យចាស់)
  Widget _buildCoverImageSection() {
    return GestureDetector(
        onTap: () => _pickImage(false),
        child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                    fit: StackFit.expand,
                    children: [
                    // ✅ បង្ហាញរូបដែលបានជ្រើសរើសថ្មី ឬរូបចាស់
                    if (_coverImage != null)
                Image.file(_coverImage!, fit: BoxFit.cover)
            else if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty)
        Image.network(
        _coverImageUrl!,
        fit: BoxFit.cover,
        key: ValueKey(_coverImageUrl), // ជួយ refresh
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
    )
    else
    _buildPlaceholder(),

    // ✅ ប៊ូតុង Edit overlay
    Positioned(
    top: 8,
    right: 8,
    child: Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
    color: Colors.black.withOpacity(0.6),
    borderRadius: BorderRadius.circular(20),
    ),
    child: const Icon(
    Icons.edit,
    color: Colors.white,
    size: 16,
    ),
    ),
    ),
    ],
    ),
    ),
    ),
    );
  }

  // ✅ Placeholder សម្រាប់ពេលគ្មានរូប
  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate,
          size: 40,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 8),
        Text(
          "ដាក់រូប Cover",
          style: TextStyle(color: Colors.grey[500]),
        ),
      ],
    );
  }

  // ✅ Profile Image Section (មិន clear ទិន្នន័យចាស់)
  Widget _buildProfileImageSection() {
    return Center(
        child: GestureDetector(
            onTap: () => _pickImage(true),
            child: Stack(
              children: [
              Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
                // ✅ បង្ហាញរូបថ្មី ឬរូបចាស់
                image: _profileImage != null
                    ? DecorationImage(
                  image: FileImage(_profileImage!),
                  fit: BoxFit.cover,
                )
                    : _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? DecorationImage(
                  image: NetworkImage(_profileImageUrl!),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              // ✅ បង្ហាញ icon ពេលគ្មានរូប
              child: _profileImage == null &&
                  (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                  ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                  : null,
            ),
            // ✅ ប៊ូតុងកាមេរ៉ា
            Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green[700],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ),
              ],
            ),
        ),
    );
  }

  // Custom TextField
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green[700]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green[700]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}