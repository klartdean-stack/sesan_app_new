import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final _titleController = TextEditingController();
  final _monthController = TextEditingController();
  final _descController = TextEditingController();

  File? _selectedFile;
  bool _isUploading = false;

  // 🎯 មុខងាររើស File PDF ពីទូរស័ព្ទ
  Future<void> _pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  // 🎯 មុខងារបង្ហោះទៅ Firebase
  Future<void> _uploadReport() async {
    if (_selectedFile == null || _titleController.text.isEmpty) return;

    setState(() => _isUploading = true);

    try {
      // ១. បង្ហោះ File ទៅ Firebase Storage
      String fileName = "${DateTime.now().millisecondsSinceEpoch}.pdf";
      Reference ref = FirebaseStorage.instance.ref().child('reports/$fileName');
      UploadTask uploadTask = ref.putFile(_selectedFile!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // ២. រក្សាទុកព័ត៌មានក្នុង Firestore
      await FirebaseFirestore.instance.collection('reports').add({
        'title': _titleController.text,
        'month': _monthController.text,
        'description': _descController.text,
        'pdf_url': downloadUrl, // ទុក Link PDF សម្រាប់ User ចុចមើល
        'date': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F121F),
      appBar: AppBar(title: const Text("បង្ហោះរបាយការណ៍ PDF")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildInput("ចំណងជើងរបាយការណ៍", _titleController),
          _buildInput("ប្រចាំខែ", _monthController),
          const SizedBox(height: 10),

          // ប៊ូតុងរើស File
          InkWell(
            onTap: _pickPDF,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.blueAccent,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.redAccent,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedFile == null
                        ? "ចុចដើម្បីរើស File PDF"
                        : "ជ្រើសរើសរួចរាល់៖\n${_selectedFile!.path.split('/').last}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          _buildInput("ការរៀបរាប់សង្ខេប", _descController, maxLines: 3),
          const SizedBox(height: 30),

          _isUploading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _uploadReport,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("បង្ហោះចូលទៅកាន់ Sesan App"),
                ),
        ],
      ),
    );
  }

  Widget _buildInput(
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}
