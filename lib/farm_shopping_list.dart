import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class FarmShoppingList extends StatefulWidget {
  const FarmShoppingList({super.key});

  @override
  State<FarmShoppingList> createState() => _FarmShoppingListState();
}

class _FarmShoppingListState extends State<FarmShoppingList> {
  final ScreenshotController _screenshotController = ScreenshotController();

  // ១. បញ្ជីចាប់ផ្តើមពីទទេ (Empty List) តាមបំណងរបស់មេ
  final List<Map<String, dynamic>> _items = [];

  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  // មុខងារថតរូប និងផ្ញើចេញ
  void _shareAsImage() async {
    if (_items.isEmpty) return; // បើគ្មានអីវ៉ាន់ មិនបាច់ Share ទេ

    await _screenshotController.capture().then((Uint8List? image) async {
      if (image != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = await File(
          '${directory.path}/shopping_list.png',
        ).create();
        await imagePath.writeAsBytes(image);
        await Share.shareXFiles([
          XFile(imagePath.path),
        ], text: 'បញ្ជីអីវ៉ាន់ចម្ការពី App Sesan');
      }
    });
  }

  // មុខងារបន្ថែមអីវ៉ាន់ថ្មី
  void _addItem() {
    if (_nameCtrl.text.isNotEmpty && _qtyCtrl.text.isNotEmpty) {
      setState(() {
        _items.add({
          "name": _nameCtrl.text,
          "qty": _qtyCtrl.text,
          "isBought": false,
        });
      });
      _nameCtrl.clear();
      _qtyCtrl.clear();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "បញ្ជីទិញអីវ៉ាន់",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        backgroundColor: Colors.cyan[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _shareAsImage, icon: const Icon(Icons.share)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Screenshot(
              controller: _screenshotController,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildInvoiceHeader(),
                    const Divider(thickness: 1.5),

                    // បើបញ្ជីទទេ បង្ហាញអក្សរប្រាប់កសិករ
                    _items.isEmpty
                        ? const Expanded(
                            child: Center(
                              child: Text(
                                "មិនទាន់មានទំនិញក្នុងបញ្ជី\nសូមចុចប៊ូតុងខាងក្រោមដើម្បីថែម",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : Expanded(
                            child: ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                return _buildItemRow(index);
                              },
                            ),
                          ),

                    const Divider(),
                    const Text(
                      "បង្កើតដោយ៖ App Sesan - ជំនួយការកសិករ",
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Checkbox(
          value: _items[index]['isBought'],
          activeColor: Colors.cyan[800],
          onChanged: (val) => setState(() => _items[index]['isBought'] = val),
        ),
        title: Text(
          _items[index]['name'],
          style: TextStyle(
            decoration: _items[index]['isBought']
                ? TextDecoration.lineThrough
                : null,
            color: _items[index]['isBought'] ? Colors.grey : Colors.black,
          ),
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _items[index]['qty'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 5),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () =>
                  setState(() => _items.removeAt(index)), // មុខងារលុប
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SESAN APP",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.cyan[800],
              ),
            ),
            const Text("បញ្ជីទិញអីវ៉ាន់ចម្ការ", style: TextStyle(fontSize: 14)),
          ],
        ),
        const Icon(Icons.shopping_cart_outlined, size: 40, color: Colors.cyan),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "ថែមអីវ៉ាន់",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan[800],
                minimumSize: const Size(0, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 55,
            decoration: BoxDecoration(
              color: Colors.orange[800],
              borderRadius: BorderRadius.circular(15),
            ),
            child: IconButton(
              onPressed: _shareAsImage,
              icon: const Icon(Icons.camera_alt, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ថែមមុខទំនិញថ្មី"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: "ឈ្មោះអីវ៉ាន់",
                hintText: "ឧ៖ ជីអ៊ុយរ៉េ",
              ),
            ),
            TextField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(
                labelText: "ចំនួន",
                hintText: "ឧ៖ 10 បាវ",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("បោះបង់"),
          ),
          ElevatedButton(onPressed: _addItem, child: const Text("បញ្ចូល")),
        ],
      ),
    );
  }
}
