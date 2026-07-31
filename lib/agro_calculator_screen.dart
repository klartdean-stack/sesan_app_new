import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AgroCalculatorScreen extends StatefulWidget {
  const AgroCalculatorScreen({super.key});

  @override
  State<AgroCalculatorScreen> createState() => _AgroCalculatorScreenState();
}

class _AgroCalculatorScreenState extends State<AgroCalculatorScreen> {
  String _input = "";
  String _result = "0";

  // អត្រាប្តូរប្រាក់ (USD, THB, VND ធៀបនឹងរៀល)
  double rateUSD = 4100;
  double rateTHB = 115;
  double rateVND = 0.16;

  String fromCurrency = "USD";
  String toCurrency = "KHR";
  // 🎯 ថែមដុំនេះចូល
  Future<void> _fetchBankRates(
    TextEditingController usdC,
    TextEditingController thbC,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.exchangerate-api.com/v4/latest/USD'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        double khrRate = data['rates']['KHR'].toDouble();
        double thbInUsd = data['rates']['THB'].toDouble();
        double thbRate = khrRate / thbInUsd;

        usdC.text = khrRate.toStringAsFixed(0);
        thbC.text = thbRate.toStringAsFixed(1);
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  void _onPressed(String text) {
    setState(() {
      if (text == "AC") {
        _input = "";
        _result = "0";
      } else if (text == "⌫") {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else if (text == "=") {
        _calculate(isFinal: true);
      } else {
        _input += text;
        _calculate(isFinal: false);
      }
    });
  }

  void _calculate({bool isFinal = false}) {
    if (_input.isEmpty) return;
    try {
      String expInput = _input.replaceAll('x', '*').replaceAll('÷', '/');
      Parser p = Parser();
      Expression exp = p.parse(expInput);
      double eval = exp.evaluate(EvaluationType.REAL, ContextModel());
      _result = eval % 1 == 0
          ? eval.toInt().toString()
          : eval.toStringAsFixed(2);
    } catch (e) {
      if (isFinal) _result = "Error";
    }
  }

  void _convertCurrency() {
    _calculate(isFinal: true);
    double val = double.tryParse(_result) ?? 0;
    if (val == 0) return;
    double khr = fromCurrency == "USD"
        ? val * rateUSD
        : fromCurrency == "THB"
        ? val * rateTHB
        : fromCurrency == "VND"
        ? val * rateVND
        : val;
    double finalRes = toCurrency == "USD"
        ? khr / rateUSD
        : toCurrency == "THB"
        ? khr / rateTHB
        : toCurrency == "VND"
        ? khr / rateVND
        : khr;
    setState(() {
      _result = finalRes % 1 == 0
          ? finalRes.toInt().toString()
          : finalRes.toStringAsFixed(2);
      _input = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Agro Calculator",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => _showSettings(), // 🎯 ហៅផ្ទាំងកែហាងឆេង
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _input,
                    style: const TextStyle(color: Colors.white70, fontSize: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _result,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.grey[900],
            child: Row(
              children: [
                _buildDrop(
                  fromCurrency,
                  (v) => setState(() => fromCurrency = v!),
                ),
                const Icon(Icons.arrow_forward, color: Colors.green, size: 20),
                _buildDrop(toCurrency, (v) => setState(() => toCurrency = v!)),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _convertCurrency,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                    ),
                    child: const Text(
                      "CONVERT",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildKeypad(),
        ],
      ),
    );
  }

  void _showSettings() {
    final usdC = TextEditingController(text: rateUSD.toString());
    final thbC = TextEditingController(text: rateTHB.toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // 🎯 ត្រូវមាន StatefulBuilder ទើបចុច Update ក្នុង Dialog ដើរ
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("កំណត់ហាងឆេង"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usdC,
                decoration: const InputDecoration(labelText: "1 USD = ? KHR"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: thbC,
                decoration: const InputDecoration(labelText: "1 THB = ? KHR"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),

              // 🎯 ប៊ូតុងទាញពីធនាគារ
              TextButton.icon(
                onPressed: () async {
                  await _fetchBankRates(usdC, thbC);
                  setDialogState(() {}); // ឱ្យវាបង្ហាញលេខថ្មីលើអេក្រង់ភ្លាម
                },
                icon: const Icon(Icons.sync, color: Colors.blue),
                label: const Text(
                  "ទាញពីធនាគារអូតូ",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("បោះបង់"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  rateUSD = double.tryParse(usdC.text) ?? rateUSD;
                  rateTHB = double.tryParse(thbC.text) ?? rateTHB;
                });
                Navigator.pop(context);
              },
              child: const Text("រក្សាទុក"),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 ថែមមុខងារ _buildDrop (សម្រាប់ដោះស្រាយ Error ក្នុងរូប ១ និង ២)
  Widget _buildDrop(String val, Function(String?) onChange) {
    return DropdownButton<String>(
      value: val,
      dropdownColor: Colors.grey[850],
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      underline: const SizedBox(),
      items: [
        "USD",
        "KHR",
        "THB",
        "VND",
      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChange,
    );
  }

  // 🎯 ថែមមុខងារ _buildKeypad (សម្រាប់ដោះស្រាយ Error ក្នុងរូប ៣)
  Widget _buildKeypad() {
    final btns = [
      "AC",
      "⌫",
      "%",
      "÷",
      "7",
      "8",
      "9",
      "x",
      "4",
      "5",
      "6",
      "-",
      "1",
      "2",
      "3",
      "+",
      "0",
      ".",
      "00",
      "=",
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.grey[900],
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: btns.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, i) {
          bool isOp = ["÷", "x", "-", "+", "="].contains(btns[i]);
          return ElevatedButton(
            onPressed: () => _onPressed(btns[i]),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOp ? Colors.green[700] : Colors.grey[850],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              btns[i],
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
          );
        },
      ),
    );
  }
}
