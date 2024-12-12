import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AutoMode extends StatefulWidget {
  final double volume;

  const AutoMode({super.key, required this.volume});

  @override
  State<AutoMode> createState() => _AutoModeState();
}

class _AutoModeState extends State<AutoMode> {
  late double wineAmount;

  @override
  void initState() {
    super.initState();
    wineAmount = widget.volume;
    _loadCurrentWineAmount(); // Load the current wine amount from ESP32 when the widget is initialized
  }

  // Load the initial wine amount from ESP32
  Future<void> _loadCurrentWineAmount() async {
    const url = 'http://192.168.4.1/getSettings';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          wineAmount = (data['wine_number'] as num).toDouble(); // Update the wine amount from ESP32
        });
      } else {
        print("Failed to load wine amount from ESP32");
      }
    } catch (e) {
      print("Error loading wine amount: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chế độ tự động'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Slider(
              value: wineAmount,
              min: 0,
              max: 50,
              divisions: 50,
              label: '${wineAmount.round()} ml',
              onChanged: (double value) {
                setState(() {
                  wineAmount = value;
                });
              },
              onChangeEnd: (double value) {
                _sendWineAmount(value); // Send the updated wine amount to ESP32
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Số lượng rượu: ${wineAmount.round()} ml',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWineAmount(double amount) async {
    final url = 'http://192.168.4.1/winenumber?number=$amount';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        print("Wine amount set successfully");
      } else {
        print("Failed to set wine amount");
      }
    } catch (e) {
      print("Error sending wine amount: $e");
    }
  }

}

