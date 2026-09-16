from pathlib import Path

p = Path('lib/product_list.dart')
s = p.read_text(encoding='utf-8')

# Required V51 imports.
if "import 'pre_order_detail_screen.dart';" not in s:
    s = s.replace("import 'product_detail.dart';", "import 'product_detail.dart';\nimport 'pre_order_detail_screen.dart';")

# Manage-post state.
needle = "  String? _currentUserId;\n  String _selectedSubCategory = 'ទាំងអស់';"
replacement = "  String? _currentUserId;\n  String _selectedManageType = 'sale';\n  static String _lastManageType = 'sale';\n  String _selectedSubCategory = 'ទាំងអស់';"
if needle in s:
    s = s.replace(needle, replacement, 1)

# Restore selected tab when entering My Products.
old_init = """  Future<void> _initUserAndFetch() async {
    _currentUserId = await UserService.getUserId();


    // ✅ Clear តែពេលចូលមកដំបូង"""
new_init = """  Future<void> _initUserAndFetch() async {
    _currentUserId = await UserService.getUserId();
    if (widget.category == "ទំនិញរបស់ខ្ញុំ") {
      final prefs = await SharedPreferences.getInstance();
      final savedType = prefs.getString('manage_posts_tab');
      _selectedManageType = savedType ?? _lastManageType;
    }


    // ✅ Clear តែពេលចូលមកដំបូង"""
if old_init in s:
    s = s.replace(old_init, new_init, 1)

# Include pre-orders owned by current user.
old_future_tail = """      FirebaseFirestore.instance
          .collection('wanted_products')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get(),
    ]);"""
new_future_tail = """      FirebaseFirestore.instance
          .collection('wanted_products')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get(),
      FirebaseFirestore.instance
          .collection('pre_orders')
          .where('owner_id', isEqualTo: _currentUserId)
          .get(),
    ]);"""
if old_future_tail in s:
    s = s.replace(old_future_tail, new_future_tail, 1)

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

# Filter by selected Manage Posts type.
filter_anchor = """      final query = widget.searchQuery;


      final subCategory"""
filter_insert = """      final query = widget.searchQuery;

      final postType = _managePostType(doc);
      final matchesManageType = widget.category != 'ទំនិញរបស់ខ្ញុំ' ||
          postType == _selectedManageType;

      final subCategory"""
if filter_anchor in s:
    s = s.replace(filter_anchor, filter_insert, 1)

# Handle both already-fixed and legacy filter return forms.
fixed_return = """      return _matchesSmartSearch(data, query) &&
          matchesSub &&
          matchesSubSub &&
          _matchesLocationFilter(data);"""
manage_return = """      return matchesManageType &&
          _matchesSmartSearch(data, query) &&
          matchesSub &&
          matchesSubSub &&
          _matchesLocationFilter(data);"""
if fixed_return in s:
    s = s.replace(fixed_return, manage_return, 1)
legacy_return = """      return (query.isEmpty || name.contains(query)) &&
          matchesSub &&
          matchesSubSub;"""
if legacy_return in s:
    s = s.replace(legacy_return, manage_return, 1)

# Show Manage Posts tabs above empty state and grid.
empty_anchor = """          if (!widget.isHome) _buildSubCategoryFilter(),
          const Expanded("""
empty_repl = """          if (!widget.isHome) _buildSubCategoryFilter(),
          if (widget.category == 'ទំនិញរបស់ខ្ញុំ') _buildManageTabs(),
          const Expanded("""
if empty_anchor in s:
    s = s.replace(empty_anchor, empty_repl, 1)

main_anchor = """        if (!widget.isHome) _buildSubCategoryFilter(),
        Expanded("""
main_repl = """        if (!widget.isHome) _buildSubCategoryFilter(),
        if (widget.category == 'ទំនិញរបស់ខ្ញុំ') _buildManageTabs(),
        Expanded("""
if main_anchor in s:
    s = s.replace(main_anchor, main_repl, 1)

# Helpers before sub-category filter.
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
        raise SystemExit('Sub-category marker not found')
    s = s.replace(marker, helper + marker, 1)

# Product card: derive post type rather than only wanted/non-wanted.
old_card = """    final bool isWanted = doc.reference.path.contains('wanted_products');"""
new_card = """    final String postType = _managePostType(doc);
    final bool isWanted = postType == 'wanted';
    final bool isPreOrder = postType == 'preorder';"""
if old_card in s:
    s = s.replace(old_card, new_card, 1)

# Product tap: support Pre-order details.
s = s.replace(
    'onTap: () => _onProductTap(docId, data, isWanted),',
    'onTap: () => _onProductTap(docId, data, isWanted, isPreOrder: isPreOrder),',
)

# Replace navigation helper if it is still the old signature.
old_sig = """  void _onProductTap(
    String docId,
    Map<String, dynamic> data,
    bool isWanted,
  ) {"""
new_sig = """  void _onProductTap(
    String docId,
    Map<String, dynamic> data,
    bool isWanted, {
    bool isPreOrder = false,
  }) {"""
if old_sig in s:
    s = s.replace(old_sig, new_sig, 1)

old_builder = """        builder: (context) => isWanted
            ? WantedDetailScreen(data: productWithId)
            : ProductDetailScreen(product: productWithId),"""
new_builder = """        builder: (context) => isPreOrder
            ? PreOrderDetailScreen(documentId: docId, data: productWithId)
            : isWanted
                ? WantedDetailScreen(data: productWithId)
                : ProductDetailScreen(product: productWithId),"""
if old_builder in s:
    s = s.replace(old_builder, new_builder, 1)

# Verify essential parity pieces before writing.
required = [
    "import 'pre_order_detail_screen.dart';",
    "String _selectedManageType = 'sale';",
    "collection('pre_orders')",
    "combined.addAll(futures[2].docs);",
    "String _managePostType(DocumentSnapshot doc)",
    "Widget _buildManageTabs()",
    "postType == _selectedManageType",
    "PreOrderDetailScreen(documentId: docId, data: productWithId)",
]
for token in required:
    if token not in s:
        raise SystemExit(f'Missing expected parity token: {token}')

p.write_text(s, encoding='utf-8')
