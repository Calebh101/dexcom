Get Dexcom data (also sets up session)
```dart
Future<Map<String, dynamic>?> getDexcomData(username, password) async {
    Map settings = await getAllSettings();
    var dexcom = Dexcom(username], settings[password]);
    List<dynamic>? response;

    if (username == "" || password == "") {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()), // You can define LoginPage somewhere else in your code
        );
        return {};
    }
  
    try {
        response = await dexcom.getGlucoseReadings(maxCount: 2);
        print("Read data with dexcom: $dexcom");
    } catch (e) {
        showAlertDialogue(context, "Login error:", "An error occurred while logging in: $e: Did you enter the correct username and password? If not, go to Settings > Log In With Dexcom."); // You can define showAlertDialogue somewhere else in your code
    }

    if (response != null) {
        print(response);

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
        }
        
        Map<String, dynamic> data = {
            "bg": response[0]["Value"],
            "trend": getTrend(response[0]["Trend"]),
            "previousreading": response[1]["Value"],
            "readingtime": readingTime // in seconds, you can edit the function above to get milliseconds
        };

        print(data);
        return data;
    } else {
        return {"error": "response is null"};
    }
}
```

Verify login (creates Dexcom session and gets data to verify that the user is fully logged in)
```dart
Future<void> verifyLogin(username, password) async {
    var dexcom = Dexcom(username, password);
  
    try {
        await dexcom.verifyLogin(username, password);
        print("Verified login with dexcom: $dexcom");
        Navigator.pop(context);
    } catch (e) {
        showAlertDialogue(context, "Login error:", "An error occurred while logging in: $e (did you enter the correct username and password?)"); // You can define showAlertDialogue somewhere else in your code
    }
}
```