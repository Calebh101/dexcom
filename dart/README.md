# About

dexcom for Dart allows you to use the Dexcom Share API to get your Dexcom CGM data, or anybody else's, to run your application. Includes time (in milliseconds since Unix epoch), reading, and trend. Use only your email and password to have access to all your glucose data! The username can be an email, username, or phone.

# Important Information

WARNING: This package fetches, processes, and outputs real-time blood glucose levels. DO NOT USE/ADVERTISE THIS FOR IMPORTANT MEDICAL TREATMENT DECISIONS. WE ARE NOT RESPONSIBLE FOR ANY MEDICAL INCIDENTS/EMERGENCIES CREATED/ELEVATED BECAUSE OF THIS PROGRAM OR ANY PROGRAMS USING IT. USE AT YOUR OWN RISK, OR AT THE RISK OF ANY CLIENTS USING THIS APP.

# What is the Dexcom Web API?

The Dexcom Web API is Dexcom's official API. It uses OAuth 2.0 among other things. The Dexcom Share API is an unofficial, undocumented method of retrieving glucose. It's extremely helpful for hobbyists who want a way to display their bloodsugar how and where they want it. It's also good for apps that need instant access to glucose data.

| Feature | Dexcom Share API | Dexcom Web API v3 |
|-----------|-----------|-----------|
| Features | Get real-time blood glucose levels | Get retrospective glucose and data |
| Data | Just glucose levels | Past glucose levels, calibration data, and lots more
| Compatibility | Sensors: Dexcom G4+ | Sensors: Dexcom G6+ |
| Documentation | Unofficially documented through projects like [pydexcom](https://github.com/gagebenne/pydexcom), [dexcom-share-api](https://github.com/aud/dexcom-share-api), and my Dexcom project ([dexcom](https://github.com/Calebh101/dexcom)) | Officially documented on Dexcom's website
| Authentication | Username and password are sent with https requests | Apps are authorized by the client using OAuth 2.0

While the Dexcom Share API can only fetch real-time blood glucose levels with no way to control range and other things, the Dexcom Web API has a lot of (officially provided) features:

- Alerts
- Calibrations
- Data ranges
- Device information
- Glucose values
- Events

The main downside to the Web API, along with other things: **it has a data delay of one to three hours**, which is not preferable for some apps.

This package documents and supports the Dexcom Share API, not the Web API.

# Usage

## Verifying:
```dart
String username = "username";
String password = "password";
String region = "region";
var dexcom = Dexcom({username: username, password: username, region: region, debug: bool, minutes: int, maxCount: int, appIds: DexcomAppIds});
List<dynamic>? response;
```

First, let's go over the parameters:
- username: username (email, password, or phone number)
- password: password
- region: region (set automatically if not set)
- debug: shows extra logs
- minutes: default for every function if not explicitly set
- maxCount: default for every function if not explicitly set
- appIds: DexcomAppIds

What is DexcomAppIds?

DexcomAppIds is an object that stores the application IDs needed to send requests. There's a US option, an out-of US (OUS) option, and a Japan (JP) option. US and OUS can sometimes be used interchangeably, so you only have to specify one if you don't want to specify both. The Japanese option is separately managed. If your program is used in a region that you have not set an application ID for, then the Dexcom object will error. There is a default set, in case you don't have your own. (Which is common since this uses an undocumented API.)
Example:

```dart
DexcomAppIds(us: "your-us-app-id", ous: "your-ous-app-id", jp: "your-jp-app-id");
```

```dart
DexcomVerificationResult verificationResult = dexcom.verify();
```

This logs the user into their account to check if the entered credentials are valid. This will return a `DexcomVerificationResult` object.

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
} else {
    print("Data is null");
}
```

This actually retrieves the glucose readings from the user. If it fails, it automatically tries to recreate the session. This is sample data (actually taken from a real reading):

```json
[
  {
    "WT": "2022-11-22T17:29:54.000Z", 
    "ST": "2022-11-22T17:29:54.000Z",      // system time
    "DT": "2022-11-22T11:29:54.000-06:00", // display time
    "Value": 162, 
    "Trend": "FortyFiveUp"
  },
  {
    "WT": "2022-11-22T17:24:54.000Z", 
    "ST": "2022-11-22T17:24:54.000Z",
    "DT": "2022-11-22T11:24:54.000-06:00", 
    "Value": 159, 
    "Trend": "FortyFiveUp"
  }
]
```

This is how the package will return it:

```dart
[
    DexcomReading(
        systemTime: DateTime(2022-11-22T17:29:54.000Z),
        displayTime: DateTime(2022-11-22T17:29:54.000Z),
        value: 162,
        trend: DexcomTrend.fortyFiveUp,
    ),
    DexcomReading(
        systemTime: DateTime(2022-11-22T17:29:54.000Z),
        displayTime: DateTime(2022-11-22T17:29:54.000Z),
        value: 159,
        trend: DexcomTrend.fortyFiveUp,
    ),
]
```

As you can see, it's an array of 2 items, because that's how many I wanted the program to get. The top one (item 0) is the most recent. From the [Dexcom Web API documentation](https://developer.dexcom.com/docs/dexcomv3/endpoint-overview/#time):

> "systemTime is the UTC time according to the device, whereas displayTime is the time being shown on the device to the user. Depending on the device, this time may be user-configurable, and can therefore change its offset relative to systemTime. Note that systemTime is not 'true' UTC time because of drift and/or user manipulation of the devices' clock." 

Value is the actual glucose value taken. The trend is the arrow direction. The trend can be:
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

The program will return DexcomTrend.flat, DexcomTrend.fortyFiveDown, etc. You can convert it to a string with `trend.convert()`.

## Listening:

First, make a new DexcomStreamProvider object:

```dart
DexcomStreamProvider provider = DexcomStreamProvider(object, oneAtATime: bool, debug: bool, interval: int, buffer: int);
```

Parameters:
- `object`: The Dexcom object to listen to.
- `maxCount`: How many pieces of data should be sent with each new incoming data. This is recommended to be a low number.
- `debug`: Show debug logs.
- `buffer`: How long the function should wait after the timer hits the interval before fetching. This is used to give the client's Dexcom time to upload its reading.

```dart
provider.listen(
    onData: (data) => print('Stream received: $data'),
    onError: (error) => print('Stream errored: $error'),
    onTimerChange: (time) => print("Stream timer: $time"),
    onRefresh: () => print("Stream refresh"),
    onRefreshEnd: (time) => print("Stream refresh ended after ${time.inMilliseconds}ms"),
    cancelOnError: false, // True if the listener should cancel when an error is received.
);
```

This will call `onData` when new data is received, `onError` when it throws an error, and `onTimerChange` when the timer is changed, which is normally every second.

Function parameters:

- `onData`: Called when new Dexcom data is received. This also includes manual/automatic refreshes.
- `onError`: Called when the stream errors.
- `onTimerChange`: Called when the timer is changed, which is every second; but sometimes it can slow down when refreshing.
- `onRefresh`: Called when the provider starts refreshing.
- `onRefreshEnd`: Called when the provider is done refreshing. This also includes how long it took to refresh, in a `Duration` object.

To refresh the readings early:

```dart
provider.refresh();
```

This just sets the timer to 0.

# Additional Information

This package was based off of pydexcom for Python. I was able to port it to Flutter (version `0.0.0`), and then eventually Dart (version `0.1.2`).

For contact/support, email me at [calebh101dev@icloud.com](mailto:calebh101dev@icloud.com).
