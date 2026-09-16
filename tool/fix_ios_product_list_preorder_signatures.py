from pathlib import Path

p = Path('lib/product_list.dart')
s = p.read_text(encoding='utf-8')

old_owner = '''  Widget _buildOwnerTools(
      String docId,
      Map<String, dynamic> data,
      bool isWanted,
      ) {'''
new_owner = '''  Widget _buildOwnerTools(
      String docId,
      Map<String, dynamic> data,
      bool isWanted, {
      bool isPreOrder = false,
      }) {'''
if old_owner in s:
    s = s.replace(old_owner, new_owner, 1)

old_tap = '''  void _onProductTap(String docId, Map<String, dynamic> data, bool isWanted) {'''
new_tap = '''  void _onProductTap(
    String docId,
    Map<String, dynamic> data,
    bool isWanted, {
    bool isPreOrder = false,
  }) {'''
if old_tap in s:
    s = s.replace(old_tap, new_tap, 1)

for token in [
    'bool isWanted, {\n      bool isPreOrder = false,\n      }) {',
    'bool isWanted, {\n    bool isPreOrder = false,\n  }) {',
    'PreOrderDetailScreen(documentId: docId, data: productWithId)',
]:
    if token not in s:
        raise SystemExit(f'Missing expected token: {token}')

p.write_text(s, encoding='utf-8')
