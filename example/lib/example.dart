import 'dart:io';

import 'package:dexcom/dexcom.dart';

void main({
  String username = "",
  String password = "",
  bool verbose = false,
}) async {
  // If DEXCOM_DEBUG is enabled (set to "true" or is greater than 0), then enable debug logging.
  String debug = Platform.environment['DEXCOM_DEBUG'] ?? "false";

  // Set up the main [dexcom] object
  Dexcom dexcom = Dexcom(
    username: username,
    password: password,
    debug: verbose || debug == "true" || (int.tryParse(debug) ?? 0) > 0,
    onStatusUpdate: (status, finished) {
      print("Status update: $status (${status.pretty}) (finished: $finished)");
    },
  );

  // Set up the listener (provider)
  DexcomStreamProvider provider = DexcomStreamProvider(dexcom, debug: verbose);

  print("Dexcom: $dexcom");
  print("Provider: $provider");

  print("Dexcom readings: ${await dexcom.getGlucoseReadings(maxCount: 3)}");
  print("Dexcom verify: ${await dexcom.verify()}");

  // Listen to the provider
  provider.listen(
    onData:
        (data) => print(
          '${DateTime.now().toUtc().toIso8601String()}: Stream received: $data',
        ),
    onError:
        (error) => print(
          '${DateTime.now().toUtc().toIso8601String()}: Stream errored: $error',
        ),
    onTimerChange: (time) {
      if (dexcom.debug)
        print(
          "${DateTime.now().toUtc().toIso8601String()}: Stream timer: $time",
        );
    },
    onRefresh:
        () => print(
          "${DateTime.now().toUtc().toIso8601String()}: Stream refreshing",
        ),
    onRefreshEnd:
        (time) => print(
          "${DateTime.now().toUtc().toIso8601String()}: Stream refresh ended after ${time.inMilliseconds}ms",
        ),
  );

  // Listen for key inputs
  stdin.echoMode = false;
  stdin.lineMode = false;

  stdin.listen((List<int> data) {
    for (int byte in data) {
      String char = String.fromCharCode(byte);

      switch (char) {
        case "r":
          provider.refresh();
          break;
      }
    }
  });
}
