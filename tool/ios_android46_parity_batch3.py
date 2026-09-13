from pathlib import Path

p = Path('lib/chat_screen_legacy.dart')
text = p.read_text(encoding='utf-8')


def swap(old, new, label):
    global text
    if new in text:
        print(f'{label}: already applied')
        return
    if old not in text:
        raise SystemExit(f'{label}: anchor not found')
    text = text.replace(old, new, 1)
    print(f'{label}: applied')


swap(
    '                  margin: const EdgeInsets.all(8),',
    '                  margin: const EdgeInsets.fromLTRB(6, 2, 6, 4),',
    'chat cart outer margin',
)
swap(
    '                        padding: const EdgeInsets.all(12),',
    '                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),',
    'chat cart header padding',
)
swap(
    '''                              size: 20,\n                            ),\n                            const SizedBox(width: 8),\n                            Text(\n                              appText(context, km: 'ទំនិញដែលចង់ទិញ (${items.length})', en: 'Cart items (${items.length})'),\n                              style: TextStyle(\n                                fontWeight: FontWeight.bold,\n                                color: Colors.orange[700],\n                                fontSize: 14,\n                              ),\n                            ),\n                            const Spacer(),\n                            TextButton(\n                              onPressed: () async {\n                                for (var item in items) {\n                                  await item.reference.delete();\n                                }\n                              },\n                              child: Text(\n                                appText(context, km: 'លុបទាំងអស់', en: 'Clear all'),\n                                style: TextStyle(fontSize: 12, color: Colors.red),\n                              ),\n                            ),''',
    '''                              size: 16,\n                            ),\n                            const Spacer(),\n                            IconButton(\n                              tooltip: appText(\n                                context,\n                                km: 'លុបទាំងអស់',\n                                en: 'Delete all',\n                              ),\n                              padding: EdgeInsets.zero,\n                              constraints: const BoxConstraints(\n                                minWidth: 28,\n                                minHeight: 28,\n                              ),\n                              visualDensity: VisualDensity.compact,\n                              onPressed: () async {\n                                for (var item in items) {\n                                  await item.reference.delete();\n                                }\n                              },\n                              icon: const Icon(\n                                Icons.delete_outline_rounded,\n                                size: 19,\n                                color: Colors.red,\n                              ),\n                            ),''',
    'chat cart compact header and clear icon',
)
swap(
    '''                      SizedBox(\n                        height: 75, // 🎯 បង្កើនកម្ពស់ពី 60 ទៅ 75 ដើម្បីល្មមនឹងតម្លៃទំនិញ\n                        child: ListView.builder(\n                          scrollDirection: Axis.horizontal,\n                          padding: const EdgeInsets.symmetric(horizontal: 8),''',
    '''                      SizedBox(\n                        height: 62,\n                        child: ListView.builder(\n                          scrollDirection: Axis.horizontal,\n                          padding: const EdgeInsets.symmetric(horizontal: 6),''',
    'chat cart panel height',
)
swap(
    '''                            return Container(\n                              width: 85, // 🎯 បង្កើនទទឹងបន្តិចពី 80 ទៅ 85\n                              margin: const EdgeInsets.only(right: 6, bottom: 4),''',
    '''                            return Container(\n                              width: 72,\n                              margin: const EdgeInsets.only(right: 5, bottom: 3),''',
    'chat cart item size',
)
swap(
    '''                                            ? Image.network(imageUrl, height: 30, width: double.infinity, fit: BoxFit.cover)\n                                            : Container(height: 30, color: Colors.grey[200]),''',
    '''                                            ? Image.network(imageUrl, height: 23, width: double.infinity, fit: BoxFit.cover)\n                                            : Container(height: 23, color: Colors.grey[200]),''',
    'chat cart image height',
)

p.write_text(text, encoding='utf-8')
print('iOS Android 46 chat parity batch complete')
