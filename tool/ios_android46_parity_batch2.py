from pathlib import Path
import re


def insert_before_once(path, anchor, addition, marker, label):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if marker in text:
        print(f'{label}: already applied')
        return
    if anchor not in text:
        raise SystemExit(f'{label}: anchor not found in {path}')
    text = text.replace(anchor, addition + anchor, 1)
    p.write_text(text, encoding='utf-8')
    print(f'{label}: applied')


def regex_replace_once(path, pattern, replacement, marker, label):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if marker in text:
        print(f'{label}: already applied')
        return
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'{label}: expected one match in {path}, got {count}')
    p.write_text(new_text, encoding='utf-8')
    print(f'{label}: applied')


# Product Detail: show how many users saved/bookmarked this product.
bookmark_widget = r'''                        // Android Build 46 parity: live bookmark/save count
                        if ((widget.product['id'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('bookmarks')
                                  .where(
                                    'productId',
                                    isEqualTo: widget.product['id'] ?? '',
                                  )
                                  .snapshots(),
                              builder: (context, bookmarkSnapshot) {
                                final saveCount =
                                    bookmarkSnapshot.data?.docs.length ?? 0;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bookmark_rounded,
                                      color: Colors.blue.shade700,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      Localizations.localeOf(context).languageCode == 'en'
                                          ? '$saveCount saves'
                                          : 'បានរក្សាទុក $saveCount ដង',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

'''
insert_before_once(
    'lib/product_detail.dart',
    '                        // ✅ Average រួម + Rating ផ្ទាល់របស់គណនីនេះ\n',
    bookmark_widget,
    'Android Build 46 parity: live bookmark/save count',
    'product bookmark count',
)

# Seller Profile: add local phone privacy state/helper.
p = Path('lib/seller_profile_screen.dart')
text = p.read_text(encoding='utf-8')
if 'bool _showSellerPhone = false;' not in text:
    anchor = '  bool _isLoadingFollow = false;\n'
    if anchor not in text:
        raise SystemExit('seller phone state anchor not found')
    text = text.replace(anchor, anchor + '  bool _showSellerPhone = false;\n', 1)

if 'String _maskSellerPhoneForDisplay(' not in text:
    anchor = '  Future<void> _loadUserId() async {\n'
    helper = '''  String _maskSellerPhoneForDisplay(String phone) {
    final clean = phone.trim().replaceAll(RegExp(r'\\s+'), '');
    if (clean.isEmpty) return '';
    if (clean.length <= 5) return 'XXX';
    return '${clean.substring(0, 3)}${'*' * (clean.length - 5)}${clean.substring(clean.length - 2)}';
  }

'''
    if anchor not in text:
        raise SystemExit('seller phone helper anchor not found')
    text = text.replace(anchor, helper + anchor, 1)

p.write_text(text, encoding='utf-8')

# Combine Chat + seller phone + Follow in one compact line like Android 46.
seller_compact = r'''              // Android Build 46 parity: compact chat, phone privacy and follow controls
              FutureBuilder<String>(
                future: _getSellerPhoneFromProducts(widget.sellerId),
                builder: (context, phoneSnapshot) {
                  final phone = phoneSnapshot.data ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    seller_id: widget.sellerId,
                                    receiver_id: widget.sellerId,
                                    productName: 'ហាងរបស់ ${widget.sellerName}',
                                    productId: 'general',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline, size: 15),
                            label: const Text(
                              'ឆាត',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, fontFamily: 'Siemreap'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 6,
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 7),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.phone, color: Colors.green[700], size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _showSellerPhone
                                          ? phone
                                          : _maskSellerPhoneForDisplay(phone),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.green[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(
                                      () => _showSellerPhone = !_showSellerPhone,
                                    ),
                                    icon: Icon(
                                      _showSellerPhone
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 15,
                                    ),
                                    tooltip: _showSellerPhone ? 'លាក់លេខ' : 'បង្ហាញលេខ',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_currentUserId != widget.sellerId) ...[
                          const SizedBox(width: 6),
                          _FollowButton(
                            sellerId: widget.sellerId,
                            currentUserId: _currentUserId,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

'''
regex_replace_once(
    'lib/seller_profile_screen.dart',
    r'\s*// បង្ហាញលេខទូរស័ព្ទ\n\s*FutureBuilder<String>\(.*?\n\s*// ទីតាំង\n',
    '\n' + seller_compact + '              // ទីតាំង\n',
    'Android Build 46 parity: compact chat, phone privacy and follow controls',
    'seller compact controls',
)

# Remove the now-duplicate lower Chat/Follow row.
regex_replace_once(
    'lib/seller_profile_screen.dart',
    r'\s*// ប៊ូតុងឆាត និងតាមដាន\n\s*Row\(.*?\n\s*// ប៊ូតុងដំឡើងហាង \(បើជាម្ចាស់\)\n',
    '\n              // ប៊ូតុងដំឡើងហាង (បើជាម្ចាស់)\n',
    '// Android46 compact controls duplicate removed',
    'remove duplicate seller chat row',
)

# Add marker after successful duplicate removal so reruns are idempotent.
p = Path('lib/seller_profile_screen.dart')
text = p.read_text(encoding='utf-8')
if '// Android46 compact controls duplicate removed' not in text:
    text = text.replace(
        '              // ប៊ូតុងដំឡើងហាង (បើជាម្ចាស់)\n',
        '              // Android46 compact controls duplicate removed\n              // ប៊ូតុងដំឡើងហាង (បើជាម្ចាស់)\n',
        1,
    )
p.write_text(text, encoding='utf-8')

print('iOS Android 46 parity batch 2 complete')
