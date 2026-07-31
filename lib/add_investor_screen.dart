import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class AddInvestorScreen extends StatefulWidget {
  const AddInvestorScreen({super.key});


  @override
  State<AddInvestorScreen> createState() => _AddInvestorScreenState();
}


class _AddInvestorScreenState extends State<AddInvestorScreen> {
  final TextEditingController _sesanIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;


  Future<void> _addInvestor() async {
    final sesanId = _sesanIdController.text.trim();


    if (sesanId.isEmpty || sesanId.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'សូមបញ្ចូល Sesan ID ឲ្យបាន 6 ខ្ទង់',
            style: TextStyle(fontFamily: 'Siemreap'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }


    setState(() => _isLoading = true);


    try {
      // ពិនិត្យថា sesan_id នេះមានមែនក្នុង collection users
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('sesan_id', isEqualTo: sesanId)
          .limit(1)
          .get();


      if (userQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'មិនមានអ្នកប្រើដែលមាន Sesan ID នេះទេ',
                style: TextStyle(fontFamily: 'Siemreap'),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }


      // ✅ ទាញយកទិន្នន័យពី collection users
      final userData = userQuery.docs.first.data();
      final userName = userData['name'] ?? 'មិនស្គាល់ឈ្មោះ';
      final photoUrl = userData['photoUrl'] ?? '';
      final userUid = userQuery.docs.first.id;


      // ✅ បន្ថែមចូល collection investors (ជាមួយ photoUrl និង UID)
      await FirebaseFirestore.instance
          .collection('investors')
          .doc(sesanId)
          .set({
        'sesan_id': sesanId,
        'name': _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : userName,
        'user_name': userName,
        'photo_url': photoUrl,
        'user_uid': userUid,
        'added_at': FieldValue.serverTimestamp(),
      });


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ បន្ថែម $sesanId ($userName) ចូលបញ្ជីអ្នកវិនិយោគដោយជោគជ័យ!',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Siemreap',
              ),
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        _sesanIdController.clear();
        _nameController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ មានបញ្ហា៖ $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _removeInvestor(String sesanId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'ដកចេញពីបញ្ជី',
          style: TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold),
        ),
        content: Text(
          'តើអ្នកចង់ដក $sesanId ចេញពីបញ្ជីអ្នកវិនិយោគមែនទេ?',
          style: const TextStyle(fontFamily: 'Siemreap'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('បោះបង់'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ដកចេញ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );


    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('investors')
          .doc(sesanId)
          .delete();


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('បានដកចេញពីបញ្ជីអ្នកវិនិយោគ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('មានបញ្ហា៖ $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'គ្រប់គ្រងអ្នកវិនិយោគ',
          style: TextStyle(fontFamily: 'Siemreap', fontSize: 16),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ផ្នែកបន្ថែមអ្នកវិនិយោគថ្មី
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'បន្ថែមអ្នកវិនិយោគថ្មី',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _sesanIdController,
                  decoration: InputDecoration(
                    labelText: 'Sesan ID (6 ខ្ទង់)',
                    hintText: 'ឧ. 123456',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.tag),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'ឈ្មោះសម្គាល់ (ស្រេចចិត្ត)',
                    hintText: 'ឧ. វណ្ណា',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _addInvestor,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.add_circle_outline),
                    label: Text(
                      _isLoading ? 'កំពុងដំណើរការ...' : 'បន្ថែមចូលបញ្ជី',
                      style: const TextStyle(fontFamily: 'Siemreap'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),


          // បញ្ជីអ្នកវិនិយោគបច្ចុប្បន្ន
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('investors')
                  .orderBy('added_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }


                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 60,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'មិនទាន់មានអ្នកវិនិយោគនៅឡើយ',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                      ],
                    ),
                  );
                }


                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final sesanId = data['sesan_id'] ?? '';
                    final name = data['name'] ?? 'មិនស្គាល់';


                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          child: const Icon(Icons.person, color: Colors.orange),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                        subtitle: Text(
                          'ID: $sesanId',
                          style: const TextStyle(
                            fontFamily: 'Siemreap',
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeInvestor(sesanId),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}



