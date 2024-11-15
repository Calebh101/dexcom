# About

dexcom for Dart allows you to use Dexcom Share to get your Dexcom CGM data, or anybody else's, to run your application. Includes time (in milliseconds since Enoch), reading, and trend. Use only your email and password to have access to all your glucose data! The username can be an email, username, or phone.

# Features

Very simple to use. Just create a Dexcom object with a username and password, then fetch the user's latest readings. The script takes care of all the account IDs, the session IDs, and the session creating automatically.

# Usage

## Verifying:
```dart
String username = "username";
String password = "password";
var dexcom = Dexcom(username, password);
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

This actually retrieves the glucose readings from the user. If it fails, it automatically tries to recreate the session.

# Additional information

This package was based off of pydexcom for Python. I (and some help from ChatGPT) ported it to Flutter (version `0.0.0`), and then eventually Dart (version `0.1.2`).

WARNING: THIS PACKAGE IS STILL IN BETA: IT MAY BE UNSTABLE! USE AT YOUR OWN RISK!

# How it Works
## Overview

There is no documentation on this that I could find, so I'm going to make my own.
Basically, your program will first get the account ID of the user. Then it uses the account ID to create a session and get the session ID. It then uses the session ID to get the glucose readings. If the glucose readings fail, this may be because of an expired session, so you will need to get the session ID again.

Here are the application IDs, base URLs, and endpoints that the program will use to 
```dart
"appId": {
    "us": "d89443d2-327c-4a6f-89e5-496bbb0317db",
    "ous": "d89443d2-327c-4a6f-89e5-496bbb0317db",
    "jp": "d8665ade-9673-4e27-9ff6-92db4ce13d13"
},
"baseUrl": {
    "us": "https://share2.dexcom.com/ShareWebServices/Services",
    "ous": "https://shareous1.dexcom.com/ShareWebServices/Services",
    "jp": "https://share.dexcom.jp/ShareWebServices/Services"
},
  "endpoint": {
    "account": "General/AuthenticatePublisherAccount",
    "session": "General/LoginPublisherAccountById",
    "data": "Publisher/ReadPublisherLatestGlucoseValues"
}
```

## Account ID
First, you need to get the account ID. This is really simple, as you just need to send a username, a password, and an application id to the server. Depending on where the user is (in the US, out of the US, or Japan), you will send the request to one of these URLs:
- US: https://share2.dexcom.com/ShareWebServices/Services/General/AuthenticatePublisherAccount
- Out of US: https://shareous1.dexcom.com/ShareWebServices/Services/General/AuthenticatePublisherAccount
- Japan: https://share.dexcom.jp/ShareWebServices/Services/General/AuthenticatePublisherAccount
Then, send these as the headers: `{'Content-Type': 'application/json'}`
And send this as the body:
```json
{
  'accountName': username,
  'password': password,
  'applicationId': appId, // based on the region, see the data above in the `appId` section
}
```

Great, now you should have an account ID! This is just step one of the process. Sigh...

## Session ID
