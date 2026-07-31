import 'package:flutter/material.dart';

class DisputePolicyScreen extends StatelessWidget {
  const DisputePolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("គោលការណ៍គតិយុត្ត"),
        backgroundColor: Colors.grey[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "សេចក្តីជូនដំណឹង និងលក្ខខណ្ឌគតិយុត្តនៃការដាក់ពាក្យបណ្ដឹង",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.red,
              ),
            ),
            const Divider(height: 30),
            _buildLegalText(
              "១. និយមន័យនៃបណ្ដឹងស្របច្បាប់៖",
              "ការដាក់ពាក្យបណ្ដឹង (Dispute) អាចធ្វើទៅបានលុះត្រាតែមានភស្តុតាងបញ្ជាក់ច្បាស់លាស់អំពីការរំលោភលើកិច្ចសន្យាទិញ-លក់ ដូចជា៖\n"
                  "• អវត្តមាននៃការផ្តល់ទំនិញ (Non-Delivery): រយៈពេលលើសពី ០3 ថ្ងៃនៃថ្ងៃធ្វើការ គិតចាប់ពីថ្ងៃដែលការបញ្ជាទិញត្រូវបានបញ្ជាក់ជាផ្លូវការ។\n"
                  "• អនុលោមភាពទំនិញ (Product Non-Conformity): ទំនិញដែលទទួលបានមានលក្ខណៈខុសប្លែកទាំងស្រុងពីការពិពណ៌នា ឬមានការខូចខាតជាទម្ងន់។",
            ),
            _buildLegalText(
              "២. ការដាក់កម្រិតលើបណ្ដឹងអសុពលភាព៖",
              "ប្រព័ន្ធនឹងមិនទទួលយក ឬដោះស្រាយរាល់បណ្ដឹងដែលកើតចេញពី៖\n"
                  "• ការផ្លាស់ប្តូរការសម្រេចចិត្តផ្ទាល់ខ្លួន (Change of mind) ដោយគ្មានមូលហេតុបច្ចេកទេស។\n"
                  "• ការពន្យារពេលបន្តិចបន្តួចដែលបង្កឡើងដោយភ្នាក់ងារដឹកជញ្ជូន ឬករណីប្រធានស័ក្តិ (Force Majeure)។",
            ),
            _buildLegalText(
              "៣. ផលវិបាកនៃការផ្តល់ព័ត៌មានមិនពិត៖",
              "រាល់ការដាក់ពាក្យបណ្ដឹងដោយចេតនាទុច្ចរិត ក្នុងគោលបំណងបង្ខូចកេរ្តិ៍ឈ្មោះអ្នកដទៃ ឬការផ្តល់ភស្តុតាងក្លែងក្លាយ គឺជាការរំលោភលើលក្ខខណ្ឌប្រើប្រាស់។ ម្ចាស់កម្មវិធីរក្សាសិទ្ធិក្នុងការបិទគណនី (Block Account) ជាអចិន្ត្រៃយ៍។",
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("ខ្ញុំបានអាន និងយល់ព្រម"),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalText(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
