import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';


class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});


  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}


class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _uid = '';
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadUid();
  }


  Future<void> _loadUid() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_uid') ?? '';
    if (mounted)
      setState(() {
        _uid = uid;
        _isLoading = false;
      });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F121F),
      appBar: AppBar(
        title: const Text(
          'ប្រវត្តិនៃការវិនិយោគ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'Siemreap',
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _uid.isEmpty
          ? const Center(
        child: Text(
          'សូមចូលប្រើប្រាស់គណនីសិន',
          style: TextStyle(color: Colors.white, fontFamily: 'Siemreap'),
        ),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('investment_requests')
            .where('user_id', isEqualTo: _uid) // ✅ ប្រើ _uid
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'មានបញ្ហាត្រង់ Index ឬ ឈ្មោះ Field',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'មិនទាន់មានប្រវត្តិទិញនៅឡើយទេ',
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Siemreap',
                ),
              ),
            );
          }


          var docs = snapshot.data!.docs;


          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;


              Color statusColor = Colors.orange;
              String statusText = 'កំពុងពិនិត្យ';
              if (data['status'] == 'success') {
                statusColor = Colors.greenAccent;
                statusText = 'ជោគជ័យ';
              } else if (data['status'] == 'rejected') {
                statusColor = Colors.redAccent;
                statusText = 'បដិសេធ';
              }
              String formattedDate = '';
              String dividendDate = '';
              if (data['timestamp'] != null) {
                DateTime date = (data['timestamp'] as Timestamp).toDate();
                formattedDate = DateFormat(
                  'dd/MM/yyyy HH:mm',
                ).format(date);
                DateTime nextYear = DateTime(
                  date.year + 1,
                  date.month,
                  date.day,
                );
                dividendDate = DateFormat('dd/MM/yyyy').format(nextYear);
              }


              return Card(
                color: const Color(0xFF1E2235),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  onTap: () {
                    if (data['receipt_url'] != null &&
                        data['receipt_url'] != '') {
                      _showReceiptDialog(context, data['receipt_url']);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('មិនមានរូបភាពបង្កាន់ដៃឡើយ'),
                        ),
                      );
                    }
                  },
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'វិនិយោគចំនួន ${data['shares'] ?? 0} ហ៊ុន',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(
                        'តម្លៃសរុប៖ ${data['total_price'] ?? 0} ៛',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'កាលបរិច្ឆេទ៖',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'ភាគលាភដំបូង៖',
                                style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                dividendDate,
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white10,
                    size: 14,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


void _showReceiptDialog(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}



