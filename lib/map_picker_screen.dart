import 'package:flutter/material.dart';


class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // ១. កំណត់ទីតាំងដំបូង (ឧទាហរណ៍៖ ភ្នំពេញ)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "រើសទីតាំងទំនិញ",
          style: TextStyle(fontFamily: 'KHMEROS', fontSize: 16),
        ),
        backgroundColor: Colors.green,

      ),
      body: Stack(
      ),
    );
  }
}
