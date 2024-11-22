import 'package:dexcom/dexcom.dart';

// Get Dexcom data (also sets up session)

Future<Map<String, dynamic>?> getDexcomData(username, password) async {
  String username = "username";
  String password = "password";
  Dexcom dexcom = Dexcom(username, password);
  List<dynamic>? response;

  if (username == "" || password == "") {
    // Not logged in
    return {};
  }

  try {
    response = await dexcom.getGlucoseReadings(maxCount: 2);
    print("Read data with dexcom: $dexcom");
  } catch (e) {
    print(
        "An error occurred while logging in: $e: Did you enter the correct username and password? If not, go to Settings > Log In With Dexcom.");
  }

  if (response != null) {
    print(response);

    int readingTime;
    String wtString = response[0]['ST'];
    RegExp regExp = RegExp(r'Date\((\d+)\)');
    Match? match = regExp.firstMatch(wtString);

    if (match != null) {
      int milliseconds = int.parse(match.group(1)!);
      int seconds = milliseconds ~/ 1000;
      print('Time in seconds: $seconds');
      readingTime = seconds;
    } else {
      print('Invalid date format');
      readingTime = 0;
    }

    Map<String, dynamic> data = {
      "bg": response[0]["Value"],
      "trend": response[0]["Trend"],
      "previousreading": response[1]["Value"],
      "readingtime":
          readingTime // in seconds, you can edit the function above to get milliseconds
    };

    print(data);
    return data;
  } else {
    return {"error": "response is null"};
  }
}

// Verify login (creates Dexcom session and gets data to verify that the user is fully logged in)

Future<void> verifyLogin(username, password) async {
  String username = "username";
  String password = "password";
  Dexcom dexcom = Dexcom(username, password);

  try {
    await dexcom.verifyLogin(username, password);
    print("Verified login with dexcom: $dexcom");
  } catch (e) {
    print(
        "An error occurred while logging in: $e (did you enter the correct username and password?)");
  }
}
