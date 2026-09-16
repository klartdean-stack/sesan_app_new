from pathlib import Path

p = Path('lib/product_list.dart')
s = p.read_text(encoding='utf-8')

old = """      return (query.isEmpty || name.contains(query)) &&
          matchesSub &&
          matchesSubSub;"""
new = """      return _matchesSmartSearch(data, query) &&
          matchesSub &&
          matchesSubSub &&
          _matchesLocationFilter(data);"""

if old in s:
    s = s.replace(old, new, 1)
elif new not in s:
    raise SystemExit('Expected Product List filter block was not found')

if 'name.contains(query)' in s:
    raise SystemExit('Legacy name.contains(query) filter still remains')

p.write_text(s, encoding='utf-8')
