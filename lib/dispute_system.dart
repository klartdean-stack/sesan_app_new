import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/dispute_policy_screen.dart';

class DisputeSystem extends StatefulWidget {
  final Map<String, dynamic> orderData;
  const DisputeSystem({super.key, required this.orderData});

  @override
  State<DisputeSystem> createState() => _DisputeSystemState();
}

class _DisputeSystemState extends State<DisputeSystem> {
  // ១. បង្កើត Controller សម្រាប់ឱ្យ User បំពេញផ្ទាល់ (ការពារការចេញ "គ្មាន")
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedReason;
  File? _screenshotFile;
  bool _isUploading = false;
  bool _isAccepted = false;

  final List<String> _reasons = [
    "អីវ៉ាន់ខូច/បែកបាក់",
    "អីវ៉ាន់មិនដូចក្នុងរូបថត",
    "អ្នកលក់ផ្ញើខុសមុខទំនិញ",
    "មិនបានទទួលអីវ៉ាន់ (លើស 3 ថ្ងៃ)",
    "អ្នកលក់អាកប្បកិរិយាមិនសមរម្យ",
    "ផ្សេងៗ...",
  ];

  @override
  void initState() {
    super.initState();
    // 🎯 កែឈ្មោះ Key ក្នុង [] ឱ្យដូចក្នុង Database របស់មេបេះបិទ
    _phoneController = TextEditingController(
      text: widget.orderData['customer_phone']?.toString() ?? "",
    );
    _addressController = TextEditingController(
      text:
          widget.orderData['shipping_address'] ??
          widget.orderData['address'] ??
          "",
    );
  }

  Future<void> _submitComplaint() async {
    // កែក្នុង _submitComplaint ឱ្យបាត់ឆ្នូតក្រហម
    if (_selectedReason == null ||
        _phoneController.text.isEmpty ||
        _addressController.text.isEmpty) {
      _showSnackBar("សូមបំពេញ មូលហេតុ លេខទូរស័ព្ទ និងអាសយដ្ឋានឱ្យគ្រប់!");
      return;
    }
    if (_screenshotFile == null) {
      _showSnackBar("សូមភ្ជាប់រូបភាពភស្តុតាង!");
      return;
    }

    setState(() => _isUploading = true);

    try {
      String imageUrl = "";
      final ref = FirebaseStorage.instance.ref().child(
        'complaints/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(_screenshotFile!);
      imageUrl = await ref.getDownloadURL();

      final currentUser = FirebaseAuth.instance.currentUser;

      // ២. រុញចូល Firebase (ច្របាច់ទិន្នន័យឱ្យហ្មត់ចត់បំផុត)
      await FirebaseFirestore.instance.collection('complaints').add({
        'order_id':
            widget.orderData['order_id'] ??
            widget.orderData['orderId'] ??
            "Unknown_ID",
        'product_name':
            widget.orderData['product_name'] ??
            widget.orderData['productName'] ??
            "មិនស្គាល់ទំនិញ",
        'reason': _selectedReason,
        'description': _descriptionController.text,
        'screenshot_order': imageUrl,
        'time': FieldValue.serverTimestamp(),
        'status': 'pending',

        // ព័ត៌មានអតិថិជន (យកពីប្រអប់ដែល User វាយ - លែងចេញ "គ្មាន" ទៀតហើយ)
        'customer_id': currentUser?.uid ?? widget.orderData['customer_id'],
        'customer_name':
            currentUser?.displayName ??
            widget.orderData['customer_name'] ??
            "អតិថិជន",
        'customer_phone': _phoneController.text,
        'shipping_address': _addressController.text,

        // ព័ត៌មានអ្នកលក់
        'seller_id': widget.orderData['seller_id'] ?? "Unknown_Seller",
        'seller_name': widget.orderData['seller_name'] ?? "ហាងមិនបានបញ្ជាក់",
        'seller_phone': widget.orderData['seller_phone'] ?? "000000000",
      });

      setState(() => _isUploading = false);
      _showSuccessDialog();
    } catch (e) {
      setState(() => _isUploading = false);
      _showSnackBar("កំហុស៖ $e");
    }
  }

  // --- UI បង្ហាញ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ដាក់បណ្ដឹង", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildNoticeCard(),
            const SizedBox(height: 20),
            _buildOrderPreview(), // ព័ត៌មានបុង (ការពារ Screen ក្រហម)
            const SizedBox(height: 20),
            _buildComplaintForm(),
            const SizedBox(height: 30),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderPreview() {
    return Card(
      child: ListTile(
        // 🎯 បន្ថែមរូបភាពទំនិញនៅទីនេះ
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.network(
            widget.orderData['image_url'] ??
                widget.orderData['product_image'] ??
                "",
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.shopping_bag,
              color: Colors.red,
            ), // បើអត់រូប ឱ្យចេញរូបថង់ដដែល
          ),
        ),
        title: Text(widget.orderData['product_name'] ?? "ទំនិញមិនស្គាល់"),
        subtitle: Text("លេខបុង៖ ${widget.orderData['order_id'] ?? 'N/A'}"),
      ),
    );
  }

  Widget _buildComplaintForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "១. មូលហេតុបណ្ដឹង",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedReason,
          hint: const Text("រើសមូលហេតុ..."),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: _reasons
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (v) => setState(() => _selectedReason = v),
        ),
        const SizedBox(height: 15),
        const Text(
          "២. ព័ត៌មានទំនាក់ទំនងរបស់អ្នក",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: "លេខទូរស័ព្ទ",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: "អាសយដ្ឋាន",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "៣. រូបភាពភស្តុតាង",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickScreenshot,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _screenshotFile == null
                ? const Icon(Icons.add_a_photo, size: 40)
                : Image.file(_screenshotFile!, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }

  // --- Widget ជំនួយ (SnackBar, Dialog, Button...) ---
  Widget _buildNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        children: [
          const Text(
            "⚠️ ការផ្ដល់ភស្តុតាងមិនពិត ឬមានចេតនាបន្លំក្នុងប្រព័ន្ធបណ្ដឹង ជាអំពើល្មើសនឹងគោលការណ៍កម្មវិធី ហើយនឹងត្រូវប្រឈមមុខនឹងការផ្ដាច់អាជ្ញាប័ណ្ណប្រើប្រាស់ (បិទគណនី) ជាអចិន្ត្រៃយ៍។",
            style: TextStyle(fontSize: 12, color: Colors.red),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment
                .start, // 🎯 ឱ្យអក្សរតម្រឹមទៅលើស្មើ Checkbox បើវាវែង
            children: [
              Checkbox(
                value: _isAccepted,
                onChanged: (value) => setState(() => _isAccepted = value!),
              ),
              Expanded(
                // 🎯 ប្រើ Expanded ដើម្បីឱ្យអក្សរធ្លាក់បន្ទាត់បានស្អាត
                child: GestureDetector(
                  onTap: () => setState(() => _isAccepted = !_isAccepted),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontFamily: 'Siemreap',
                      ),
                      children: [
                        const TextSpan(
                          text:
                              "ខ្ញុំសូមបញ្ជាក់ថាព័ត៌មានខាងក្រោមត្រឹមត្រូវ និងយល់ព្រមតាម ",
                        ),
                        WidgetSpan(
                          child: InkWell(
                            onTap: () => _showPolicyDialog(context),
                            child: const Text(
                              "គោលការណ៍ដោះស្រាយវិវាទ",
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isAccepted ? Colors.red[800] : Colors.grey,
        ),
        onPressed: (_isAccepted && !_isUploading) ? _submitComplaint : null,
        child: _isUploading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "បញ្ជូនបណ្ដឹង",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ជោគជ័យ"),
        content: const Text("ផ្ញើបណ្ដឹងរួចរាល់!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // បិទ Dialog
              Navigator.pop(
                context,
              ); // ថយក្រោយទៅកាន់ Screen មុន (Order History)
            },
            child: const Text("យល់ព្រម"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickScreenshot() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (p != null) setState(() => _screenshotFile = File(p.path));
  }

  void _showPolicyDialog(BuildContext context) {
    // 🎯 ប្រើ Navigator.push ដើម្បីបើក file dispute_policy_screen.dart ពេញ Screen តែម្ដង
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DisputePolicyScreen()),
    );
  }
}
