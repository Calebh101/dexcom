import 'dart:io';

import 'package:dexcom/dexcom.dart';

void main({String username = "", String password = ""}) async {
  // Set up the main [dexcom] object
  Dexcom dexcom = Dexcom(username: username, password: password, debug: true);

  // Set up the listener (provider)
  DexcomStreamProvider provider = DexcomStreamProvider(
    dexcom,
    debug: true,
    buffer: 10,
  );

  print("Dexcom: $dexcom");
  print("Provider: $provider");

  print("Dexcom readings: ${await dexcom.getGlucoseReadings(maxCount: 3)}");
  print("Dexcom verify: ${await dexcom.verify()}");

  // Listen to the provider
  provider.listen(
    onData: (data) => print('Stream received: $data'),
    onError: (error) => print('Stream errored: $error'),
    onTimerChange: (time) => print("Stream timer: $time"),
  );

  // Listen for key inputs
  stdin.echoMode = false;
  stdin.lineMode = false;

  stdin.listen((List<int> data) {
    for (int byte in data) {
      String char = String.fromCharCode(byte);
      print("Received character: $char");

      switch (char) {
        case "r":
          provider.refresh();
          break;
      }
    }
  });
}
