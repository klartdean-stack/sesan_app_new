import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:flutter/services.dart';


class CreateInvoiceSheet extends StatefulWidget {
  final Function(Map<String, dynamic> data) onAction;


  static final TextEditingController cusName = TextEditingController();
  static final TextEditingController cusPhone = TextEditingController();
  static final TextEditingController cusAddress = TextEditingController();


  // 🎯 កែប្រែទី១៖ ថ្លៃដឹកដំបូងទុកទំនេរស្អាត មិនឱ្យជាប់ 0.0 នាំហត់លុប
  static final TextEditingController shipPrice = TextEditingController(
    text: '',
  );


  // 🎯 កែប្រែទី២៖ តម្លៃទំនិញជួរទីមួយ ទុកទំនេរស្អាត ('') មិនឱ្យចេញ 0.0 ឡើយ
  static List<Map<String, TextEditingController>> items = [
    {
      'desc': TextEditingController(),
      'qty': TextEditingController(
        text: '1',
      ), // ចំនួនចេញលេខ 1 អូតូ ត្រឹមត្រូវហើយ
      'price': TextEditingController(text: ''),
    },
  ];


  static File? qrFile;


  const CreateInvoiceSheet({super.key, required this.onAction});


  @override
  State<CreateInvoiceSheet> createState() => _CreateInvoiceSheetState();
}


class _CreateInvoiceSheetState extends State<CreateInvoiceSheet> {
  final ScreenshotController _screenshotController = ScreenshotController();


  // មុខងារ Reset ទិន្នន័យ
  void _resetInvoice() {
    setState(() {
      CreateInvoiceSheet.cusName.clear();
      CreateInvoiceSheet.cusPhone.clear();
      CreateInvoiceSheet.cusAddress.clear();
      CreateInvoiceSheet.shipPrice.text = ''; // ទុកឱ្យទំនេរ
      CreateInvoiceSheet.qrFile = null;
      CreateInvoiceSheet.items = [
        {
          'desc': TextEditingController(),
          'qty': TextEditingController(text: '1'),
          'price': TextEditingController(text: ''), // ទុកឱ្យទំនេរ
        },
      ];
    });
  }


  Future<void> _pickAndCropQRCode() async {
    final ImagePicker picker = ImagePicker();
    final ImageCropper cropper = ImageCropper();


    final XFile? image = await picker.pickImage(source: ImageSource.gallery);


    if (image != null) {
      final CroppedFile? croppedFile = await cropper.cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'តម្រឹម QR Code',
            toolbarColor: Colors.green,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'តឹម QR Code',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );


      if (croppedFile != null) {
        setState(() {
          CreateInvoiceSheet.qrFile = File(croppedFile.path);
        });
      }
    }
  }


  // 🎯 កែប្រែទី៣៖ មុខងារគណនាលុយសរុបថ្មី ដោយលុបសញ្ញាក្បៀស (,) ចេញមុននឹងបូកលេខ
  double _calculateGrandTotal() {
    double subtotal = CreateInvoiceSheet.items.fold(0, (sum, item) {
      String qtyText = (item['qty']!.text).replaceAll(',', '');
      String priceText = (item['price']!.text).replaceAll(',', '');


      // ✅ ពិនិត្យទទេ
      double q = double.tryParse(qtyText) ?? 0;
      double p = double.tryParse(priceText) ?? 0;
      return sum + (q * p);
    });


    String shipText = CreateInvoiceSheet.shipPrice.text.replaceAll(',', '');
    double shipping = double.tryParse(shipText) ?? 0;
    return subtotal + shipping;
  }
  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: _screenshotController,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: GestureDetector(
                // ✅ ចាប់ Tap លើផ្ទៃទំនេរ
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "បញ្ជីទំនិញ / Items List",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),

                      ...CreateInvoiceSheet.items
                          .asMap()
                          .entries
                          .map((entry) => _buildItemCard(entry.key))
                          .toList(),

                      TextButton.icon(
                        onPressed: () => setState(
                              () => CreateInvoiceSheet.items.add({
                            'desc': TextEditingController(),
                            'qty': TextEditingController(text: '1'),
                            'price': TextEditingController(text: ''),
                          }),
                        ),
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        label: const Text(
                          "បន្ថែមទំនិញថ្មី",
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                      const Divider(height: 30, thickness: 1),

                      const Text(
                        "ព័ត៌មានអ្នកទិញ / Buyer Info",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _buildInput(
                        "ឈ្មោះអ្នកទិញ / Buyer Name",
                        CreateInvoiceSheet.cusName,
                      ),
                      _buildInput(
                        "លេខទូរស័ព្ទ / Phone",
                        CreateInvoiceSheet.cusPhone,
                        isNum: true,
                      ),
                      _buildInput(
                        "អាសយដ្ឋាន / Address",
                        CreateInvoiceSheet.cusAddress,
                      ),
                      _buildInput(
                        "ថ្លៃដឹកជញ្ជូន / Shipping (៛)",
                        CreateInvoiceSheet.shipPrice,
                        isNum: true,
                        isPrice: true,
                        onChanged: (v) => setState(() {}),
                      ),
                      const SizedBox(height: 20),

                      _buildQRUploadSection(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
            _buildActionSection(),
          ],
        ),
      ),
    );
  }


  Widget _buildQRUploadSection() {
    return Column(
      children: [
        const Text(
          "QR Code សម្រាប់បង់ប្រាក់ (ABA / KHQR)",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickAndCropQRCode,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: CreateInvoiceSheet.qrFile != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                CreateInvoiceSheet.qrFile!,
                fit: BoxFit.cover,
              ),
            )
                : const Icon(
              Icons.qr_code_scanner,
              size: 60,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "បង្កើតវិក្កយបត្រអាជីព",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onAction({'type': 'history'});
                },
                icon: const Icon(Icons.history, color: Colors.blue),
              ),
              IconButton(
                onPressed: _resetInvoice,
                icon: const Icon(Icons.refresh, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }


  // 🎯 កែប្រែទី៤៖ មុខងារបង្ហាញកាតទំនិញ បន្ថែមជួរលេខរាប់ឈរ (1, 2, 3...) នៅពីមុខ
  Widget _buildItemCard(int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔢 លេខរាប់ជួរឈរទំនិញ
            Text(
              "ទំនិញទី ${index + 1}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            _buildInput("ឈ្មោះទំនិញ", CreateInvoiceSheet.items[index]['desc']!),
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    "ចំនួន",
                    CreateInvoiceSheet.items[index]['qty']!,
                    isNum: true,
                    onChanged: (v) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInput(
                    "តម្លៃរាយ ៛",
                    CreateInvoiceSheet.items[index]['price']!,
                    isNum: true,
                    isPrice:
                    true, // 🎯 ថែមប៉ារ៉ាម៉ែត្រនេះ ដើម្បីឱ្យវាលោតសញ្ញាក្បៀសតាមដៃ
                    onChanged: (v) {
                      setState(() {});
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () =>
                      setState(() => CreateInvoiceSheet.items.removeAt(index)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildActionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "សរុបចុងក្រោយ៖",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "${NumberFormat('#,###').format(_calculateGrandTotal())} ៛",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _actionBtn(Icons.save, "Save", Colors.blue, () {
                widget.onAction({
                  'type': 'save',
                  'total': _calculateGrandTotal(),
                });
              }),
              _actionBtn(Icons.camera_alt, "Capture", Colors.purple, () {
                widget.onAction({
                  'type': 'screenshot',
                  'total': _calculateGrandTotal(),
                });
              }),
            ],
          ),
        ],
      ),
    );
  }


  Widget _actionBtn(
      IconData icon,
      String label,
      Color color,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  // 🎯 កែប្រែទី៥៖ មុខងារបង្កើត TextField ថ្មីដោយបញ្ចូលប្រព័ន្ធ Format ដាក់ក្បៀស
  Widget _buildInput(
      String label,
      TextEditingController ctrl, {
        bool isNum = false,
        bool isPrice = false, // 🎯 ថែមប៉ារ៉ាម៉ែត្រនេះដើម្បីសម្គាល់ប្រឡោះលុយ
        Function(String)? onChanged,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        keyboardType: isNum
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        // 🎯 បន្ថែមកូដត្រង់នេះ៖ បើជាប្រឡោះលុយ ឱ្យវាចាប់ហៅ Class Format ក្បៀសអូតូភ្លាមៗ
        inputFormatters: isPrice
            ? [
          FilteringTextInputFormatter.digitsOnly,
          ThousandsSeparatorInputFormatter(),
        ]
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: isPrice
              ? '0'
              : null, // បើជាប្រឡោះតម្លៃលក់ ឱ្យបង្ហាញគំរូ 0 ស្រអាប់ៗ
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}


// 🎯 កែប្រែទី៦៖ Class សម្រាប់ Format សញ្ញាក្បៀស គ្រប់គ្រងទីតាំង Cursor ត្រឹមត្រូវ ១០០%
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }


    // លុបសញ្ញាក្បៀសចាស់ៗចេញ
    String strippedValue = newValue.text.replaceAll(',', '');


    // បំប្លែងទៅជាលេខ
    int? numValue = int.tryParse(strippedValue);
    if (numValue == null) return oldValue;


    // ដាក់សញ្ញាក្បៀសខ្ទង់ពាន់
    final formatter = NumberFormat('#,###');
    String formattedValue = formatter.format(numValue);


    return TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }
}



