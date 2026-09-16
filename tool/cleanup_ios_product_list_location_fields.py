from pathlib import Path

p = Path('lib/product_list.dart')
s = p.read_text(encoding='utf-8')

field_block = """  final String? filterProvince;
  final String? filterDistrict;
  final String? filterCommune;"""
arg_block = """    this.filterProvince,
    this.filterDistrict,
    this.filterCommune,"""

# Normalize any repeated copies to exactly one block.
while field_block + '\n' + field_block in s:
    s = s.replace(field_block + '\n' + field_block, field_block, 1)
while arg_block + '\n' + arg_block in s:
    s = s.replace(arg_block + '\n' + arg_block, arg_block, 1)

# ProductGridView must expose exactly one set of fields and constructor args.
widget_start = s.index('class ProductGridView extends StatefulWidget')
state_start = s.index('class _ProductGridViewState', widget_start)
widget_text = s[widget_start:state_start]
for token in ['filterProvince', 'filterDistrict', 'filterCommune']:
    expected = 2  # field declaration + constructor parameter
    actual = widget_text.count(token)
    if actual != expected:
        raise SystemExit(f'{token} count is {actual}, expected {expected}')

p.write_text(s, encoding='utf-8')
