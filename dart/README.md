# About

dexcom for Dart allows you to use Dexcom Share to get your Dexcom CGM data, or anybody else's, to run your application. Includes time (in milliseconds since Enoch), reading, and trend. Use only your email and password to have access to all your glucose data! The username can be an email, username, or phone.

# Important Information

WARNING: This package is in beta (signified by the version 0.x.x). Please use at your own risk.

WARNING: This package fetches, processes, and outputs real-time blood glucose levels and sensor information. DO NOT USE/ADVERTISE THIS FOR IMPORTANT MEDICAL TREATMENT DECISIONS.

WE ARE NOT RESPONSIBLE FOR ANY MEDICAL INCIDENTS/EMERGENCIES CREATED/ELEVATED BECAUSE OF THIS PROGRAM OR ANY PROGRAMS USING IT. USE AT YOUR OWN RISK.

# Features

Very simple to use. Just create a Dexcom object with a username and password, then fetch the user's latest readings. The script takes care of all the account IDs, the session IDs, and the session creating automatically. The username can be email, username, or phone number.

# The difference between the Dexcom Share API and the Dexcom Web API

| Feature | Dexcom Share API | Dexcom Web API v3 |
|-----------|-----------|-----------|
| Features | Get real-time blood glucose levels | Get retrospective glucose and data |
| Compatibility | Sensors: Dexcom G4+ | Sensors: Dexcom G6+ |
| Documentation | Unofficially documented through [pydexcom](https://github.com/gagebenne/pydexcom) and my Dexcom project ([dexcom](https://github.com/Calebh101/dexcom)) | Officially documented on Dexcom's website
| Authentication | Username and password are sent with https requests | Apps are authorized by the client using OAuth 2.0

While the Dexcom Share API can only fetch real-time blood glucose levels with no way to control range and other things, the Dexcom Web API has a lot of (officially provided) features:

- Alerts
- Calibrations
- Data ranges
- Device information
- Glucose values
- Events

The Dexcom Web API does, however, have a delay of 1 hour in the US and 3 hours outside of the US.

Please note: this package officially supports the Dexcom Share API and the Dexcom Web API v3. We do not provide support for the Dexcom Web API v2. This package's readme only provides documentation on the Dexcom Share API usage, but I will create documentation for the Dexcom Web API and release it soon.

# Installing and Importing

To install: `dart pub add dexcom` or `flutter pub add dexcom`

To import:
- For the Dexcom Share API: `import 'package:dexcom/share.dart';`
- For the Dexcom Web API: `import 'package:dexcom/web.dart';`

# Dexcom Share API Usage

## Verifying:
```dart
String username = "username";
String password = "password";
DexcomRegion region = "region"; // can be: DexcomRegion.us, DexcomRegion.ous, or DexcomRegion.jp
var dexcom = Dexcom({username: username, password: username, region: region, debug: bool, minutes: int, maxCount: int, appIds: DexcomAppIds});
List<dynamic>? response;
```

First, let's go over the parameters:
- username: username
- password: password
- region: region (set automatically if not set)
- debug: shows extra logs
- minutes: default for every function if not explicitly set
- maxCount: default for every function if not explicitly set
- appIds: DexcomAppIds

What is DexcomAppIds?

DexcomAppIds is an object that stores the application IDs needed to send requests. There's a US option, an out-of US (OUS) option, and a Japan (JP) option. US and OUS can sometimes be used interchangeably, so you only have to specify one if you don't want to specify both. The Japanese option is separately managed. If your program is used in a region that you have not set an application ID for, then your program will error and not work. There is a default set, in case you don't have your own. (Which is common since this uses an undocumented API.)
Example:

```dart
DexcomAppIds(us: "your-us-app-id", ous: "your-ous-app-id", jp: "your-jp-app-id");
```

```dart
try {
    // getReadings can be optionally set to false (the default is true) if you just want to check the session success
    await dexcom.verify();
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
    "WT": "2022-11-22T17:29:54.000Z", 
    "ST": "2022-11-22T17:29:54.000Z", 
    "DT": "2022-11-22T11:29:54.000-06:00", 
    "Value": 162, 
    "Trend": "FortyFiveUp", 
    "TimeSince": 21145 // Milliseconds from when the reading was taken til now. This would be 21 seconds.
  },
  {
    "WT": "2022-11-22T17:24:54.000Z", 
    "ST": "2022-11-22T17:24:54.000Z", 
    "DT": "2022-11-22T11:24:54.000-06:00", 
    "Value": 159, 
    "Trend": "FortyFiveUp", 
    "TimeSince": 321145 // This would be 321 seconds (around 5.5 minutes).
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
- NonComputable: the graph is too wonky for Dexcom to know which way the glucose levels are going. You might be able to try to compute it yourself if you wanted to.
- RateOutOfRange: the bloodsugar is rising or falling too fast to be computable. This typically happens during sensor errors, where the bloodsugar will randomly drop 50 or more before when the sensor malfunctions.

## Listening:

First, make a new DexcomStreamProvider object:

```dart
DexcomStreamProvider provider = DexcomStreamProvider(object, oneAtATime: bool, debug: bool, interval: int, buffer: int);
```

Parameters:
object: The Dexcom object to listen to.
maxCount: How many pieces of data should be sent with each new incoming data. This is recommended to be a low number.
debug: Show debug logs.
buffer: How long the function should wait after the timer hits the interval before fetching. This is used to give the client's Dexcom time to upload its reading.

```dart
provider.listen(
    onData: (data) => print('Stream received: $data'),
    onError: (error) => print('Stream errored: $error'),
    onTimerChange: (time) print("Stream timer: $time"),
    cancelOnError: false, // True if the listener should shut down when an error is received.
);
```

This will call onData when new data is received, onError when it throws an error, and onTimerChange when the timer is changed, which is normally every second. (onTimerChange is mainly a debug option, as you can access provider.timer to get the current timer instead of using onTimerChange.)

To refresh the readings early:

```dart
provider.refresh();
```

This just sets the timer to 0.

# Additional Information

This package was based off of pydexcom for Python. I was able to port it to Flutter (version `0.0.0`), and then eventually Dart (version `0.1.2`). At release `0.2.0` I made a method to use the Dexcom Web API.

For contact/support, email me at [calebh101dev@icloud.com](mailto:calebh101dev@icloud.com).