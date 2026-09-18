import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_app/wanted_related_products_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'chat_screen.dart';
import 'edit_wanted_screen.dart';
import 'user_profile_screen.dart';
import 'media_viewer.dart';

class WantedDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const WantedDetailScreen({super.key, required this.data});

  @override
  State<WantedDetailScreen> createState() => _WantedDetailScreenState();
}

class _WantedDetailScreenState extends State<WantedDetailScreen> {
  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;
  String? _currentUid;
  int _currentImageIndex = 0;
  // ✅ ពិនិត្យថាជាម្ចាស់ប្រកាសដែរឬទេ
  bool get _isOwner =>
      _currentUid != null && _currentUid == widget.data['userId'];

  // សម្រាប់ "ខ្ញុំមានលក់"
  List<Map<String, dynamic>> _sellers = [];
  bool _hasClickedSell = false;

  // ✅ ព័ត៌មានអ្នកប្រកាស
  String _posterName = '';
  String _posterPhotoUrl = '';
  String _posterSesanId = '';
  bool _isPosterLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadSellers();
    _loadPosterInfo(); // ✅ បន្ថែម
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUid = prefs.getString('user_uid');
    if (mounted) setState(() {});
  }

  // ✅ ទាញយកព័ត៌មានអ្នកប្រកាស
  Future<void> _loadPosterInfo() async {
    final String? userId = widget.data['userId'];
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() {
          _posterName = _t('មិនស្គាល់អ្នកប្រកាស', 'Unknown poster');
          _isPosterLoading = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && mounted) {
        final userData = doc.data() as Map<String, dynamic>;
        setState(() {
          _posterName =
              userData['name'] ??
              userData['displayName'] ??
              _t('គ្មានឈ្មោះ', 'Unnamed user');
          _posterPhotoUrl = userData['photoUrl'] ?? userData['photo'] ?? '';
          _posterSesanId = userData['sesan_id'] ?? '';
          _isPosterLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _posterName = _t('មិនអាចរកឃើញអ្នកប្រកាស', 'Poster not found');
            _isPosterLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _posterName = _t('មានបញ្ហាក្នុងការផ្ទុក', 'Could not load poster');
          _isPosterLoading = false;
        });
      }
    }
  }

  Future<void> _loadSellers() async {
    try {
      final productId = widget.data['id'] ?? '';
      if (productId.isEmpty) return;

      final sellersSnapshot = await FirebaseFirestore.instance
          .collection('wanted_products')
          .doc(productId)
          .collection('sellers')
          .orderBy('createdAt', descending: true)
          .get();

      final sellers = sellersSnapshot.docs.map((doc) {
        return {
          'uid': doc.data()['uid'],
          'userName': doc.data()['userName'] ?? 'អ្នកលក់',
          'photoUrl': doc.data()['photoUrl'] ?? '',
          'price': doc.data()['price'],
          'currency': doc.data()['currency'] ?? '៛',
          'isNegotiable': doc.data()['isNegotiable'] ?? false,
        };
      }).toList();

      final hasClicked = sellers.any((s) => s['uid'] == _currentUid);

      if (mounted) {
        setState(() {
          _sellers = sellers;
          _hasClickedSell = hasClicked;
        });
      }
    } catch (e) {
      debugPrint("Error loading sellers: $e");
    }
  }

  Future<void> _clickToSell() async {
    if (_currentUid == null || _hasClickedSell) return;

    final result = await _showSellDialog();
    if (result == null) return;

    final price = result['price'] as String;
    final currency = result['currency'] as String;
    final isNegotiable = result['isNegotiable'] as bool;
    final productId = widget.data['id'] ?? '';
    if (productId.isEmpty) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid)
        .get();
    final userName = userDoc.data()?['name'] ?? 'អ្នកលក់';
    final photoUrl = userDoc.data()?['photoUrl'] ?? '';

    await FirebaseFirestore.instance
        .collection('wanted_products')
        .doc(productId)
        .collection('sellers')
        .doc(_currentUid)
        .set({
          'uid': _currentUid,
          'userName': userName,
          'photoUrl': photoUrl,
          'price': price,
          'currency': currency,
          'isNegotiable': isNegotiable,
          'createdAt': FieldValue.serverTimestamp(),
        });

    _loadSellers();
  }

  Future<Map<String, dynamic>?> _showSellDialog() {
    final priceController = TextEditingController();
    String currency = '៛';
    bool isNegotiable = false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            _t('ខ្ញុំមានលក់', 'I have this to sell'),
            style: TextStyle(fontFamily: 'Siemreap'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('តម្លៃ', 'Price'),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(_t('រូបិយប័ណ្ណ: ', 'Currency: ')),
                  DropdownButton<String>(
                    value: currency,
                    items: const [
                      DropdownMenuItem(value: '៛', child: Text('៛ រៀល')),
                      DropdownMenuItem(value: '\$', child: Text('\$ ដុល្លារ')),
                    ],
                    onChanged: (v) => setDialogState(() => currency = v!),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: isNegotiable,
                    onChanged: (v) => setDialogState(() => isNegotiable = v!),
                  ),
                  Text(_t('អាចចរចារបាន', 'Negotiable')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t('បោះបង់', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, {
                  'price': priceController.text,
                  'currency': currency,
                  'isNegotiable': isNegotiable,
                });
              },
              child: Text(_t('បញ្ជាក់', 'Confirm')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final List<dynamic> images = d['imageUrls'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t('លម្អិតការប្រកាសទិញ', 'Wanted listing details'),
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              String firstImg = images.isNotEmpty ? images[0] : "";
              Clipboard.setData(ClipboardData(text: firstImg));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _t('ចម្លង Link រូបភាពរួចរាល់!', 'Image link copied!'),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              String firstImg = images.isNotEmpty ? images[0] : "";
              Share.share(
                _t(
                  "ត្រូវការទិញ: ${d['productName']}\nតម្លៃ: ${d['price']} ${d['currency']}\nមើលរូបភាព: $firstImg",
                  "Wanted: ${d['productName']}\nPrice: ${d['price']} ${d['currency']}\nView image: $firstImg",
                ),
              );
            },
          ),
          // ✅ ប៊ូតុងកែប្រែ (សម្រាប់តែម្ចាស់)
          // ✅ ប៊ូតុងកែប្រែ (សម្រាប់តែម្ចាស់)
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditWantedScreen(
                      // ✅ ប្រើ EditWantedScreen
                      productId: d['id'] ?? '',
                      productData: d,
                    ),
                  ),
                );
              },
            ),

          // ✅ ប៊ូតុងលុប (សម្រាប់តែម្ចាស់)
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () => _confirmDelete(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🎯 រូបភាពស្លាយ + លេខរាប់
            _buildImageGallery(images),

            // ✅ ប្រអប់ព័ត៌មានអ្នកប្រកាស
            _buildPosterCard(),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d['productName'] ?? '',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ✅ បង្ហាញកាលបរិច្ឆេទប្រកាស
                  if (d['createdAt'] != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _t(
                            'ប្រកាសនៅ: ${_formatDate(d['createdAt'])}',
                            'Posted: ${_formatDate(d['createdAt'])}',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // ✅ ពិនិត្យថាតើតម្លៃជា "ចរចារ" ឬអត់
                  Text(
                    d['price'] == 'ចរចារ' ||
                            d['price'] == 'negotiable' ||
                            d['price'].toString().toLowerCase() == 'ចរចារ'
                        ? _t('ចរចារ', 'Negotiable')
                        : "${d['price']} ${d['currency']}",
                    style: TextStyle(
                      fontSize: 24,
                      color: d['price'] == 'ចរចារ' || d['price'] == 'negotiable'
                          ? Colors.orange
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 30),
                  _infoTile(
                    Icons.shopping_bag,
                    _t('ចំនួនត្រូវការ', 'Quantity wanted'),
                    "${d['quantity']} ${d['unit']}",
                  ),
                  _infoTile(
                    Icons.location_on,
                    _t('ទីតាំង', 'Location'),
                    d['location'] ?? _t('មិនបញ្ជាក់', 'Not specified'),
                  ),
                  _infoTile(
                    Icons.phone,
                    _t('លេខទូរស័ព្ទ', 'Phone number'),
                    d['phone'] ?? _t('មិនមាន', 'Not available'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _t('ការរៀបរាប់បន្ថែម:', 'Additional description:'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    d['description'] ??
                        _t('មិនមានការរៀបរាប់...', 'No description...'),
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 30),
                  _buildSellersSection(),
                  const SizedBox(height: 30),
                  WantedRelatedProductsWidget(
                    category: d['category'] ?? '',
                    currentProductId: d['id'] ?? '',
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
        ),
        child: Row(
          children: [
            _bottomActionIcon(Icons.chat, Colors.orange, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    productId: d['id'] ?? '',
                    productName: d['productName'] ?? '',
                    seller_id: d['userId'] ?? '',
                    receiver_id: d['userId'] ?? '',
                  ),
                ),
              );
            }),
            const SizedBox(width: 15),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final url = Uri.parse("tel:${d['phone']}");
                  if (await canLaunchUrl(url)) await launchUrl(url);
                },
                icon: const Icon(Icons.phone),
                label: Text(
                  _t('តេទៅភ្លាម', 'Call now'),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                ),
              ),
            ),

            // ✅ ប៊ូតុងលុប (សម្រាប់តែម្ចាស់)
            if (_isOwner) ...[
              const SizedBox(width: 12),
              _bottomActionIcon(
                Icons.delete_outline,
                Colors.red,
                () => _confirmDelete(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ✅ Widget បង្ហាញព័ត៌មានអ្នកប្រកាស
  Widget _buildPosterCard() {
    if (_isPosterLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: () {
        final String? userId = widget.data['userId'];
        if (userId != null && userId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(userId: userId),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.blue.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: _posterPhotoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(_posterPhotoUrl)
                  : null,
              child: _posterPhotoUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.blue, size: 30)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _posterName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (_posterSesanId.isNotEmpty)
                    Text(
                      'ID: $_posterSesanId',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'Siemreap',
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ✅ ផ្នែក "ខ្ញុំមានលក់"
  Widget _buildSellersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(
                _t('អ្នកមានលក់', 'Sellers with this product'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Siemreap',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _t('${_sellers.length} នាក់', '${_sellers.length} sellers'),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_hasClickedSell)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clickToSell,
                icon: const Icon(Icons.add_business, color: Colors.green),
                label: Text(
                  _t('ខ្ញុំមានលក់', 'I have this to sell'),
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Siemreap',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _t(
                      'អ្នកបានបញ្ជាក់ថាមានលក់',
                      'You confirmed that you have this to sell',
                    ),
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ),
          if (_sellers.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ...List.generate(_sellers.length, (index) {
              final seller = _sellers[index];
              return _buildSellerItem(seller);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSellerItem(Map<String, dynamic> seller) {
    final price = seller['price']?.toString() ?? '0';
    final currency = seller['currency'] ?? '៛';
    final isNegotiable = seller['isNegotiable'] ?? false;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: seller['uid']),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage:
                  seller['photoUrl'] != null &&
                      seller['photoUrl'].toString().isNotEmpty
                  ? CachedNetworkImageProvider(seller['photoUrl'])
                  : null,
              child:
                  seller['photoUrl'] == null ||
                      seller['photoUrl'].toString().isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seller['userName'] ?? _t('អ្នកលក់', 'Seller'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$price $currency',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isNegotiable) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _t('អាចចរចារ', 'Negotiable'),
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery(List<dynamic> images) {
    return Stack(
      children: [
        SizedBox(
          height: 300,
          width: double.infinity,
          child: images.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaViewer(
                          url: images[_currentImageIndex],
                          type: 'image',
                        ),
                      ),
                    );
                  },
                  child: PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) =>
                        setState(() => _currentImageIndex = i),
                    itemBuilder: (_, i) => CachedNetworkImage(
                      imageUrl: images[i],
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: Colors.grey[300]),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                )
              : Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, size: 50),
                ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${_currentImageIndex + 1}/${images.length}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _bottomActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return _t('មិនកំណត់', 'Not set');
    if (date is Timestamp) {
      final d = date.toDate();
      return DateFormat('dd/MM/yyyy').format(d);
    }
    return date.toString();
  }

  // ✅ មុខងារលុបការប្រកាស
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _t('លុបការប្រកាស?', 'Delete listing?'),
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        content: Text(
          _t(
            'តើអ្នកពិតជាចង់លុបការប្រកាសនេះមែនទេ?',
            'Are you sure you want to delete this listing?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('ទេ', 'No')),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('wanted_products')
                  .doc(widget.data['id'])
                  .delete();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(
              _t('លុប', 'Delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
