import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';


// ── Constants ────────────────────────────────────────────────
const Color _bg = Color(0xFF0A0E1A);
const Color _text = Color(0xFFF0F4FF);
const Color _textMuted = Color(0xFF7B8BB2);
const Color _accent = Color(0xFFFF6B35);
const Color _accentGold = Color(0xFFFFD166);


// ── Luxury AppBar ─────────────────────────────────────────────
PreferredSizeWidget buildLuxuryAppBar(
    BuildContext context,
    VoidCallback onInfo,
    ) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(75),
    child: _LuxuryAppBar(onInfo: onInfo),
  );
}


class _LuxuryAppBar extends StatefulWidget {
  final VoidCallback onInfo;
  const _LuxuryAppBar({super.key, required this.onInfo});


  @override
  State<_LuxuryAppBar> createState() => _LuxuryAppBarState();
}


class _LuxuryAppBarState extends State<_LuxuryAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;


  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }


  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }


  // ── មុខងារបង្ហាញគោលការណ៍ (ភាសាច្បាប់ និងហិរញ្ញវត្ថុ - វែង និងលម្អិត) ──────────
  void _showDetailedPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1220),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(25, 20, 25, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Center(
                  child: Text(
                    'លក្ខខណ្ឌ និងសេចក្តីថ្លែងការណ៍គោលការណ៍ដេញថ្លៃ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _accentGold,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                ),
                const SizedBox(height: 30),


                _buildPolicyPara(
                  "១. សុពលភាពនៃកិច្ចសន្យាដេញថ្លៃ",
                  "រាល់ការដាក់តម្លៃដេញថ្លៃ (Bidding) ត្រូវបានចាត់ទុកជាការសន្យាជាគោលការណ៍តាមផ្លូវច្បាប់។ នៅពេលបញ្ចប់ការដេញថ្លៃ អ្នកដែលផ្តល់តម្លៃខ្ពស់បំផុត (Highest Bidder) នឹងមានកាតព្វកិច្ចហិរញ្ញវត្ថុក្នុងការទូទាត់សាច់ប្រាក់តាមតម្លៃដែលបានកំណត់។ ហាមដាច់ខាតការដេញថ្លៃលេងសើចដែលបង្កការខាតបង់ដល់ម្ចាស់ទំនិញ។",
                ),


                _buildPolicyPara(
                  "២. នីតិវិធីនៃការទូទាត់ និងដោះដូរ (Settlement Process)",
                  "• រយៈពេលទូទាត់៖ អ្នកឈ្នះត្រូវធ្វើការទំនាក់ទំនងទៅកាន់ម្ចាស់ទំនិញ ដើម្បីបូកសរុបការទូទាត់ក្នុងរយៈពេល ២៤ ទៅ ៤៨ ម៉ោង បន្ទាប់ពីការដេញថ្លៃបានបញ្ចប់។\n"
                      "• វិធីសាស្ត្រទូទាត់៖ ការផ្ទេរប្រាក់ត្រូវធ្វើឡើងតាមប្រព័ន្ធធនាគារផ្លូវការ ឬការជួបប្រគល់សាច់ប្រាក់ផ្ទាល់ (Escrow/COD) អាស្រ័យលើការព្រមព្រៀងរវាងភាគីទាំងពីរ។\n"
                      "• ការផ្ទៀងផ្ទាត់ទំនិញ៖ មុននឹងបញ្ចេញសាច់ប្រាក់ អ្នកទិញមានសិទ្ធិពិនិត្យស្ថានភាពបច្ចេកទេសទំនិញឱ្យបានត្រឹមត្រូវតាមការពិពណ៌នា។ បើទំនិញមិនដូចការរៀបរាប់ អ្នកទិញមានសិទ្ធិបដិសេធការទូទាត់។",
                ),
                _buildPolicyPara(
                  "៣. ការទទួលខុសត្រូវរបស់អ្នកដាក់ដេញថ្លៃ (Assignor)",
                  "ម្ចាស់ទំនិញត្រូវធានានូវតម្លាភាពនៃកម្មសិទ្ធិ និងស្ថានភាពបច្ចេកទេស។ ប្រសិនបើមានការភូតភរ ឬបន្លំលក្ខណៈបច្ចេកទេសដែលនាំឱ្យមានវិវាទហិរញ្ញវត្ថុ ម្ចាស់ទំនិញត្រូវទទួលខុសត្រូវទាំងស្រុងចំពោះមុខច្បាប់ និងត្រូវដកសិទ្ធិចេញពីប្រព័ន្ធជាអចិន្ត្រៃយ៍។",
                ),


                _buildPolicyPara(
                  "៤. វិធានការប្រឆាំងនឹងការបង្ខូចតម្លៃ (Market Integrity)",
                  "ហាមដាច់ខាតរាល់សកម្មភាពឃុបឃិត (Collusion) ដើម្បីដំឡើងតម្លៃបោកប្រាស់ (Shill Bidding)។ ប្រព័ន្ធនឹងធ្វើការត្រួតពិនិត្យដោយស្វ័យប្រវត្តិ ហើយរាល់គណនីដែលសង្ស័យនឹងត្រូវផ្អាកដំណើរការភ្លាមៗដើម្បីរក្សាតុល្យភាពទីផ្សារ និងផលប្រយោជន៍អ្នកប្រើប្រាស់ទូទៅ។",
                ),


                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const Text(
                  "* សេចក្តីបញ្ជាក់៖ វេទិកាសេសាន គឺជាស្ពានចម្លងបច្ចេកវិទ្យាសម្រាប់សម្រួលដល់ការដោះដូរ។ យើងលើកទឹកចិត្តឱ្យមានការដេញថ្លៃដោយសីលធម៌ និងភាពស្មោះត្រង់បំផុត។",
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Siemreap',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildPolicyPara(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Siemreap',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.6,
              fontFamily: 'Siemreap',
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0D1220).withOpacity(0.97),
                const Color(0xFF111827).withOpacity(0.97),
              ],
            ),
            border: const Border(
              bottom: BorderSide(color: Color(0x22FFFFFF), width: 0.8),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Icon ញញួរ
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: _accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),


                  // Title + Live Counter (ប្រើ Logic ចាស់ដែលបងចង់បាន)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'ផ្សារដេញថ្លៃ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Siemreap',
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('auction_products')
                              .where('status', isEqualTo: 'auction')
                              .snapshots(),
                          builder: (context, snapshot) {
                            int liveCount = 0;
                            if (snapshot.hasData) {
                              // Logic រាប់ដែលបងថាត្រឹមត្រូវ
                              liveCount = snapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final endTime = data['end_time'] as Timestamp?;
                                return endTime != null &&
                                    endTime.toDate().isAfter(DateTime.now());
                              }).length;
                            }
                            return Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseAnim,
                                  builder: (_, __) => Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.redAccent,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.redAccent.withOpacity(
                                            _pulseAnim.value,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'បន្តផ្ទាល់ $liveCount កម្មវិធី',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Siemreap',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ), // ប៊ូតុងគោលការណ៍
                  GestureDetector(
                    onTap: () => _showDetailedPolicy(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.rule_rounded, color: _textMuted, size: 15),
                          SizedBox(width: 4),
                          Text(
                            'គោលការណ៍',
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 10,
                              fontFamily: 'Siemreap',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),


                  // ប៊ូតុងចក្ខុវិស័យ (Icon មាស)
                  GestureDetector(
                    onTap: widget.onInfo,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E3440), Color(0xFF1A1F2B)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_mosaic_rounded,
                        color: _accentGold,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



