import 'package:flutter/material.dart';


class ProductDetailScreen extends StatelessWidget {
  final Map<String, dynamic> productData;


  const ProductDetailScreen({super.key, required this.productData});


  @override
  Widget build(BuildContext context) {
    // ទាញយក Key ទាំងអស់ដែលមានក្នុង Document ទំនិញ
    final keys = productData.keys.toList();


    return Scaffold(
      backgroundColor: const Color(0xFF0F121F),
      appBar: AppBar(
        title: Text(
          productData['product_name'] ?? "ព័ត៌មានទំនិញ",
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
          var value = productData[key];


          // លក្ខខណ្ឌពិសេស៖ បើជា Key រូបភាព ឱ្យវាបង្ហាញជារូបហ្មង
          if (key.contains('image_url') || key.contains('photo')) {
            return _buildImageTile(key, value);
          }


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
                    key, // បង្ហាញ Key ដូចជា price, quantity, seller_id...
                    style: const TextStyle(
                      color: Colors.orangeAccent,
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


  // Widget សម្រាប់បង្ហាញរូបភាពក្នុងបញ្ជី Detail
  Widget _buildImageTile(String key, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key,
          style: const TextStyle(
            color: Colors.orangeAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            value is List ? value[0] : value.toString(),
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: Colors.white24),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}



