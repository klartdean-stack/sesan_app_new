import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});


  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}


class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isLoading = false;
  String _selectedType = 'info';


  final _types = [
    {
      'value': 'info',
      'label': 'ព័ត៌មាន',
      'color': Color(0xFF3B5BFF),
      'icon': Icons.info_rounded,
    },
    {
      'value': 'success',
      'label': 'ជោគជ័យ',
      'color': Color(0xFF2DCB73),
      'icon': Icons.check_circle_rounded,
    },
    {
      'value': 'warning',
      'label': 'ព្រមាន',
      'color': Color(0xFFFF6B35),
      'icon': Icons.warning_amber_rounded,
    },
  ];


  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }


  Future<void> _postNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('សូមបំពេញចំណងជើង និងខ្លឹមសារ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }


    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': _titleController.text.trim(),
        'message': _bodyController.text.trim(),
        'type': _selectedType, // ✅ save type
        'created_at': FieldValue.serverTimestamp(),
        'sender': 'Admin',
      });
      _titleController.clear();
      _bodyController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ បញ្ជូនដំណឹងរួចរាល់!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _deleteNotification(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'លុបដំណឹង?',
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        content: const Text(
          'ពិតជាចង់លុបដំណឹងនេះ?',
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ទេ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('លុប', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );


    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ លុបដំណឹងរួចរាល់!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Color _typeColor(String type) {
    switch (type) {
      case 'warning':
        return const Color(0xFFFF6B35);
      case 'success':
        return const Color(0xFF2DCB73);
      default:
        return const Color(0xFF3B5BFF);
    }
  }


  IconData _typeIcon(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'success':
        return Icons.check_circle_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        title: const Text(
          'គ្រប់គ្រងដំណឹង',
          style: TextStyle(
            fontFamily: 'Siemreap',
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Column(
        children: [
          // ── Post Form ─────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                  '📢 បង្កើតដំណឹងថ្មី',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 16),


                // ── Type Selector ──────────────────────
                Row(
                  children: _types.map((t) {
                    final isSelected = _selectedType == t['value'];
                    final color = t['color'] as Color;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                              () => _selectedType = t['value'] as String,
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withOpacity(0.1)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                t['icon'] as IconData,
                                color: isSelected ? color : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t['label'] as String,
                                style: TextStyle(
                                  color: isSelected ? color : Colors.grey,
                                  fontSize: 11,
                                  fontFamily: 'Siemreap',
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),


                // ── Title ──────────────────────────────
                TextField(
                  controller: _titleController,
                  style: const TextStyle(fontFamily: 'Siemreap'),
                  decoration: InputDecoration(
                    labelText: 'ចំណងជើង *',
                    labelStyle: const TextStyle(fontFamily: 'Siemreap'),
                    prefixIcon: const Icon(Icons.title_rounded),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF3B5BFF),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),


                // ── Body ───────────────────────────────
                TextField(
                  controller: _bodyController,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'Siemreap'),
                  decoration: InputDecoration(
                    labelText: 'ខ្លឹមសារដំណឹង *',
                    labelStyle: const TextStyle(fontFamily: 'Siemreap'),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 60),
                      child: Icon(Icons.notes_rounded),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF3B5BFF),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),


                // ── Submit Button ───────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B5BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _postNotification,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                    label: Text(
                      _isLoading ? 'កំពុងបញ្ជូន...' : 'បោះពុម្ពផ្សាយ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Siemreap',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),


          // ── List Header ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Text(
                  'ដំណឹងដែលបានបោះពុម្ព',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Siemreap',
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('announcements')
                      .snapshots(),
                  builder: (_, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B5BFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count ដំណឹង',
                        style: const TextStyle(
                          color: Color(0xFF3B5BFF),
                          fontSize: 12,
                          fontFamily: 'Siemreap',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),


          // ── List ──────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'មិនទាន់មានដំណឹងទេ',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                  );
                }


                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final type = data['type'] as String? ?? 'info';
                    final color = _typeColor(type);


                    String date = '';
                    if (data['created_at'] != null) {
                      final dt = (data['created_at'] as Timestamp).toDate();
                      date = DateFormat('dd/MM/yyyy • HH:mm').format(dt);
                    }


                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border(
                          left: BorderSide(color: color, width: 4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_typeIcon(type), color: color, size: 20),
                        ),
                        title: Text(
                          data['title'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Siemreap',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              data['message'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                                fontFamily: 'Siemreap',
                              ),
                            ),
                            if (date.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                date,
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_rounded,
                            color: Colors.red,
                            size: 22,
                          ),
                          onPressed: () => _deleteNotification(docId),
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



