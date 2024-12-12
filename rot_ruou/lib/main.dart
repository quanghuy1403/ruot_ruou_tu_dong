import 'package:flutter/material.dart';
import 'auto_mode.dart';
import 'manual_mode.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rót Rượu tự động',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isAutoMode = true;
  bool mode = false;
  double volume = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
    _timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      _checkModeButtonPressed();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialSettings() async {
    const url = 'http://192.168.4.1/getSettings';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          isAutoMode = data['auto_mode'] ?? true;
          mode = !isAutoMode;
          volume = (data['wine_number'] as num).toDouble();
        });
      } else {
        print("Failed to load settings from ESP32");
      }
    } catch (e) {
      print("Error loading settings: $e");
    }
  }

  Future<void> _checkModeButtonPressed() async {
    const url = 'http://192.168.4.1/getSettings';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['mode_button_pressed'] == true) {
          _loadInitialSettings();
        }
      }
    } catch (e) {
      print("Error checking mode button pressed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'Rót Rượu tự động',
            style: TextStyle(
              color: Colors.cyan,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Rót liên tục'),
                Switch(
                  value: isAutoMode,
                  onChanged: (value) async {
                    setState(() {
                      isAutoMode = value;
                      mode = !mode;
                    });
                    await _sendMode(mode);
                  },
                ),
                const Text('Rót tự động'),
              ],
            ),
            Expanded(
              child: isAutoMode
                  ? AutoMode(volume: volume)
                  : const ManualMode(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMode(bool status) async {
    final url = 'http://192.168.4.1/test?leg=${!status}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        print("Mode update successful");
      } else {
        print("Mode update failed");
      }
    } catch (e) {
      print("Error sending mode: $e");
    }
  }
}
