import 'package:flutter/material.dart';

// ទិន្នន័យទីតាំង ២៥ ខេត្តក្រុង
const Map<String, List<String>> cambodiaProvinceData = {
  "ភ្នំពេញ": [
    "ចំការមន",
    "ដូនពេញ",
    "៧មករា",
    "ទួលគោក",
    "ដង្កោ",
    "មានជ័យ",
    "ឫស្សីកែវ",
    "សែនសុខ",
    "ពោធិ៍សែនជ័យ",
    "ជ្រោយចង្វារ",
    "ព្រែកព្នៅ",
    "ច្បារអំពៅ",
    "បឹងកេងកង",
    "កំបូល",
  ],
  "កណ្តាល": [
    "តាខ្មៅ",
    "កណ្តាលស្ទឹង",
    "គៀនស្វាយ",
    "ខ្សាច់កណ្តាល",
    "កោះធំ",
    "លើកដែក",
    "ល្វាឯម",
    "មុខកំពូល",
    "អង្គស្នួល",
    "ពញាឮ",
    "ស្អាង",
  ],
  "សៀមរាប": [
    "សៀមរាប",
    "អង្គរជុំ",
    "អង្គរធំ",
    "បន្ទាយស្រី",
    "ជីក្រែង",
    "ក្រឡាញ់",
    "ពួក",
    "ប្រាសាទបាគង",
    "ស្រីស្នំ",
    "ស្វាយលើ",
    "វ៉ារិន",
    "សូទ្រនិគម",
  ],
  "ព្រះសីហនុ": ["ព្រះសីហនុ", "កោះរ៉ុង", "ព្រៃនប់", "ស្ទឹងហាវ", "កំពង់សីលា"],
  "បាត់ដំបង": [
    "បាត់ដំបង",
    "បាណន់",
    "ថ្មគោល",
    "បវេល",
    "ឯកភ្នំ",
    "មោងឫស្សី",
    "នរតនមណ្ឌល",
    "សង្កែ",
    "សំឡូត",
    "សំពៅលូន",
    "ភ្នំព្រឹក",
    "កំរៀង",
    "គាស់ក្រឡ",
    "រុក្ខគីរី",
  ],
  "កំពង់ចាម": [
    "កំពង់ចាម",
    "កំពង់សៀម",
    "កងមាស",
    "កោះសុទិន",
    "ចំការលើ",
    "ជើងព្រៃ",
    "ត្បូងឃ្មុំ",
    "បាធាយ",
    "ព្រៃឈរ",
    "ស្រីសន្ធរ",
    "ស្ទឹងត្រង់",
  ],
  "ត្បូងឃ្មុំ": [
    "សួង",
    "ត្បូងឃ្មុំ",
    "អូររាំងឪ",
    "ក្រូចឆ្មារ",
    "តំបែរ",
    "ពញាក្រែក",
    "មេមត់",
  ],
  "កំពង់ធំ": [
    "ស្ទឹងសែន",
    "បារាយណ៍",
    "កំពង់ស្វាយ",
    "ប្រាសាទសំបូរ",
    "សណ្តាន់",
    "សន្ទុក",
    "ស្ទោង",
    "ប្រាសាទបល្ល័ង្ក",
  ],
  "កំពង់ឆ្នាំង": [
    "កំពង់ឆ្នាំង",
    "បរិបូណ៌",
    "ជលគិរី",
    "កំពង់លែង",
    "រលាប្អៀរ",
    "សាមគ្គីមានជ័យ",
    "ទឹកផុស",
  ],
  "កំពង់ស្ពឺ": [
    "ច្បារមន",
    "គងពិសី",
    "ភ្នំស្រួច",
    "សំរោងទង",
    "ថ្ពង",
    "ឧដុង្គ",
    "ឱរ៉ាល់",
    "បរសេដ្ឋ",
  ],
  "តាកែវ": [
    "ដូនកែវ",
    "អង្គរបុរី",
    "បាទី",
    "បុរីជលសារ",
    "គីរីវង់",
    "កោះអណ្តែត",
    "ព្រៃកប្បាស",
    "សំរោង",
    "ត្រាំកក់",
    "ទ្រាំង",
  ],
  "កំពត": [
    "កំពត",
    "ជុំគិរី",
    "ដងទង់",
    "ទឹកឈូ",
    "បន្ទាយមាស",
    "អង្គរជ័យ",
    "កំពង់ត្រាច",
    "ឈូក",
  ],
  "កែប": ["កែប", "ដំណាក់ចង្អើរ"],
  "ព្រះវិហារ": [
    "ព្រះវិហារ",
    "ជ័យសែន",
    "ឆែប",
    "ជាំក្សាន្ត",
    "គូលែន",
    "រវៀង",
    "សង្គមថ្មី",
    "ត្បែងមានជ័យ",
  ],
  "ស្ទឹងត្រែង": [
    "ស្ទឹងត្រែង",
    "សេសាន",
    "សៀមបូក",
    "សៀមប៉ាង",
    "ថាឡាបរិវ៉ាត់",
    "បុរីអូរស្វាយសែនជ័យ",
  ],
  "ក្រចេះ": ["ក្រចេះ", "ឆ្លូង", "ព្រែកប្រសប់", "សំបូរ", "ស្នួល", "ចិត្របុរី"],
  "មណ្ឌលគិរី": ["សែនមនោរម្យ", "កែវសីមា", "កោះញែក", "អូររាំង", "ពេជ្រាដា"],
  "រតនគិរី": [
    "បានលុង",
    "អណ្តូងមាស",
    "បរកែវ",
    "កូនមុំ",
    "លំផាត់",
    "អូរជុំ",
    "អូរយ៉ាដាវ",
    "តាវែង",
    "វើនសៃ",
  ],
  "ឧត្តរមានជ័យ": [
    "សំរោង",
    "អន្លង់វែង",
    "បន្ទាយអំពិល",
    "ចុងកាល់",
    "ត្រពាំងប្រាសាទ",
  ],
  "បន្ទាយមានជ័យ": [
    "សិរីសោភ័ណ",
    "មង្គលបុរី",
    "ភ្នំស្រុក",
    "ព្រះនេត្រព្រះ",
    "អូរជ្រៅ",
    "ភ្នំដាច់",
    "ថ្មពួក",
    "ស្វាយចេក",
    "ប៉ោយប៉ែត",
  ],
  "ប៉ៃលិន": ["ប៉ៃលិន", "សាលាក្រៅ"],
  "ពោធិ៍សាត់": [
    "ពោធិ៍សាត់",
    "បាកាន",
    "កណ្តៀង",
    "ក្រគរ",
    "ភ្នំក្រវាញ",
    "វាលវែង",
    "តាលោសែនជ័យ",
  ],
  "ស្វាយរៀង": [
    "ស្វាយរៀង",
    "ចន្ទ្រា",
    "កំពង់រោទ៍",
    "រំដួល",
    "រមាសហែក",
    "ស្វាយជ្រំ",
    "ស្វាយទាប",
    "បាវិត",
  ],
  "ព្រៃវែង": [
    "ព្រៃវែង",
    "បាភ្នំ",
    "កំចាយមារ",
    "កំពង់ត្របែក",
    "កញ្ជ្រៀច",
    "មេសាង",
    "ពាមជរ",
    "ពាមរក៍",
    "ពារាំង",
    "ព្រះស្តេច",
    "ស្វាយអន្ទរ",
    "ពោធិ៍រៀង",
  ],

  "Thailand_Branches": [
    "បាងកក (តំបន់ប្រាទូណាម)",
    "กรุงเทพฯ (ประตูน้ำ)",
    "បាងកក (តំបន់ជួងណនស៊ី)",
    "กรุงเทพฯ (ช่องนนทรี)",
    "បាងកក (តំបន់បាងណា)",
    "กรุงเทพฯ (บางนา)",
    "បាងកក (តំបន់មិងប៊ុរី)",
    "กรุงเทพฯ (มีนบุรี)",
    "សាមុតប្រាកាន",
    "สมุทรปราการ",
    "សាមុតសាខន (មហាឆៃ)",
    "สมุทรสาคร (มหาชัย)",
    "ប៉ាធុមថានី (តំបន់រង្សិត)",
    "ปทุมธานี (รังสิต)",
    "នន្ទបុរី",
    "นนทบุรี",
    "ឈុនបុរី (ក្រុងប៉ាតាយ៉ា)",
    "ชลบุรี (พัทยา)",
    "ឈុនបុរី (តំបន់សេកុង)",
    "ชลบุรี (ศรีราชา)",
    "រ៉យ៉ង",
    "ระยอง",
    "ច័ន្ទបុរី",
    "จันทบุรี",
    "ត្រាត",
    "ตราด",
    "ច្រកព្រំដែនខ្លងយ៉ៃ (ត្រាត)",
    "ด่านคลองใหญ่ (ตราด)",
    "ច្រកព្រំដែនបានឡែម (ច័ន្ទបុរី)",
    "ด่านบ้านแหลม (จันทบุรี)",
    "ច្រកព្រំដែនសួនស៊ុម (ច័ន្ទបុរី)",
    "ด่านสวนส้ม (จันทบุรี)",
    "ស្រះកែវ (អារញ្ញប្រាថេត)",
    "สระแก้ว (อรัญประเทศ)",
    "ច្រកព្រំដែនរ៉ងខ្លឿ (ស្រះកែវ)",
    "ด่านโรงเกลือ (สระแก้ว)",
    "ព្រះនគរស៊ីអយុធ្យា",
    "พระนครศรีอยุธยา",
    "សារៈបុរី",
    "สระบุรี",
    "នគររាជសីមា (គោរាជ)",
    "นครราชสีมา (โคราช)",
    "បុរីរម្យ",
    "บุรีรัมย์",
    "សុរិន្ទ",
    "สุรินทร์",
    "ស៊ីសាកេត",
    "ศรีสะเกษ",
    "ឧប៊ុនរាជធានី",
    "อุบลราชธานี",
    "ខនកែន",
    "ขอนแก่น",
    "ឧត្តរធានី",
    "อุดรธานี",
    "ឈៀងម៉ៃ",
    "เชียงใหม่",
    "ឈៀងរ៉ាយ",
    "เชียงราย",
    "តាក (ម៉ែសត)",
    "ตาก (แม่สอด)",
    "កញ្ចនបុរី",
    "กาญจนบุรี",
    "រាជបុរី",
    "ราชบุรี",
    "ពេជ្របុរី",
    "เพชรบุรี",
    "ប្រចួបគីរីខាន់",
    "ประจวบคีรีขันธ์",
    "ជុម្ពពរ",
    "ชุมพร",
    "សុរ៉ាតធានី",
    "สุราษฎร์ธานี",
    "ភូកេត",
    "ภูเก็ต",
    "សុងខ្លា (ហាត់យ៉ៃ)",
    "สงขลา (หาดใหญ่)",
  ],

  "Vietnam_Branches": [
    "ទីក្រុងហូជីមិញ",
    "Thành phố Hồ Chí Minh",
    "ខេត្តតៃនិញ (ច្រកម៉ុកបៃ)",
    "Tỉnh Tây Ninh (Cửa khẩu Mộc Bài)",
    "ខេត្តអានយ៉ាង (ច្រកទិញបៀន)",
    "Tỉnh An Giang (Cửa khẩu Tịnh Biên)",
    "ខេត្តគៀនយ៉ាង (ច្រកហាទៀង)",
    "Tỉnh Kiên Giang (Cửa khẩu Hà Tiên)",
    "ខេត្តឡុងអាង (ច្រកប៊ិញហៀប)",
    "Tỉnh Long An (Cửa khẩu Bình Hiệp)",
    "ខេត្តដុងថាប់ (ច្រកយិញដឿង)",
    "Tỉnh Đồng Tháp (Cửa khẩu Dinh Bà)",
    "ទីក្រុងកឹងធើ",
    "Thành phố Cần Thơ",
    "ទីក្រុងហាណូយ",
    "Thành phố Hà Nội",
    "ទីក្រុងដាណាំង",
    "Thành phố Đà Nẵng",
    "ខេត្តប៊ិញយឿង",
    "Tỉnh Bình Dương",
  ],
};

// --- Function បង្ហាញផ្ទាំងរើសខេត្ត ---
void showLocationPicker(BuildContext context, Function(String) onSelected) {
  String searchQuery = "";

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          List<String> filteredProvinces = cambodiaProvinceData.keys
              .where((p) => p.contains(searchQuery))
              .toList();

          return _buildBaseSheet(
            context,
            title: "ជ្រើសរើសខេត្ត/ក្រុង",
            onSearchChanged: (val) => setModalState(() => searchQuery = val),
            child: ListView(
              children: [
                // ប៊ូតុងសរសេរដោយដៃ
                _buildManualInputTile(context, onSelected),
                const Divider(),
                ...filteredProvinces.map(
                  (province) => ListTile(
                    title: Text(province),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.pop(context);
                      _showDistrictSheet(context, province, onSelected);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// --- Function បង្ហាញផ្ទាំងរើសស្រុក ---
void _showDistrictSheet(
  BuildContext context,
  String province,
  Function(String) onSelected,
) {
  String searchQuery = "";
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          List<String> districts = cambodiaProvinceData[province] ?? [];
          List<String> filteredDistricts = districts
              .where((d) => d.contains(searchQuery))
              .toList();

          return _buildBaseSheet(
            context,
            title: "ស្រុក/ខណ្ឌ ក្នុង $province",
            onSearchChanged: (val) => setModalState(() => searchQuery = val),
            child: ListView(
              children: [
                _buildManualInputTile(context, onSelected),
                const Divider(),
                ...filteredDistricts.map(
                  (district) => ListTile(
                    title: Text(district),
                    onTap: () {
                      onSelected("$province, $district");
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// --- ប៊ូតុងសម្រាប់សរសេរដោយដៃ ---
Widget _buildManualInputTile(
  BuildContext context,
  Function(String) onSelected,
) {
  return ListTile(
    leading: const Icon(Icons.edit_note, color: Colors.blue),
    title: const Text(
      "✍️ សរសេរទីតាំងដោយដៃ",
      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
    ),
    onTap: () {
      Navigator.pop(context);
      _showManualInputDialog(context, onSelected);
    },
  );
}

// --- ប្រអប់ Dialog សម្រាប់វាយអក្សរបញ្ចូល ---
void _showManualInputDialog(BuildContext context, Function(String) onSelected) {
  TextEditingController customController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("វាយបញ្ចូលទីតាំង"),
      content: TextField(
        controller: customController,
        decoration: const InputDecoration(
          hintText: "ឧទាហរណ៍៖ ភ្នំពេញ, កោះពេជ្រ...",
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("បោះបង់"),
        ),
        ElevatedButton(
          onPressed: () {
            if (customController.text.isNotEmpty) {
              onSelected(customController.text);
              Navigator.pop(context);
            }
          },
          child: const Text("យល់ព្រម"),
        ),
      ],
    ),
  );
}

// --- UI គ្រោងឆ្អឹងរបស់ BottomSheet ---
Widget _buildBaseSheet(
  BuildContext context, {
  required String title,
  required Function(String) onSearchChanged,
  required Widget child,
}) {
  return Container(
    height: MediaQuery.of(context).size.height * 0.85,
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.all(15),
          child: TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: "ស្វែងរកឈ្មោះ...",
              prefixIcon: const Icon(Icons.search),
              fillColor: Colors.grey[100],
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}
