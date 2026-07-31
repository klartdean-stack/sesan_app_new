import 'package:flutter/material.dart';


class UserDetailScreen extends StatelessWidget {
  final Map<String, dynamic> userData;


  const UserDetailScreen({super.key, required this.userData});


  @override
  Widget build(BuildContext context) {
    // ទាញយក Key ទាំងអស់ដែលមានក្នុង Map
    final keys = userData.keys.toList();


    return Scaffold(
      backgroundColor: const Color(0xFF0F121F),
      appBar: AppBar(
        title: Text(
          userData['name'] ?? "ព័ត៌មានលម្អិត",
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF161B2E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: keys.length,
        itemBuilder: (context, index) {
          String key = keys[index];
          var value = userData[key];


          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    key, // បង្ហាញឈ្មោះ Key (ឧទាហរណ៍៖ sesan_id, password...)
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Text(" :  ", style: TextStyle(color: Colors.white54)),
                Expanded(
                  flex: 3,
                  child: Text(
                    "$value", // បង្ហាញតម្លៃទិន្នន័យ
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}



