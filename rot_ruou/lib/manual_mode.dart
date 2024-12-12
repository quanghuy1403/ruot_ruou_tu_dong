import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ManualMode extends StatefulWidget {
  const ManualMode({super.key});

  @override
  State<ManualMode> createState() => _ManualModeState();
}

class _ManualModeState extends State<ManualMode> {
  bool manualModeState = false;
  bool startButtonPressed = false;
  bool lastStartButtonPressed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _checkButtonState();
    });
  }

  Future<void> _checkButtonState() async {
    const url = 'http://192.168.4.1/getSettings';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        bool newStartButtonPressed = data['start_button_pressed'] ?? false;
        bool newManualModeState = data['manual_mode'] ?? false;

        if (newStartButtonPressed != lastStartButtonPressed || newManualModeState != manualModeState) {
          setState(() {
            startButtonPressed = newStartButtonPressed;
            lastStartButtonPressed = newStartButtonPressed;
            manualModeState = newManualModeState;
          });

          if (startButtonPressed) {
            Timer(const Duration(milliseconds: 500), () {
              setState(() {});
            });
          }
        }
      } else {
        print("Failed to load settings from ESP32");
      }
    } catch (e) {
      print("Error checking button state: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chế độ thủ công'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      manualModeState = true;
                    });
                    _sendManualButton(manualModeState);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Bật',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      manualModeState = false;
                    });
                    _sendManualButton(manualModeState);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Tắt',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Trạng thái nút: ${manualModeState ? "Bật" : "Tắt"}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendManualButton(bool status) async {
    final url = 'http://192.168.4.1/manual?button=$status';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        print("Manual mode update successful");
      } else {
        print("Manual mode update failed");
      }
    } catch (e) {
      print("Error sending manual mode: $e");
    }
  }
}
