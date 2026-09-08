from pathlib import Path
p=Path('lib/chat_screen_legacy.dart')
s=p.read_text(encoding='utf-8')
def rep(a,b,label,count=1):
 global s
 if a not in s: raise SystemExit('MISSING '+label)
 s=s.replace(a,b,count); print('OK',label)
rep("_errorMessage = 'សូម Login មុននឹងប្រើឆាត';","_errorMessage = appText(context, km: 'សូម Login មុននឹងប្រើឆាត', en: 'Please log in before using Chat');",'login error')
rep("_errorMessage = 'មានបញ្ហា: $e';","_errorMessage = appText(context, km: 'មានបញ្ហា: $e', en: 'Error: $e');",'init error')
rep(".showSnackBar(SnackBar(content: Text('ផ្ញើសារមិនបាន: $e')));",".showSnackBar(SnackBar(content: Text(appText(context, km: 'ផ្ញើសារមិនបាន: $e', en: 'Could not send message: $e'))));",'send error')
rep("_showSnack('បានលប់សម្លេង', Colors.orange);","_showSnack(appText(context, km: 'បានលុបសម្លេង', en: 'Recording deleted'), Colors.orange);",'record deleted')
rep("_showSnack('🔒 Lock — ចុច Send ពេលចប់', Colors.green);","_showSnack(appText(context, km: '🔒 បានចាក់សោ — ចុចផ្ញើពេលចប់', en: '🔒 Locked — tap Send when finished'), Colors.green);",'locked')
rep("label: 'ចម្លងអក្សរ',","label: appText(context, km: 'ចម្លងអក្សរ', en: 'Copy text'),",'copy label')
rep("_showSnack('បានចម្លងហើយ', Colors.blue);","_showSnack(appText(context, km: 'បានចម្លងហើយ', en: 'Copied'), Colors.blue);",'copied')
rep("label: isHighlighted ? 'លុប Highlight' : 'Highlight ⭐',","label: isHighlighted\n                    ? appText(context, km: 'លុប Highlight', en: 'Remove highlight')\n                    : appText(context, km: 'Highlight ⭐', en: 'Highlight ⭐'),",'highlight label')
rep("isHighlighted ? 'បានលុប Highlight' : '⭐ បាន Highlight',","isHighlighted\n                        ? appText(context, km: 'បានលុប Highlight', en: 'Highlight removed')\n                        : appText(context, km: '⭐ បាន Highlight', en: '⭐ Highlighted'),",'highlight snack')
rep("label: 'លុបសម្រាប់ខ្លួនឯង',","label: appText(context, km: 'លុបសម្រាប់ខ្លួនឯង', en: 'Delete for me'),",'delete me')
rep("label: 'លុបសម្រាប់ទាំងអស់គ្នា',","label: appText(context, km: 'លុបសម្រាប់ទាំងអស់គ្នា', en: 'Delete for everyone'),",'delete everyone')
rep("const Text(\n                'លុបសម្រាប់ទាំងអស់គ្នា?',\n                style: TextStyle(","Text(\n                appText(context, km: 'លុបសម្រាប់ទាំងអស់គ្នា?', en: 'Delete for everyone?'),\n                style: const TextStyle(",'delete title')
rep("'សារនេះនឹងបាត់ចេញពីទូរស័ព្ទ'\n                    'ទាំងអស់គ្នា មិនអាចដកវិញបានទេ។',","appText(\n                  context,\n                  km: 'សារនេះនឹងបាត់ចេញពីទូរស័ព្ទទាំងអស់គ្នា មិនអាចដកវិញបានទេ។',\n                  en: 'This message will be removed for everyone and cannot be undone.',\n                ),",'delete body')
rep("child: const Text(\n                        'បោះបង់',\n                        style: TextStyle(fontFamily: 'Siemreap'),\n                      ),","child: Text(\n                        appText(context, km: 'បោះបង់', en: 'Cancel'),\n                        style: const TextStyle(fontFamily: 'Siemreap'),\n                      ),",'cancel')
rep("child: const Text(\n                        'លុបចេញ',\n                        style: TextStyle(","child: Text(\n                        appText(context, km: 'លុបចេញ', en: 'Delete'),\n                        style: const TextStyle(",'delete button')
rep("_showSnack('បានលុបសម្រាប់ទាំងអស់គ្នា', Colors.red);","_showSnack(appText(context, km: 'បានលុបសម្រាប់ទាំងអស់គ្នា', en: 'Deleted for everyone'), Colors.red);",'deleted everyone')
rep("'message': '🚫 សារត្រូវបានលុប',","'message': appText(context, km: '🚫 សារត្រូវបានលុប', en: '🚫 Message deleted'),",'deleted placeholder')
rep("_showSnack('បានលុបចេញ', Colors.orange);","_showSnack(appText(context, km: 'បានលុបចេញ', en: 'Deleted'), Colors.orange);",'deleted')
rep("_showSnack('❌ លុបមិនបាន: $e', Colors.red);","_showSnack(appText(context, km: '❌ លុបមិនបាន: $e', en: '❌ Could not delete: $e'), Colors.red);",'delete error')
old="""    if (messageDate == today) {
      return 'ថ្ងៃនេះ ម៉ោង $timeStr';
    } else if (messageDate == yesterday) {
      return 'ម្សិលមិញ ម៉ោង $timeStr';
    } else {
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    }"""
new="""    if (messageDate == today) {
      return appText(context, km: 'ថ្ងៃនេះ ម៉ោង $timeStr', en: 'Today at $timeStr');
    } else if (messageDate == yesterday) {
      return appText(context, km: 'ម្សិលមិញ ម៉ោង $timeStr', en: 'Yesterday at $timeStr');
    } else {
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    }"""
rep(old,new,'date headers')
# More visible picker/recording strings in same chat UI.
rep("const Text(\n                      'កំពុងថតសម្លេង...',","Text(\n                      appText(context, km: 'កំពុងថតសម្លេង...', en: 'Recording...'),",'recording')
rep("subtitle: const Text(\n                \"ជ្រើសរើសបានច្រើនសន្លឹកក្នុងពេលតែមួយ\",\n                style: TextStyle(fontSize: 12, color: Colors.grey),\n              ),","subtitle: Text(\n                appText(context, km: 'ជ្រើសរើសបានច្រើនសន្លឹកក្នុងពេលតែមួយ', en: 'Select multiple images at once'),\n                style: const TextStyle(fontSize: 12, color: Colors.grey),\n              ),",'multi image')
p.write_text(s,encoding='utf-8')
