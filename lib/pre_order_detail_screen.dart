import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_app/pre_order_related_products_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';
import 'media_viewer.dart';

class PreOrderDetailScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> data;

  const PreOrderDetailScreen({super.key, required this.documentId, required this.data});

  @override
  State<PreOrderDetailScreen> createState() => _PreOrderDetailScreenState();
}

class _PreOrderDetailScreenState extends State<PreOrderDetailScreen> {
  String _t(String km, String en) => Localizations.localeOf(context).languageCode == 'en' ? en : km;
  String? currentUid;
  final formatter = NumberFormat('#,###');
  int _currentImageIndex = 0;
  bool _isDescriptionExpanded = false;
  final ValueNotifier<bool> _showPhoneNotifier = ValueNotifier<bool>(false);
  Timer? _phoneHideTimer;
  String _posterName = '';
  String _posterPhotoUrl = '';
  String _posterSesanId = '';
  bool _isPosterLoading = true;

  @override
  void initState() { super.initState(); _loadUser(); _loadPosterInfo(); }

  @override
  void dispose() { _phoneHideTimer?.cancel(); _showPhoneNotifier.dispose(); super.dispose(); }

  String _maskedPhone(dynamic value) {
    final phone = (value ?? '').toString().trim().replaceAll(RegExp(r'\s+'), '');
    if (phone.isEmpty) return '';
    final prefixLength = phone.startsWith('+') ? (phone.length < 4 ? phone.length : 4) : (phone.length < 3 ? phone.length : 3);
    if (phone.length <= prefixLength) return phone;
    return '${phone.substring(0, prefixLength)}${List.filled(phone.length - prefixLength, 'X').join()}';
  }

  void _revealPhoneTemporarily() {
    _phoneHideTimer?.cancel(); _showPhoneNotifier.value = true;
    _phoneHideTimer = Timer(const Duration(seconds: 5), () { if (mounted) _showPhoneNotifier.value = false; });
  }
  void _hidePhone() { _phoneHideTimer?.cancel(); _showPhoneNotifier.value = false; }

  Future<void> _loadUser() async { final prefs = await SharedPreferences.getInstance(); currentUid = prefs.getString('user_uid'); if (mounted) setState(() {}); }

  Future<void> _loadPosterInfo() async {
    final String? userId = widget.data['owner_id'];
    if (userId == null || userId.isEmpty) { if (mounted) setState(() { _posterName = _t('មិនស្គាល់អ្នកប្រកាស', 'Unknown poster'); _isPosterLoading = false; }); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists && mounted) {
        final userData = doc.data() as Map<String, dynamic>;
        setState(() { _posterName = userData['name'] ?? userData['displayName'] ?? _t('គ្មានឈ្មោះ', 'Unnamed user'); _posterPhotoUrl = userData['photoUrl'] ?? userData['photo'] ?? ''; _posterSesanId = userData['sesan_id'] ?? ''; _isPosterLoading = false; });
      } else if (mounted) { setState(() { _posterName = _t('មិនអាចរកឃើញអ្នកប្រកាស', 'Poster not found'); _isPosterLoading = false; }); }
    } catch (_) { if (mounted) setState(() { _posterName = _t('មានបញ្ហាក្នុងការផ្ទុក', 'Could not load poster'); _isPosterLoading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = widget.data['owner_id'] ?? '';
    final isOwner = currentUid == ownerId;
    List<dynamic> images = widget.data['images'] ?? widget.data['image_urls'] ?? [];
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: Text(_t('ព័ត៌មានលម្អិត', 'Pre-order details'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 18)), centerTitle: true, backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0.5, actions: [
        IconButton(icon: const Icon(Icons.copy), onPressed: () { final firstImg = images.isNotEmpty ? images[0].toString() : ''; Clipboard.setData(ClipboardData(text: firstImg)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('បានចម្លង Link រូបភាព', 'Image link copied')))); }),
        IconButton(icon: const Icon(Icons.share), onPressed: () { final firstImg = images.isNotEmpty ? images[0].toString() : ''; Share.share(_t('ត្រូវការទិញ: ${widget.data['product_name'] ?? ''}\nតម្លៃ: ${widget.data['price'] ?? '0'} ៛\nមើលរូបភាព: $firstImg', 'Pre-order: ${widget.data['product_name'] ?? ''}\nPrice: ${widget.data['price'] ?? '0'} KHR\nView image: $firstImg')); }),
      ]),
      body: SingleChildScrollView(child: Column(children: [_buildImageGallery(images), Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildTitlePriceSection(), const SizedBox(height: 25), Text(_t('ម្ចាស់ការប្រកាស', 'Posted by'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Siemreap')), const SizedBox(height: 12), _buildPosterCard(), const SizedBox(height: 25), _buildProductDetails(), const SizedBox(height: 120)]))])),
      bottomNavigationBar: _buildBottomBar(isOwner),
    );
  }

  Widget _buildPosterCard() {
    if (_isPosterLoading) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    return GestureDetector(onTap: () { final userId = widget.data['owner_id']; if (userId != null && userId.toString().isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId))); }, child: Container(margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange.withOpacity(0.2))), child: Row(children: [CircleAvatar(radius: 25, backgroundColor: Colors.orange.shade100, backgroundImage: _posterPhotoUrl.isNotEmpty ? CachedNetworkImageProvider(_posterPhotoUrl) : null, child: _posterPhotoUrl.isEmpty ? const Icon(Icons.person, color: Colors.orange, size: 30) : null), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_posterName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), if (_posterSesanId.isNotEmpty) Text('ID: $_posterSesanId', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'Siemreap'))])), const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)])));
  }

  Widget _buildBottomBar(bool isOwner) => Container(padding: const EdgeInsets.fromLTRB(20, 15, 20, 35), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]), child: Row(children: [_buildActionButton(icon: Icons.phone_forwarded, color: Colors.green, onTap: () async { final phone = widget.data['phone'] ?? ''; if (phone.toString().isNotEmpty) await launchUrl(Uri.parse('tel:$phone')); }), const SizedBox(width: 12), Expanded(child: ElevatedButton.icon(onPressed: _goToChat, icon: const Icon(Icons.chat_bubble_outline, color: Colors.white), label: Text(_t('ផ្ញើសារឥឡូវនេះ', 'Message now'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Siemreap')), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0))), if (isOwner) ...[const SizedBox(width: 12), _buildActionButton(icon: Icons.delete_outline, color: Colors.red, onTap: _confirmDelete)]]));

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onTap}) => InkWell(onTap: onTap, child: Container(height: 55, width: 55, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color, size: 26)));

  Widget _buildImageGallery(List<dynamic> images) => Stack(children: [SizedBox(height: 320, width: double.infinity, child: images.isNotEmpty ? GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaViewer(url: images[_currentImageIndex], type: 'image'))), child: PageView.builder(itemCount: images.length, onPageChanged: (i) => setState(() => _currentImageIndex = i), itemBuilder: (_, i) => CachedNetworkImage(imageUrl: images[i], fit: BoxFit.cover, placeholder: (_, __) => Container(color: Colors.grey[300]), errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 50)))) : Container(color: Colors.grey[200], child: const Icon(Icons.image, size: 80))), if (images.length > 1) Positioned(bottom: 15, right: 15, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text('${_currentImageIndex + 1}/${images.length}', style: const TextStyle(color: Colors.white, fontSize: 12))))]);

  void _goToChat() {
    if (currentUid == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('សូមចូលប្រើប្រាស់កម្មវិធីជាមុនសិន', 'Please log in first')))); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(productId: widget.documentId, productName: widget.data['product_name'] ?? _t('ផលិតផល', 'Product'), seller_id: widget.data['owner_id'], receiver_id: widget.data['owner_id'])));
  }

  void _confirmDelete() { showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(_t('លុបការប្រកាស?', 'Delete listing?'), style: const TextStyle(fontFamily: 'Siemreap')), content: Text(_t('តើអ្នកពិតជាចង់លុបការប្រកាសនេះមែនទេ?', 'Are you sure you want to delete this listing?')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('ទេ', 'No'))), TextButton(onPressed: () async { await FirebaseFirestore.instance.collection('pre_orders').doc(widget.documentId).delete(); if (ctx.mounted) Navigator.pop(ctx); if (mounted) Navigator.pop(context); }, child: Text(_t('លុប', 'Delete'), style: const TextStyle(color: Colors.red))) ])); }

  Widget _buildTitlePriceSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(widget.data['product_name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))), Text('${formatter.format(widget.data['price'] ?? 0)} ៛', style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold))]), const SizedBox(height: 6), if (widget.data['created_at'] != null) Row(children: [const Icon(Icons.access_time, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(_t('ប្រកាសនៅ: ${_formatDate(widget.data['created_at'])}', 'Posted: ${_formatDate(widget.data['created_at'])}'), style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Siemreap'))])]);

  Widget _buildProductDetails() => Column(children: [_row(Icons.event_available, _t('ថ្ងៃប្រមូលផល', 'Harvest date'), _formatDate(widget.data['harvest_date'])), const Divider(), _buildPhoneRow(), const Divider(), _row(Icons.location_on_outlined, _t('ទីតាំង', 'Location'), widget.data['location'] ?? _t('មិនមានទីតាំង', 'No location')), const Divider(), _buildDescriptionRow(), const SizedBox(height: 30), PreOrderRelatedProductsWidget(category: widget.data['category'] ?? '', currentProductId: widget.data['id'] ?? ''), const SizedBox(height: 100)]);

  Widget _buildPhoneRow() {
    final fullPhone = (widget.data['phone'] ?? '').toString().trim().replaceAll(RegExp(r'\s+'), '');
    return ValueListenableBuilder<bool>(valueListenable: _showPhoneNotifier, builder: (context, showFullPhone, _) {
      final displayedPhone = fullPhone.isEmpty ? _t('មិនមានលេខទូរស័ព្ទ', 'No phone number') : (showFullPhone ? fullPhone : _maskedPhone(fullPhone));
      return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.phone_android, color: Colors.green, size: 22), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_t('លេខទូរស័ព្ទ', 'Phone number'), style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Siemreap')), Text(displayedPhone, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))])), if (fullPhone.isNotEmpty) IconButton(onPressed: showFullPhone ? _hidePhone : _revealPhoneTemporarily, icon: Icon(showFullPhone ? Icons.visibility_off : Icons.visibility, color: Colors.green.shade700, size: 20), tooltip: showFullPhone ? _t('លាក់លេខ', 'Hide number') : _t('បង្ហាញលេខ 5 វិនាទី', 'Show number for 5 seconds'), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), visualDensity: VisualDensity.compact)]));
    });
  }

  Widget _buildDescriptionRow() {
    final description = (widget.data['description'] ?? '').toString().trim();
    final displayText = description.isEmpty ? _t('មិនមានការពិពណ៌នា', 'No description') : description;
    final shouldShowToggle = description.length > 180 || '\n'.allMatches(description).length >= 5;
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.description_outlined, color: Colors.green, size: 22), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isEnglish ? 'Description' : 'ពិពណ៌នា', style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Siemreap')), const SizedBox(height: 3), AnimatedSize(duration: const Duration(milliseconds: 220), alignment: Alignment.topCenter, child: Text(displayText, maxLines: _isDescriptionExpanded ? null : 5, overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, height: 1.45, fontFamily: 'Siemreap'))), if (shouldShowToggle) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded), icon: Icon(_isDescriptionExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18), label: Text(_isDescriptionExpanded ? (isEnglish ? 'See less' : 'បង្រួម') : (isEnglish ? 'See more' : 'មើលបន្ថែម'), style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold)), style: TextButton.styleFrom(foregroundColor: Colors.green.shade700, padding: const EdgeInsets.only(top: 4), minimumSize: const Size(0, 34), tapTargetSize: MaterialTapTargetSize.shrinkWrap))) ]))]));
  }

  Widget _row(IconData icon, String title, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Colors.green, size: 22), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(value, style: const TextStyle(fontWeight: FontWeight.w500))]))]));

  String _formatDate(dynamic date) { if (date == null) return _t('មិនទាន់កំណត់', 'Not set'); if (date is Timestamp) return DateFormat('dd-MM-yyyy').format(date.toDate()); return date.toString(); }
}
