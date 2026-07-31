import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_edit_withdrawal_screen.dart';

class AdminWithdrawalListScreen extends StatelessWidget {
  const AdminWithdrawalListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ព័ត៌មានដកប្រាក់អ្នកប្រើប្រាស់',
            style: TextStyle(fontFamily: 'Siemreap', fontSize: 16)),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('full_name_kh', isNotEqualTo: '') // មានឈ្មោះពេញ
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('មិនទាន់មានអ្នកប្រើប្រាស់បំពេញព័ត៌មានដកប្រាក់ទេ',
                  style: TextStyle(fontFamily: 'Siemreap')),
            );
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final String userId = users[index].id;
              final String name = userData['name'] ?? 'គ្មានឈ្មោះ';
              final String fullNameKh = userData['full_name_kh'] ?? '';
              final String bank = userData['bank_name'] ?? '';
              final String accountNumber = userData['bank_account_number'] ?? '';
              final String idCard = userData['id_card'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                  ),
                  title: Text(name, style: const TextStyle(fontFamily: 'Siemreap')),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (fullNameKh.isNotEmpty)
                        Text('ឈ្មោះពេញ: $fullNameKh', style: const TextStyle(fontSize: 12)),
                      if (bank.isNotEmpty)
                        Text('ធនាគារ: $bank - $accountNumber', style: const TextStyle(fontSize: 12)),
                      if (idCard.isNotEmpty)
                        Text('អត្តសញ្ញាណ: $idCard', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminEditWithdrawalScreen(
                          userId: userId,
                          userData: userData,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}