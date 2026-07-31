import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  String _cityName = "កំពុងស្វែងរកទីតាំង...";
  String _temp = "--";
  String _desc = "សូមរង់ចាំ";
  String _advice = "កំពុងវិភាគស្ថានភាពមេឃ...";
  bool _isLoading = false;

  // 🎯 មុខងារទាញយកទីតាំង និងធាតុអាកាស
  Future<void> _getWeather() async {
    setState(() => _isLoading = true);
    try {
      // ១. សុំច្បាប់ប្រើ GPS
      LocationPermission permission = await Geolocator.requestPermission();
      Position position = await Geolocator.getCurrentPosition();

      // ២. ទាញទិន្នន័យពី API (មេត្រូវចុះឈ្មោះយក API Key ពី openweathermap.org)
      // យកលេខកូដដែលមេផ្ញើមក ដាក់ក្នុងសញ្ញា " " បែបនេះ៖
      String apiKey = "4e36aadcd7e72a9393b46635c4ff70c9";
      var url = Uri.parse(
        "https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric&lang=kh",
      );

      var response = await http.get(url);
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _cityName = data['name'];
          _temp = "${data['main']['temp'].toStringAsFixed(0)}°C";
          _desc = data['weather'][0]['description'];
          _advice = _generateAdvice(data); // បង្កើតដំបូន្មាន
        });
      }
    } catch (e) {
      setState(() => _advice = "មិនអាចទាញទិន្នន័យបានទេ សូមឆែក Internet");
    }
    setState(() => _isLoading = false);
  }

  // 💡 Logic ផ្ដល់ដំបូន្មានកសិកម្ម (Smart Advice)
  String _generateAdvice(Map data) {
    double windSpeed = data['wind']['speed'];
    String weatherMain = data['weather'][0]['main'];

    if (weatherMain == "Rain")
      return "⚠️ កុំអាលដាក់ជី ឬបាញ់ថ្នាំ! ភ្លៀងអាចធ្វើឱ្យខាតបង់។";
    if (windSpeed > 5)
      return "💨 ខ្យល់បក់ខ្លាំងពេក ($windSpeed m/s) មិនសមស្របសម្រាប់ការបាញ់ថ្នាំទេ។";
    return "✅ មេឃស្រឡះល្អ សមស្របសម្រាប់ការងារចម្ការ និងបាញ់ថ្នាំបំប៉ន។";
  }

  @override
  void initState() {
    super.initState();
    _getWeather(); // ហៅឱ្យដើរភ្លាមពេលបើកទំព័រ
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text("ព្យាករណ៍ធាតុអាកាស"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, color: Colors.blue[800]),
                  Text(
                    _cityName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _temp,
                    style: TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.w100,
                      color: Colors.blue[900],
                    ),
                  ),
                  Text(
                    _desc,
                    style: const TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  _buildAdviceCard(),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _getWeather,
                    icon: const Icon(Icons.refresh),
                    label: const Text("ឆែកឡើងវិញ"),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAdviceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "💡 ដំបូន្មានកសិកម្ម",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 10),
          Text(
            _advice,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
