import 'package:flutter/material.dart';
import 'package:my_app/agro_calculator_screen.dart';
import 'package:my_app/animal_age_tracker.dart';
import 'package:my_app/animal_feed_calc.dart';
import 'package:my_app/compost_calc.dart';
import 'package:my_app/crop_water_calc.dart';
import 'package:my_app/currency_converter.dart';
import 'package:my_app/electric_calc.dart';
import 'package:my_app/farm_shopping_list.dart';
import 'package:my_app/fence_calc.dart';
import 'package:my_app/fish_calc.dart';
import 'package:my_app/livestock_tracker.dart';
import 'package:my_app/npk_calc.dart';
import 'package:my_app/pesticide_calc_page.dart';
import 'package:my_app/pig_feed_calc.dart';
import 'package:my_app/plant_calc.dart';
import 'package:my_app/profit_calc.dart';
import 'package:my_app/rice_expert_screen.dart';
import 'package:my_app/sack_weigher_screen.dart';
import 'package:my_app/seed_calc.dart';
import 'package:my_app/stock_management_screen.dart';
import 'package:my_app/water_calc.dart';
import 'package:my_app/water_calculator_page.dart';
import 'package:my_app/weather_page.dart';
import 'package:my_app/yield_analysis_page.dart';
import 'land_measure_screen.dart';
import 'package:my_app/weight_calc.dart';


class FarmToolsPage extends StatelessWidget {
  const FarmToolsPage({super.key});


  @override
  Widget build(BuildContext context) {
    // 📊 បញ្ជីឧបករណ៍ (បានបន្ថែម "ស្ថិតិកូនសត្វ" រួចរាល់)
    final List<Map<String, dynamic>> tools = [
      {
        'title': 'ប្ដូររូបិយបណ្ណ',
        'icon': Icons.currency_exchange,
        'color': Colors.blueAccent,
        'desc': 'ដុល្លារ, រៀល, បាត, យ័ន',
      },
      {
        'title': 'គ្រប់គ្រងស្តុក',
        'icon': Icons.inventory_2_outlined,
        'color': Colors.teal.shade700,
        'desc': 'បន្ថែម កាត់ និងតាមដានស្តុកទំនិញ',
      },
      {
        'title': 'ថ្លឹងបាវអូតូ',
        'icon': Icons.scale_outlined, // រូបជញ្ជីងថ្លឹង
        'color': Colors.green,
        'desc': 'កត់ទម្ងន់បាវ និងគិតលុយ',
      },
      {
        'title': 'បញ្ជីទិញអីវ៉ាន់',
        'icon': Icons.assignment_turned_in_rounded,
        'color': Colors.cyan.shade700,
        'desc': 'សរុបចំនួនពូជ ជី និងថ្នាំដែលត្រូវទិញ',
      },
      {
        'title': 'ជញ្ជីងប៉ាន់ស្មាន',
        'icon': Icons.scale,
        'color': Colors.orange[900],
        'desc': 'ទម្ងន់ គោ, ក្របី, ជ្រូក',
      },
      {
        'title': 'វាស់ផ្ទៃដីកសិកម្ម',
        'icon': Icons.map_outlined,
        'color': Colors.green[800],
        'desc': 'វាស់ដោយដើរ ឬចុចលើផែនទី',
      },
      {
        'title': 'ម៉ាស៊ីនគណនា',
        'icon': Icons.calculate_outlined, // រូបម៉ាស៊ីនគណនាឱ្យចំគោលដៅ
        'color': Colors.orange,
        'desc': 'គណនាជី ថ្នាំ និងខ្នាតដី',
      },
      {
        'title': 'វិភាគទិន្នផល',
        'icon': Icons.analytics,
        'color': Colors.green.shade800,
        'desc': 'ប៉ាន់ស្មានទិន្នផលដែលនឹងទទួលបាន',
      },
      {
        'title': 'គណនារបង',
        'icon': Icons.fence,
        'color': Colors.brown,
        'desc': 'បង្គោល, លួសបន្លា, ស៊ីម៉ង់ត៍',
      },
      {
        'title': 'ចំនួនកូនដាំ',
        'icon': Icons.yard,
        'color': Colors.green,
        'desc': 'ដង់ស៊ីតេដាំដុះ, ចម្ងាយជួរ',
      },
      {
        'title': 'ស្ថិតិកូនសត្វ',
        'icon': Icons.list_alt,
        'color': Colors.teal,
        'desc': 'តាមដានមេ និងកូន (Excel Style)',
      },
      {
        'title': 'តាមដានអាយុ',
        'icon': Icons.calendar_month,
        'color': Colors.indigo,
        'desc': 'អាយុបច្ចុប្បន្ន និងថ្ងៃលក់',
      },
      {
        'title': 'គ្រាប់ពូជ',
        'icon': Icons.grass,
        'color': Colors.green.shade800,
        'desc': 'ស្មានបរិមាណពូជតាមផ្ទៃដី',
      },
      {
        'title': 'ចំណេញ-ខាត',
        'icon': Icons.analytics,
        'color': Colors.teal.shade700,
        'desc': 'ប៉ាន់ស្មានដើមទុន និងផលចំណេញ',
      },
      {
        'title': 'ចិញ្ចឹមត្រី',
        'icon': Icons.phishing, // ឬរូប Icons.water
        'color': Colors.blue.shade800,
        'desc': 'គណនាចំនួនត្រីតាមមាឌទឹក',
      },
      {
        'title': 'គណនាជី NPK',
        'icon': Icons.science,
        'color': Colors.green.shade800,
        'desc': 'ស្វែងរកចំនួនបាវជីតាមរូបមន្តដី',
      },
      {
        'title': 'គណនាជីកំប៉ុស្ត',
        'icon': Icons.recycling, // រូបតំណាងជីធម្មជាតិ
        'color': Colors.brown.shade700,
        'desc': 'រូបមន្តជីកំប៉ុស្តគោក និងជីទឹក',
      },
      {
        'title': 'រូបមន្តចំណីសត្វ',
        'icon': Icons.pets,
        'color': Colors.orange.shade700,
        'desc': 'គណនាគ្រឿងផ្សំចំណីមាន់ ទា ក្រួច',
      },
      {
        'title': 'រូបមន្តចំណីជ្រូក',
        'icon': Icons.bakery_dining, // រូបតំណាងគ្រឿងផ្សំចំណី
        'color': Colors.pink.shade400,
        'desc': 'គណនាចំណីកូនជ្រូក ជ្រូកសាច់ និងមេជ្រូក',
      },
      {
        'title': 'មេបច្ចេកទេសស្រូវ',
        'icon': Icons.psychology,
        'color': Colors.green.shade700,
        'desc': 'រូបមន្តជី និងកាលវិភាគថែទាំតាមបច្ចេកទេស',
      },
      {
        'title': 'រូបមន្តលាយថ្នាំ',
        'icon': Icons.science_rounded, // ឬប្រើ Icons.opacity
        'color': Colors.purple.shade700,
        'desc': 'គណនាបរិមាណថ្នាំកសិកម្មតាមខ្នាតធុង',
      },
      {
        'title': 'គណនាបរិមាណទឹក',
        'icon': Icons.water_drop, // ឬប្រើ Icons.waves
        'color': Colors.blue.shade700,
        'desc': 'គណនាទឹកអាង និងស្រះជម្រាល',
      },
      {
        'title': 'តម្រូវការទឹក',
        'icon': Icons.water_drop,
        'color': Colors.blueAccent.shade700,
        'desc': 'គណនាទឹកស្រោចតាមប្រភេទដំណាំ',
      },
      {
        'title': 'ប្រព័ន្ធទឹក',
        'icon': Icons.water_drop,
        'color': Colors.blue,
        'desc': 'ទុយោ, ក្បាលបាញ់, ម៉ូទ័រ',
      },
      {
        'title': 'ប្រព័ន្ធភ្លើង',
        'icon': Icons.flash_on,
        'color': Colors.orange,
        'desc': 'ខ្សែភ្លើង, បង្គោល, អំពូល',
      },
      {
        'title': 'ពិនិត្យមេឃ',
        'icon': Icons.wb_sunny_rounded,
        'color': Colors.blue.shade800,
        'desc': 'ដំបូន្មានបាញ់ថ្នាំ និងដាក់ជីតាមធាតុអាកាស',
      },
    ];


    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ជំនួយការកសិករ", // ដូរពី "ខួរក្បាលទី២ របស់កសិករ" មកពាក្យនេះវិញ
          style: TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade700, // ពណ៌បៃតងតំណាងឱ្យកសិកម្ម
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 0.85,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return InkWell(
              onTap: () {
                if (tool['title'] == 'បញ្ជីទិញអីវ៉ាន់') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FarmShoppingList(),
                    ),
                  );
                } else if (tool['title'] == 'គ្រប់គ្រងស្តុក') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StockManagementScreen(),
                    ),
                  );
                }
                // ថែមជួរនេះចូលក្នុង logic navigation របស់មេ
                else if (tool['title'] == 'ថ្លឹងបាវអូតូ') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SackWeigherScreen(),
                    ),
                  );
                }
                // 🎯 Logic សម្រាប់បើក Page នីមួយៗតាមឈ្មោះ Title
                if (tool['title'] == 'វាស់ផ្ទៃដីកសិកម្ម') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LandMeasureScreen(),
                    ),
                  );
                } else if (tool['title'] == 'ម៉ាស៊ីនគណនា') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AgroCalculatorScreen(),
                    ),
                  );
                } else if (tool['title'] == 'វិភាគទិន្នផល') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const YieldAnalysisPage(),
                    ),
                  );
                } else if (tool['title'] == 'គណនារបង') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FenceCalcPage(),
                    ),
                  );
                } else if (tool['title'] == 'ចំនួនកូនដាំ') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlantCalcPage(),
                    ),
                  );
                } else if (tool['title'] == 'ប្រព័ន្ធទឹក') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IrrigationCalcPage(),
                    ),
                  );
                } else if (tool['title'] == 'ប្រព័ន្ធភ្លើង') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ElectricCalcPage(),
                    ),
                  );
                } else if (tool['title'] == 'ស្ថិតិកូនសត្វ') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LivestockTrackerPage(),
                    ),
                  );
                } else if (tool['title'] == 'តាមដានអាយុ') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnimalAgeTrackerPage(),
                    ),
                  );
                } else if (tool['title'] == 'ប្ដូររូបិយបណ្ណ') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CurrencyScreen(),
                    ),
                  );
                } else if (tool['title'] == 'ជញ្ជីងប៉ាន់ស្មាន') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnimalWeightPage(),
                    ),
                  );
                } else if (tool['title'] == 'គ្រាប់ពូជ') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SeedCalcPage(),
                    ),
                  );
                } else if (tool['title'] == 'ចំណេញ-ខាត') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfitCalcPage(),
                    ),
                  );
                } else if (tool['title'] == 'តម្រូវការទឹក') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CropWaterCalcPage(),
                    ),
                  );
                } else if (tool['title'] == 'ចិញ្ចឹមត្រី') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FishCalcPage(),
                    ),
                  );
                } else if (tool['title'] == 'គណនាជី NPK') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NPKCalcPage(),
                    ),
                  );
                } else if (tool['title'] == 'គណនាជីកំប៉ុស្ត') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CompostCalcPage(),
                    ),
                  );
                } else if (tool['title'] == 'រូបមន្តចំណីសត្វ') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnimalFeedCalcPage(),
                    ),
                  );
                } else if (tool['title'] == 'រូបមន្តចំណីជ្រូក') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PigFeedCalcPage(),
                    ),
                  );
                } else if (tool['title'] == 'មេបច្ចេកទេសស្រូវ') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RiceMasterProPage(),
                    ),
                  );
                } else if (tool['title'] == 'រូបមន្តលាយថ្នាំ') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PesticideCalcPage(),
                    ),
                  );
                }
                // សម្រាប់ព្យាករណ៍ធាតុអាកាស
                else if (tool['title'] == 'ពិនិត្យមេឃ') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WeatherPage(),
                    ),
                  );
                } else if (tool['title'] == 'គណនាបរិមាណទឹក') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WaterCalculatorPage(),
                    ),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: tool['color'].withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(tool['icon'], size: 40, color: tool['color']),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tool['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        tool['desc'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}



