from pathlib import Path

p = Path('lib/product_list.dart')
s = p.read_text(encoding='utf-8')

# Imports.
if "import 'pre_order_detail_screen.dart';" not in s:
    s = s.replace("import 'product_detail.dart';", "import 'product_detail.dart';\nimport 'pre_order_detail_screen.dart';", 1)

# State for remembered Manage Posts tab.
if "String _selectedManageType = 'sale';" not in s:
    s = s.replace(
        "  String? _currentUserId;\n  String _selectedSubCategory = 'ទាំងអស់';",
        "  String? _currentUserId;\n  String _selectedManageType = 'sale';\n  static String _lastManageType = 'sale';\n  String _selectedSubCategory = 'ទាំងអស់';",
        1,
    )

# Restore selected tab.
if "prefs.getString('manage_posts_tab')" not in s:
    s = s.replace(
        "  Future<void> _initUserAndFetch() async {\n    _currentUserId = await UserService.getUserId();",
        "  Future<void> _initUserAndFetch() async {\n    _currentUserId = await UserService.getUserId();\n    if (widget.category == \"ទំនិញរបស់ខ្ញុំ\") {\n      final prefs = await SharedPreferences.getInstance();\n      final savedType = prefs.getString('manage_posts_tab');\n      _selectedManageType = savedType ?? _lastManageType;\n    }",
        1,
    )

# Fetch pre-orders in My Products.
if ".collection('pre_orders')" not in s:
    wanted_tail = """      FirebaseFirestore.instance
          .collection('wanted_products')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get(),
    ]);"""
    preorder_tail = """      FirebaseFirestore.instance
          .collection('wanted_products')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get(),
      FirebaseFirestore.instance
          .collection('pre_orders')
          .where('owner_id', isEqualTo: _currentUserId)
          .get(),
    ]);"""
    if wanted_tail not in s:
        raise SystemExit('Wanted fetch block not found')
    s = s.replace(wanted_tail, preorder_tail, 1)

if 'combined.addAll(futures[2].docs);' not in s:
    s = s.replace(
        '    combined.addAll(futures[1].docs);',
        '    combined.addAll(futures[1].docs);\n    combined.addAll(futures[2].docs);',
        1,
    )

s = s.replace(
    "final timeA = dataA['created_at'] ?? dataA['savedAt'] ?? Timestamp.now();",
    "final timeA = dataA['created_at'] ?? dataA['createdAt'] ?? dataA['savedAt'] ?? Timestamp.now();",
    1,
)
s = s.replace(
    "final timeB = dataB['created_at'] ?? dataB['savedAt'] ?? Timestamp.now();",
    "final timeB = dataB['created_at'] ?? dataB['createdAt'] ?? dataB['savedAt'] ?? Timestamp.now();",
    1,
)

# Filter My Products by selected type.
if 'final matchesManageType =' not in s:
    s = s.replace(
        "      final query = widget.searchQuery;\n\n\n      final subCategory",
        "      final query = widget.searchQuery;\n\n      final postType = _managePostType(doc);\n      final matchesManageType = widget.category != 'ទំនិញរបស់ខ្ញុំ' ||\n          postType == _selectedManageType;\n\n      final subCategory",
        1,
    )

smart_return = """      return _matchesSmartSearch(data, query) &&
          matchesSub &&
          matchesSubSub &&
          _matchesLocationFilter(data);"""
manage_return = """      return matchesManageType &&
          _matchesSmartSearch(data, query) &&
          matchesSub &&
          matchesSubSub &&
          _matchesLocationFilter(data);"""
if smart_return in s:
    s = s.replace(smart_return, manage_return, 1)

# Manage tabs in both empty and non-empty states.
if "widget.category == 'ទំនិញរបស់ខ្ញុំ') _buildManageTabs()" not in s:
    s = s.replace(
        "          if (!widget.isHome) _buildSubCategoryFilter(),\n          const Expanded(",
        "          if (!widget.isHome) _buildSubCategoryFilter(),\n          if (widget.category == 'ទំនិញរបស់ខ្ញុំ') _buildManageTabs(),\n          const Expanded(",
        1,
    )
    s = s.replace(
        "        if (!widget.isHome) _buildSubCategoryFilter(),\n        Expanded(",
        "        if (!widget.isHome) _buildSubCategoryFilter(),\n        if (widget.category == 'ទំនិញរបស់ខ្ញុំ') _buildManageTabs(),\n        Expanded(",
        1,
    )

# Helper + tabs.
if 'String _managePostType(DocumentSnapshot doc)' not in s:
    marker = '  Widget _buildSubCategoryFilter() {'
    helper = r'''  String _managePostType(DocumentSnapshot doc) {
    final path = doc.reference.path;
    if (path.contains('wanted_products')) return 'wanted';
    if (path.contains('pre_orders')) return 'preorder';
    return 'sale';
  }

  Widget _buildManageTabs() {
    final tabs = <({String value, String km, String en, Color color})>[
      (value: 'sale', km: 'ទំនិញលក់', en: 'For sale', color: Colors.green),
      (value: 'wanted', km: 'ប្រកាសទិញ', en: 'Wanted', color: Colors.blue),
      (value: 'preorder', km: 'លក់មុន', en: 'Pre-order', color: Colors.orange),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: tabs.map((tab) {
          final selected = _selectedManageType == tab.value;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  if (selected) return;
                  setState(() => _selectedManageType = tab.value);
                  _lastManageType = tab.value;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('manage_posts_tab', tab.value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? tab.color : tab.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: tab.color.withOpacity(selected ? 1 : 0.28),
                    ),
                  ),
                  child: Text(
                    appText(context, km: tab.km, en: tab.en),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Siemreap',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : tab.color,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

'''
    if marker not in s:
        raise SystemExit('Sub-category filter marker not found')
    s = s.replace(marker, helper + marker, 1)

# Card type detection.
legacy_type = """    final bool isWanted =
        doc.reference.path.contains('wanted_products') ||
            data.containsKey('savedAt');"""
new_type = """    final String postType = _managePostType(doc);
    final bool isWanted = postType == 'wanted';
    final bool isPreOrder = postType == 'preorder';"""
if legacy_type in s:
    s = s.replace(legacy_type, new_type, 1)

# Tap into the correct detail screen.
s = s.replace(
    'onTap: () => _onProductTap(docId, data, isWanted),',
    'onTap: () => _onProductTap(docId, data, isWanted, isPreOrder: isPreOrder),',
    1,
)

# Cart switch only belongs to normal sale posts.
s = s.replace(
    'if (widget.category == "ទំនិញរបស់ខ្ញុំ")\n                  Positioned(',
    'if (widget.category == "ទំនិញរបស់ខ្ញុំ" && postType == \'sale\')\n                  Positioned(',
    1,
)
# Edit only normal sale posts; pre-order has its own flow/detail.
s = s.replace('if (!isWanted) // បើទំនិញធម្មតា ទើបឱ្យកែ', 'if (!isWanted && !isPreOrder) // normal sale only', 1)
# Delete must know pre-order collection.
s = s.replace(
    'onTap: () => _showDeleteConfirm(docId, isWanted),',
    'onTap: () => _showDeleteConfirm(docId, isWanted, isPreOrder: isPreOrder),',
    1,
)

# Navigation helper.
old_nav = """  void _onProductTap(String docId, Map<String, dynamic> data, bool isWanted) {
    final productWithId = Map<String, dynamic>.from(data);
    productWithId['id'] = docId;
    productWithId['isWanted'] = isWanted;


    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isWanted
            ? WantedDetailScreen(data: productWithId)
            : ProductDetailScreen(product: productWithId),
      ),
    );
  }"""
new_nav = """  void _onProductTap(
    String docId,
    Map<String, dynamic> data,
    bool isWanted, {
    bool isPreOrder = false,
  }) {
    final productWithId = Map<String, dynamic>.from(data);
    productWithId['id'] = docId;
    productWithId['isWanted'] = isWanted;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isPreOrder
            ? PreOrderDetailScreen(documentId: docId, data: productWithId)
            : isWanted
                ? WantedDetailScreen(data: productWithId)
                : ProductDetailScreen(product: productWithId),
      ),
    );
  }"""
if old_nav in s:
    s = s.replace(old_nav, new_nav, 1)

# Delete correct collection.
s = s.replace(
    '  void _showDeleteConfirm(String docId, bool isWanted) {',
    '  void _showDeleteConfirm(String docId, bool isWanted, {bool isPreOrder = false}) {',
    1,
)
s = s.replace(
    ".collection(isWanted ? 'wanted_products' : 'products')\n                  .doc(docId)\n                  .delete();",
    ".collection(isPreOrder ? 'pre_orders' : isWanted ? 'wanted_products' : 'products')\n                  .doc(docId)\n                  .delete();",
    1,
)

required = [
    "import 'pre_order_detail_screen.dart';",
    "String _selectedManageType = 'sale';",
    "prefs.getString('manage_posts_tab')",
    ".collection('pre_orders')",
    "combined.addAll(futures[2].docs);",
    "String _managePostType(DocumentSnapshot doc)",
    "Widget _buildManageTabs()",
    "postType == _selectedManageType",
    "final bool isPreOrder = postType == 'preorder';",
    "PreOrderDetailScreen(documentId: docId, data: productWithId)",
    "isPreOrder ? 'pre_orders'",
]
for token in required:
    if token not in s:
        raise SystemExit(f'Missing expected parity token: {token}')

p.write_text(s, encoding='utf-8')
