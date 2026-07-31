import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ShareholderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const ShareholderDetailScreen({super.key, required this.data});

  @override
  State<ShareholderDetailScreen> createState() =>
      _ShareholderDetailScreenState();
}

class _ShareholderDetailScreenState extends State<ShareholderDetailScreen> {
  final _amountController = TextEditingController();
  String? _selectedReceiverId;
  String? _selectedReceiverName;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF0F1419),
        body: CustomScrollView(
          slivers: [
          // Sliver App Bar with avatar
          SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: const Color(0xFF161B2E),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E3A5F),
                    const Color(0xFF161B2E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.data['name'] ?? 'មិនស្គាល់',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                ],
              ),
            ),
          ),
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),

        // Content
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Stats Cards
                Row(
                children: [
                Expanded(
                child: _buildStatCard(
                  'ហ៊ុនសរុប',
                  '${widget.data['total_shares'] ?? 0}',
                  Icons.pie_chart_outline,
                  const Color(0xFF58A6FF),
                ),
                ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'វិនិយោគ',
                      '${NumberFormat('#,###').format(widget.data['invested_amount'] ?? 0)} ៛',
                      Icons.account_balance_wallet_outlined,
                      const Color(0xFF3FB950),
                    ),
                  ),
                ],
                ),
                    const SizedBox(height: 24),

                    // Info Section
                    const Text(
                      'ព័ត៌មានផ្ទាល់ខ្លួន',
                      style: TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildInfoItem(
                      icon: Icons.phone_outlined,
                      label: 'លេខទូរស័ព្ទ',
                      value: widget.data['phone'] ?? 'មិនមាន',
                    ),
                    _buildInfoItem(
                      icon: Icons.badge_outlined,
                      label: 'អត្តសញ្ញាណប័ណ្ណ',
                      value: widget.data['id_card'] ?? 'មិនមាន',
                    ),
                    _buildInfoItem(
                      icon: Icons.location_on_outlined,
                      label: 'អាសយដ្ឋាន',
                      value: widget.data['address'] ?? 'មិនមាន',
                      isLongText: true,
                    ),
                    _buildInfoItem(
                      icon: Icons.account_balance_outlined,
                      label: 'គណនីធនាគារ',
                      value: widget.data['bank_account'] ?? 'មិនមាន',
                    ),

                    const SizedBox(height: 30),

                    // Transfer Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF0883E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _showTransferBottomSheet(context),
                        icon: const Icon(Icons.swap_horiz, size: 24),
                        label: const Text(
                          "ផ្ទេរហ៊ុនទៅអ្នកផ្សេង",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
            ),
        ),
          ],
        ),
    );
  }

  Widget _buildStatCard(
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2329),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
          child: Icon(icon, color: color, size: 20),
        ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 12,
                  fontFamily: 'Siemreap',
                ),
              ),
            ],
        ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool isLongText = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF30363D),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        isLongText ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF58A6FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF58A6FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Siemreap',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TRANSFER BOTTOM SHEET - Fix Overflow
  // ═══════════════════════════════════════════════════════════
  void _showTransferBottomSheet(BuildContext context) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true, // អនុញ្ញាតឲ្យ sheet ឡើងខ្ពស់
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return DraggableScrollableSheet(
                  initialChildSize: 0.7,
                  maxChildSize: 0.9,
                  minChildSize: 0.5,
                  builder: (_, scrollController) {
                    return Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E2329),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: SingleChildScrollView(
                            controller: scrollController,
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              // Handle bar
                              Center(
                              child: Container(
                              width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF30363D),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0883E).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.swap_horiz,
                                    color: Color(0xFFF0883E),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ផ្ទេរហ៊ុនចេញ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Siemreap',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'ពី ${widget.data['name'] ?? 'មិនស្គាល់'}',
                                        style: const TextStyle(
                                          color: Color(0xFF8B949E),
                                          fontSize: 13,
                                          fontFamily: 'Siemreap',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Available shares info
                            Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1419),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF30363D),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                  const Icon(
                                  Icons.pie_chart_outline,
                                  color: Color(0xFF58A6FF),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'ហ៊ុនដែលមានសរុប',
                                          style: TextStyle(
                                            color: Color(0xFF8B949E),
                                            fontSize: 12,
                                            fontFamily: 'Siemreap',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${widget.data['total_shares'] ?? 0} ហ៊ុន',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                ),
                                  ],
                                ),
                            ),
                            const SizedBox(height: 20),

                            // Receiver Dropdown
                            StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('shareholders')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF58A6FF),
                                      ),
                                    );
                                  }

                                  final users = snapshot.data!.docs
                                      .where((doc) =>
                                  doc.id != widget.data['uid'])
                                      .toList();

                                  if (users.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F1419),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: Color(0xFFF0883E),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'មិនមានអ្នកទទួលផ្សេងទៀត',
                                              style: TextStyle(
                                                color: Color(0xFF8B949E),
                                                fontFamily: 'Siemreap',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return Container(
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF0F1419),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF30363D),
                                          ),
                                      ),
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true, // ការពារ overflow
                                      decoration: InputDecoration(
                                        labelText: "ជ្រើសរើសអ្នកទទួល",
                                        labelStyle: const TextStyle(
                                          color: Color(0xFF8B949E),
                                          fontFamily: 'Siemreap',
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: Color(0xFF58A6FF),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: Colors.transparent,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                      ),
                                      dropdownColor: const Color(0xFF1E2329),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Siemreap',
                                        fontSize: 14,
                                      ),
                                      items: users.map((doc) {
                                        final d =
                                        doc.data() as Map<String, dynamic>;
                                        return DropdownMenuItem(
                                          value: doc.id,
                                          child: Text(
                                            d['name'] ?? "គ្មានឈ្មោះ",
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        final selectedDoc = users.firstWhere(
                                              (doc) => doc.id == val,
                                        );
                                        setDialogState(() {
                                          _selectedReceiverId = val;
                                          _selectedReceiverName =
                                          (selectedDoc.data() as Map<
                                              String,
                                              dynamic>)['name'];
                                        });
                                      },
                                    ),
                                  );
                                },
                            ),
                            const SizedBox(height: 16),

                            // Amount Input
                            Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1419),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF30363D),
                                  ),
                                ),
                                child: TextField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  decoration: InputDecoration(
                                    labelText: "ចំនួនហ៊ុនត្រូវផ្ទេរ",
                                    labelStyle: const TextStyle(
                                      color: Color(0xFF8B949E),
                                      fontFamily: 'Siemreap',
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.numbers,
                                      color: Color(0xFF58A6FF),
                                    ),
                                    suffixText: 'ហ៊ុន',
                                    suffixStyle: const TextStyle(
                                      color: Color(0xFF8B949E),
                                      fontFamily: 'Siemreap',
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                            ),
                            const SizedBox(height: 24),

                            // Selected receiver info
                            if (_selectedReceiverName != null)
                        Container(
                        padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                    color: const Color(0xFF3FB950).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                    color: const Color(0xFF3FB950).withOpacity(0.3),
                    ),
                    ),
                    child: Row(
                    children: [
                    const Icon(
                    Icons.check_circle,
                    color: Color(0xFF3FB950),
                    size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                    child: Text(
                    'អ្នកទទួល: $_selectedReceiverName',
                    style: const TextStyle(
                    color: Color(0xFF3FB950),
                    fontFamily: 'Siemreap',
                    fontSize: 13,
                    ),
                    ),
                    ),
                    ],
                    ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                    children: [
                    Expanded(
                    child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B949E),
                    side: const BorderSide(
                    color: Color(0xFF30363D),
                    ),
                    padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    ),
                      child: const Text(
                        "បោះបង់",
                        style: TextStyle(
                          fontFamily: 'Siemreap',
                          fontSize: 15,
                        ),
                      ),
                    ),
                    ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            final amount =
                                int.tryParse(_amountController.text) ?? 0;
                            if (_selectedReceiverId != null &&
                                amount > 0 &&
                                amount <=
                                    (widget.data['total_shares'] ?? 0)) {
                              _executeTransfer(context, amount);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFFF85149),
                                  content: Text(
                                    "សូមពិនិត្យចំនួនហ៊ុនឡើងវិញ",
                                    style: TextStyle(
                                      fontFamily: 'Siemreap',
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF0883E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "បញ្ជាក់ការផ្ទេរ",
                            style: TextStyle(
                              fontFamily: 'Siemreap',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                        ),
                    );
                  },
              );
            },
        ),
    );
  }

  Future<void> _executeTransfer(BuildContext context, int amount) async {
    final batch = FirebaseFirestore.instance.batch();

    DocumentReference senderRef = FirebaseFirestore.instance
        .collection('shareholders')
        .doc(widget.data['uid']);
    DocumentReference receiverRef = FirebaseFirestore.instance
        .collection('shareholders')
        .doc(_selectedReceiverId);
    DocumentReference historyRef =
    FirebaseFirestore.instance.collection('transfer_history').doc();

    try {
      double shareValue =
          ((widget.data['invested_amount'] ?? 0) /
              (widget.data['total_shares'] ?? 1)) *
              amount;batch.update(senderRef, {
        'total_shares': FieldValue.increment(-amount),
        'invested_amount': FieldValue.increment(-shareValue.toInt()),
      });
      batch.update(receiverRef, {
        'total_shares': FieldValue.increment(amount),
        'invested_amount': FieldValue.increment(shareValue.toInt()),
      });
      batch.set(historyRef, {
        'from_name': widget.data['name'],
        'to_name': _selectedReceiverName,
        'amount': amount,
        'share_value': shareValue.toInt(),
        'date': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF3FB950),
            content: Text(
              "✅ ផ្ទេរជោគជ័យ!",
              style: TextStyle(fontFamily: 'Siemreap'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFF85149),
            content: Text(
              "បរាជ័យ: $e",
              style: const TextStyle(fontFamily: 'Siemreap'),
            ),
          ),
        );
      }
    }
  }
}