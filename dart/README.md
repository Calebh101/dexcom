# About

dexcom for Dart allows you to use Dexcom Share to get your Dexcom CGM data, or anybody else's, to run your application. Includes time (in milliseconds since Enoch), reading, and trend. Use only your email and password to have access to all your glucose data! The username can be an email, username, or phone.

# Important Information

WARNING: This package is in beta (signified by the version 0.x.x). Please use at your own risk.

WARNING: This package fetches, processes, calculates, and outputs real-time blood glucose levels. DO NOT USE/ADVERTISE THIS FOR IMPORTANT MEDICAL TREATMENT DECISIONS.

WE ARE NOT RESPONSIBLE FOR ANY MEDICAL INCIDENTS/EMERGENCIES CREATED/ELEVATED BECAUSE OF THIS PROGRAM OR ANY PROGRAMS USING IT. USE AT YOUR OWN RISK.

# Features

Very simple to use. Just create a Dexcom object with a username and password, then fetch the user's latest readings. The script takes care of all the account IDs, the session IDs, and the session creating automatically. The username can be email, username, or phone number.

# Usage

## Verifying:
```dart
String username = "username";
String password = "password";
String region = "region";
var dexcom = Dexcom(username, password, {region: region}); // region is set automatically if not manually set
List<dynamic>? response;

try {
    // getReadings can be optionally set to false (the default is true) if you just want to check the session success
    await dexcom.verifyLogin(username, password, [optional: getReadings]);
    print("Verified account");
} catch (e) {
    print("Unable to verify account: $e");
}
```
This logs the user into their account and gets their data. If both succeed (or if the session succeeds and getReadings is set to false), it will return
```json
{"success": true, "error": "none"};
```
However, if it fails, it will return:
```json
// If the session fails (wrong username/password):
{"success": false, "error": "session"}
// If the readings cannot be retrieved (not any readings in the last 48 hours may be a cause):
{"success": false, "error": "readings"}
```

## Retrieving data:
```dart
String username = "username";
String password = "password";
var dexcom = Dexcom(username, password);
List<dynamic>? response;
try {
    response = await dexcom.getGlucoseReadings([optional: minutes, maxCount]);
    print("Read data with dexcom: $dexcom");
} catch (e) {
    print("Unable to read data with dexcom: $e");
}

if (response != null) {
    print("Data received: $response");
    return response;
else {
    print("Data is null");
}
```

This actually retrieves the glucose readings from the user. If it fails, it automatically tries to recreate the session. This is sample data (actually taken from a real reading):
```json
[
    {
        WT: Date(1731645818222),
        ST: Date(1731645818222),
        DT: Date(1731645818222-0600),
        Value: 155,
        Trend: Flat
    },
    {
        WT: Date(1731645518663),
        ST: Date(1731645518663),
        DT: Date(1731645518663-0600),
        Value: 155,
        Trend: FortyFiveDown
    }
]
```
As you can see, it's an array of 2 items, because that's how many I wanted the program to get. The top one (item 0) is the most recent. The WT and ST both tell you when the value was taken. DT, I don't even know. Value is the actual glucose value taken. The trend is the arrow direction. The trend can be:
- Flat: steady
- FortyFiveDown: slowly falling (-1/minute)
- FortyFiveUp: slowly rising (+1/minute)
- SingleDown: falling (-2/minute)
- SingleUp: rising (+2/minute)
- DoubleDown: quickly falling (-3/minute)
- DoubleUp: quickly rising (+3/minute)
- None: no trend
- NonComputable: the graph is too wonky for Dexcom to know which way the glucose levels are going. You might be able to try to compute this yourself if you wanted to.
- RateOutOfRange: the bloodsugar is rising or falling too fast to be computable. This typically happens during sensor errors, where the bloodsugar will randomly drop 50 or more before the sensor goes out.

# Additional Information

This package was based off of pydexcom for Python. I was able to port it to Flutter (version `0.0.0`), and then eventually Dart (version `0.1.2`).

For contact/support, email me at [calebh101dev@icloud.com](mailto:calebh101dev@icloud.com).