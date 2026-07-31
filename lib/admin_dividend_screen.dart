import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDividendScreen extends StatefulWidget {
  const AdminDividendScreen({super.key});

  @override
  State<AdminDividendScreen> createState() => _AdminDividendScreenState();
}

class _AdminDividendScreenState extends State<AdminDividendScreen> {
  final TextEditingController _amountPerShareController =
      TextEditingController();
  bool _isLoading = false;

  // 🎯 Logic សម្រាប់ចែកលុយឱ្យគ្រប់គ្នា
  Future<void> _distributeDividends() async {
    double? amountPerShare = double.tryParse(_amountPerShareController.text);
    if (amountPerShare == null || amountPerShare <= 0) {
      _showSnackBar("សូមបញ្ចូលចំនួនទឹកប្រាក់ឱ្យបានត្រឹមត្រូវ!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ១. ទាញយកបញ្ជី Shareholders ទាំងអស់ដែលមានហ៊ុន (total_shares > 0)
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('shareholders')
          .where('total_shares', isGreaterThan: 0)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        int shares = doc['total_shares'] ?? 0;
        double dividendEarned = shares * amountPerShare;

        // ២. បូកលុយចូលក្នុង balance របស់ម្នាក់ៗ
        batch.update(doc.reference, {
          'balance': FieldValue.increment(dividendEarned),
          'total_earned': FieldValue.increment(
            dividendEarned,
          ), // រក្សាទុកប្រវត្តិសរុប
        });
      }

      // ៣. កត់ត្រាប្រវត្តិការចែកលុយរបស់ក្រុមហ៊ុន
      DocumentReference historyRef = FirebaseFirestore.instance
          .collection('dividend_history')
          .doc();
      batch.set(historyRef, {
        'amount_per_share': amountPerShare,
        'timestamp': FieldValue.serverTimestamp(),
        'total_investors': snapshot.docs.length,
      });

      await batch.commit();
      _showSnackBar("✅ ចែកលុយចំណេញជោគជ័យដល់ ${snapshot.docs.length} នាក់!");
      _amountPerShareController.clear();
    } catch (e) {
      _showSnackBar("❌ មានបញ្ហា៖ $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ចែកប្រាក់ចំណេញ")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "បញ្ចូលចំនួនទឹកប្រាក់ចំណេញក្នុង ១ ហ៊ុន (៛)",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountPerShareController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "ឧទាហរណ៍៖ 500",
                suffixText: "៛",
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _distributeDividends,
                    icon: const Icon(Icons.payments),
                    label: const Text("បញ្ចេញប្រាក់ចំណេញឥឡូវនេះ"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 20,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
