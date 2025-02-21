import 'package:flutter/material.dart';
import 'package:dexcom/dexcom.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dexcom Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green, // For Dexcom
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green, // For Dexcom
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // Change to test out your Dexcom account

  String username = "username"; // Can be email, username, or phone number
  String password = "password";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("dexcom Example"),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Press the buttons to see the dexcom package in action!",
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
              ),
              Text("Username: $username\nPassword: $password"),
              TextButton(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("Get past 6 glucose readings"),
                ),
                onPressed: () async {
                  List data = await getGlucoseReadings(username, password);
                  List readings = [];
                  for (var item in data) {
                    readings.add("${item["Value"]} ${item["Trend"]}");
                  }
                  showDialogue("Past 6 glucose readings", readings.toString());
                },
              ),
              TextButton(
                child: Text("Verify login"),
                onPressed: () async {
                  try {
                    await verifyLogin(username, password);
                    showDialogue(
                        "Verified login", "Login successfully verified");
                  } catch (e) {
                    showDialogue(
                        "Verified login", "Login unsuccessfully verified: $e");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List> getGlucoseReadings(String username, String password) async {
    print("Loading...");
    try {
      Dexcom dexcom = Dexcom(username: username, password: password);
      List readings = (await dexcom.getGlucoseReadings(maxCount: 6))!;
      return readings;
    } catch (e) {
      showDialogue("Unable to verify login", e.toString());
      throw Exception(e);
    }
  }

  Future<void> verifyLogin(String username, String password) async {
    print("Loading...");
    Dexcom dexcom = Dexcom(username: username, password: password);
    try {
      Map verify = await dexcom.verify();
      if (verify["success"]) {
        return;
      } else {
        throw Exception(verify["error"]);
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  void showDialogue(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
