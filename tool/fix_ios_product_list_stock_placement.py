from pathlib import Path

p = Path('lib/product_list.dart')
s = p.read_text(encoding='utf-8')

bad = '''                            ],
                          ),
                        ],
                      ),
                      if (widget.category == 'ទំនិញរបស់ខ្ញុំ' && postType == 'sale') ...[
                        const SizedBox(height: 6),
                        _buildInlineStockControl(docId, data),
                      ],
                    ),'''

good = '''                            ],
                          ),
                          if (widget.category == 'ទំនិញរបស់ខ្ញុំ' && postType == 'sale') ...[
                            const SizedBox(height: 6),
                            _buildInlineStockControl(docId, data),
                          ],
                        ],
                      ),
                    ),'''

if bad in s:
    s = s.replace(bad, good, 1)
elif good not in s:
    raise SystemExit('Expected stock-control placement block not found')

# Ensure stock control is inside Column children and only occurs once on the card.
if s.count('_buildInlineStockControl(docId, data)') != 1:
    raise SystemExit('Unexpected inline stock control call count')

p.write_text(s, encoding='utf-8')
