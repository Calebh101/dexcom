import 'package:dexcom/share.dart';

void main({String username = "", String password = ""}) async {
  Dexcom dexcom = Dexcom(username: username, password: password, debug: false);
  DexcomStreamProvider provider = DexcomStreamProvider(
    dexcom,
    debug: true,
    buffer: 10,
  );

  print("Dexcom: $dexcom");
  print("Provider: $provider");

  print("Dexcom readings: ${await dexcom.getGlucoseReadings(maxCount: 3)}");
  print("Dexcom verify: ${await dexcom.verify()}");

  provider.listen(
    onData: (data) => print('Stream received: $data'),
    onError: (error) => print('Stream errored: $error'),
    onTimerChange: (time) {
      print("Stream timer: $time");
    },
  );
}
