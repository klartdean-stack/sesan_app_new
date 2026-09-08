from pathlib import Path
p=Path('lib/chat_screen_legacy.dart')
s=p.read_text(encoding='utf-8')
def r(a,b,label):
 global s
 if a not in s: raise SystemExit('MISSING '+label)
 s=s.replace(a,b,1); print('OK',label)
r("import 'location_picker_sheet.dart';\n","import 'location_picker_sheet.dart';\nimport 'localized_text.dart';\n",'import')
r('  final List<String> _quickReplies = [\n    "តម្លៃប៉ុន្មាន?",\n    "ទីតាំងនៅណាដែរ?",\n    "នៅមានស្តុកទេ?",\n    "បាទ/ចា៎វានៅមាន",\n    "សួស្ដីបង! តើសួរទំនិញមួយណាដែរ?",\n    "សុំលេខ និងទីតាំងទទួលឥវ៉ាន់ផងបង",\n    "ជួយចេញបុងអោយផង",\n    "បាទ/ចា៎បានទទួល! សូមអរគុណច្រើន!🙏",\n  ];',"  List<String> get _quickReplies => [\n    appText(context, km: 'តម្លៃប៉ុន្មាន?', en: 'How much is it?'),\n    appText(context, km: 'ទីតាំងនៅណាដែរ?', en: 'Where are you located?'),\n    appText(context, km: 'នៅមានស្តុកទេ?', en: 'Is it still in stock?'),\n    appText(context, km: 'បាទ/ចា៎វានៅមាន', en: 'Yes, it is available.'),\n    appText(context, km: 'សួស្ដីបង! តើសួរទំនិញមួយណាដែរ?', en: 'Hello! Which product are you asking about?'),\n    appText(context, km: 'សុំលេខ និងទីតាំងទទួលឥវ៉ាន់ផងបង', en: 'Please send your phone number and delivery location.'),\n    appText(context, km: 'ជួយចេញបុងអោយផង', en: 'Please create an invoice.'),\n    appText(context, km: 'បាទ/ចា៎បានទទួល! សូមអរគុណច្រើន!🙏', en: 'Received. Thank you! 🙏'),\n  ];",'quick replies')
r("'ទំនិញដែលចង់ទិញ (${items.length})'","appText(context, km: 'ទំនិញដែលចង់ទិញ (${items.length})', en: 'Cart items (${items.length})')",'cart items')
r("child: const Text(\n                                'លុបទាំងអស់',","child: Text(\n                                appText(context, km: 'លុបទាំងអស់', en: 'Clear all'),",'clear all')
r("addedByMe ? 'ខ្លួនឯង' : addedByName","addedByMe ? appText(context, km: 'ខ្លួនឯង', en: 'You') : addedByName",'self')
r("decoration: const InputDecoration(\n                    hintText: 'សរសេរសារ...',","decoration: InputDecoration(\n                    hintText: appText(context, km: 'សរសេរសារ...', en: 'Write a message...'),",'hint')
r('title: const Text("ជ្រើសរើសរូបភាពពី Gallery")','title: Text(appText(context, km: "ជ្រើសរើសរូបភាពពី Gallery", en: "Choose photos from Gallery"))','photos')
r('title: const Text("ថតរូបថ្មី")','title: Text(appText(context, km: "ថតរូបថ្មី", en: "Take a photo"))','camera')
r('title: const Text("វីដេអូពី Gallery")','title: Text(appText(context, km: "វីដេអូពី Gallery", en: "Choose video from Gallery"))','video gallery')
r('title: const Text("ថតវីដេអូថ្មី")','title: Text(appText(context, km: "ថតវីដេអូថ្មី", en: "Record a video"))','record video')
r('label: const Text(\n                "បង្កើតបុង",','label: Text(\n                appText(context, km: "បង្កើតបុង", en: "Create invoice"),','invoice')
p.write_text(s,encoding='utf-8')
# trigger v2
