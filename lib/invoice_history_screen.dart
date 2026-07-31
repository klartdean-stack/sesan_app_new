import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ប្រវត្តិវិក្កយបត្រ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🎯 ទាញទិន្នន័យពី Firebase ដោយតម្រៀបតាមថ្ងៃខែ (ថ្មីបំផុតនៅខាងលើ)
        stream: FirebaseFirestore.instance
            .collection('invoices')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text("មានបញ្ហាត្រង់ទិន្នន័យ"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("មិនទាន់មានប្រវត្តិបុងនៅឡើយ"));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // បម្លែងកាលបរិច្ឆេទ
              String dateStr = "";
              if (data['created_at'] != null) {
                DateTime dt = (data['created_at'] as Timestamp).toDate();
                dateStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  // 🎯 បង្ហាញឈ្មោះភ្ញៀវពិតប្រាកដ
                  title: Text(
                    data['buyer_name'] ?? "ភ្ញៀវគ្មានឈ្មោះ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "សរុប៖ ${data['total_amount'] ?? '0'} ៛",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(dateStr, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                  // 🎯 ចុចមើល Detail
                  onTap: () => _showInvoiceDetail(context, data),
                  // ចុចជាប់ដើម្បីលុប (Option បន្ថែម)
                  onLongPress: () => _confirmDelete(doc.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 🎯 មុខងារបង្ហាញផ្ទាំង Detail លម្អិត
  void _showInvoiceDetail(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.blue),
            SizedBox(width: 10),
            Text("ព័ត៌មានវិក្កយបត្រ"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            _buildDetailRow("ឈ្មោះអ្នកទិញ:", data['buyer_name']),
            _buildDetailRow("លេខទូរស័ព្ទ:", data['buyer_phone']),
            _buildDetailRow("អាសយដ្ឋាន:", data['buyer_address']),
            _buildDetailRow("ទឹកប្រាក់សរុប:", "${data['total_amount']} ៛"),
            const Divider(),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                "💡 រូបភាពបុងពេញលេញ ត្រូវបានរក្សាទុកក្នុង Gallery របស់អ្នករួចរាល់ហើយ។",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("បិទ", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(
              text: "$label ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value ?? "---"),
          ],
        ),
      ),
    );
  }

  // មុខងារសួរមុននឹងលុប
  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("លុបប្រវត្តិ?"),
        content: const Text("តើអ្នកប្រាកដថាចង់លុបប្រវត្តិបុងនេះមែនទេ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ទេ"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('invoices')
                  .doc(docId)
                  .delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("លុប", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}