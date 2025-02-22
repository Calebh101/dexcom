/// Main library that controls all the http, sessions, and data processing.
library main;

import 'dart:convert'; // Convert JSON into URL body

import 'package:http/http.dart'
    as http; // Fetch account ID, session ID, and user data
import 'package:intl/intl.dart'; // Get region

// Gets the current locale using
String _getRegion() {
  String region = "us";
  String locale = Intl.getCurrentLocale();
  List<String> localeParts = locale.split('_');
  String countryCode = localeParts.length > 1 ? localeParts[1] : 'OUS';

  if (countryCode == 'US') {
    region = 'us';
  } else if (countryCode == 'JP') {
    region = 'jp';
  } else {
    region = 'ous';
  }

  return region;
}

// Lists all the application IDs, base URLs, and endpoints for the requests
Map _dexcomData = {
  "base": {
    "us": "https://share2.dexcom.com/ShareWebServices/Services",
    "ous": "https://shareous1.dexcom.com/ShareWebServices/Services",
    "jp": "https://share.dexcom.jp/ShareWebServices/Services"
  },
  "endpoint": {
    "session": "General/LoginPublisherAccountById",
    "account": "General/AuthenticatePublisherAccount",
    "data": "Publisher/ReadPublisherLatestGlucoseValues"
  }
};

/// Class for managing and retrieving app IDs.
class DexcomAppIds {
  /// US app ID.
  String? us;

  /// Out-of-US app ID.
  String? ous;

  /// Japanese app ID.
  String? jp;

  /// It is recommended to provide at least US and Japanese app IDs. At least one app ID is required.
  /// US and out-of-US app IDs can be interchangeable, so if one is provided but the other isn't, then the one that isn't will be set to the one that is provided.
  DexcomAppIds({this.us, this.ous, this.jp}) {
    if (ous == null && us != null) {
      ous = us;
    }

    if (us == null && ous != null) {
      us = ous;
    }

    if (us == null && ous == null && jp == null) {
      throw Exception("At least one app ID must be provided.");
    }
  }

  /// Get the requested app ID.
  String get({String? code}) {
    code ??= _getRegion();
    switch (code) {
      case 'us':
        if (us != null) {
          return us!;
        } else {
          throw Exception("A US app ID was not provided.");
        }
      case 'ous':
        if (ous != null) {
          return ous!;
        } else {
          throw Exception("An out-of-US app ID was not provided.");
        }
      case 'jp':
        if (jp != null) {
          return jp!;
        } else {
          throw Exception("A Japanese app ID was not provided.");
        }
      default:
        throw Exception("Invalid region code: $code.");
    }
  }
}

/// Main class that controls all of the functions.
class Dexcom {
  /// Region used to decide which server and app ID to use.
  String? region;

  /// Username used to login to the Dexcom Share API; can be email, username, or phone number.
  String? username;

  /// Password used to login to the Dexcom Share API.
  String? password;

  // Account ID for the account using username and password.
  String? _accountId;

  // Session ID for the session, using account ID and password.
  String? _sessionId;

  /// Debug mode (shows extra logging).
  bool debug;

  /// Default amount of minutes fetched (from now).
  int minutes;

  /// Default maximum amount of glucose readings that can be fetched.
  int maxCount;

  /// Application IDs to be used. You will be required to provide this in a future update.
  DexcomAppIds? appIds;

  /// Makes a Dexcom with the username, password, and region (optional).
  Dexcom(
      {this.username,
      this.password,
      this.region,
      this.debug = false,
      this.minutes = 60,
      this.maxCount = 12,
      this.appIds}) {
    if (maxCount < 1) {
      throw Exception("Max count cannot be less than 1.");
    }
  }

  /// Converts the current Dexcom object to a string.
  /// Does not show the password of the object by default.
  @override
  String toString({bool showPassword = false}) {
    _init();
    return "Dexcom(username: ${username ?? "null"}, password: ${password != null ? (showPassword ? password : ("*" * password!.length)) : "null"}, region: $region, debug: $debug)";
  }

  // Removes quotes from the uuids
  String _formatUuid(String uuid) {
    return uuid.replaceAll('"', '');
  }

  // Processes each reading
  List<Map<String, dynamic>> _process(List<Map<String, dynamic>> data) {
    data.forEach((item) {
      item["TimeSince"] = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(int.parse(
              RegExp(r"Date\((\d+)-\d+\)").firstMatch(item["DT"])!.group(1)!)))
          .inMilliseconds; // Adds a "TimeSince" field with the milliseconds from when the reading was taken to now
    });
    return data;
  }

  Future<String> _getAccountId() async {
    try {
      if (!_dexcomData["base"].containsKey(region)) {
        throw Exception('Invalid region: $region');
      }

      final url = Uri.parse(
          "${_dexcomData["base"][region]}/${_dexcomData["endpoint"]["account"]}");
      _log("Fetching account ID from $url", function: "_getAccountId");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountName': username,
          'password': password,
          'applicationId': appIds!.get(code: region),
        }),
      );

      if (response.statusCode == 200) {
        return _formatUuid(response.body);
      } else {
        throw Exception(
            'Failed to authenticate: Could not retrieve Account ID: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _getSessionId() async {
    try {
      final url = Uri.parse(
          "${_dexcomData["base"][region]}/${_dexcomData["endpoint"]["session"]}");
      _log("Fetching session ID from $url", function: "_getSessionId");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountId': _accountId,
          'password': password,
          'applicationId': appIds!.get(code: region),
        }),
      );
      if (response.statusCode == 200) {
        String responseS = _formatUuid(response.body);
        return responseS;
      } else {
        throw Exception(
            'Failed to authenticate: Could not retrieve Session ID: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Creates a session by getting the accountId, then passing that into _getSessionId(), which will create a new session ready to be used
  Future<void> _createSession() async {
    _init();
    try {
      _accountId ??= await _getAccountId();
      _log("Retrieved account ID", function: "_createSession");
      if (_accountId != null) {
        _sessionId ??= await _getSessionId();
        _log("Retrieved session ID", function: "_createSession");
      } else {
        throw Exception("_accountId was null");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _getGlucoseReadings(
      {int? minutes, int? maxCount}) async {
    minutes ??= this.minutes;
    maxCount ??= this.maxCount;

    try {
      final url = Uri.parse(
          "${_dexcomData["base"][region]}/${_dexcomData["endpoint"]["data"]}");
      _log("Fetching glucose readings from $url",
          function: "_getGlucoseReadings");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionId': _sessionId,
          'minutes': minutes,
          'maxCount': maxCount,
        }),
      );

      if (response.statusCode == 200) {
        return _process(
            List<Map<String, dynamic>>.from(jsonDecode(response.body)));
      } else {
        throw Exception(
            "Unable to fetch readings: Status code ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Gets glucose readings using minutes and maxCount.
  Future<List<Map<String, dynamic>>?> getGlucoseReadings(
      {int? minutes, int? maxCount, bool allowRetrySession = true}) async {
    _init();
    minutes ??= this.minutes;
    maxCount ??= this.maxCount;

    if (_sessionId != null) {
      try {
        final readings =
            await _getGlucoseReadings(minutes: minutes, maxCount: maxCount);
        return readings;
      } catch (e) {
        throw Exception('Failed to fetch glucose readings: $e');
      }
    }

    if (allowRetrySession) {
      await _createSession();
      return await getGlucoseReadings(
          minutes: minutes, maxCount: maxCount, allowRetrySession: false);
    } else {
      return null;
    }
  }

  /// Verifies that the user has the correct username and password by creating a session to confirm that the user used valid credentials.
  Future<Map<String, dynamic>> verify() async {
    _init();
    try {
      await _createSession();
      return {"success": true, "error": "none"};
    } catch (e) {
      _log("$e", function: "verify");
      return {"success": false, "error": "readings"};
    }
  }

  /// Verifies that the user has the correct username and password by creating a session and optionally getting the data to confirm that the user used valid credentials.
  @Deprecated("Use verify instead. This function was deprecated as of 0.2.0.")
  Future<Map<String, dynamic>> verifyLogin(String username, String password,
      {bool getReadings = true, int? minutes}) async {
    _init();
    try {
      await _createSession();
      if (getReadings) {
        try {
          await getGlucoseReadings(
              minutes: minutes ?? this.minutes,
              maxCount: 1,
              allowRetrySession: false);
          return {"success": true, "error": "none"};
        } catch (e) {
          _log("$e", function: "verifyLogin.session");
          return {"success": false, "error": "session"};
        }
      } else {
        return {"success": true, "error": "none"};
      }
    } catch (e) {
      _log("$e", function: "verifyLogin.readings");
      return {"success": false, "error": "readings"};
    }
  }

  // Takes care of variables and pre-flight checks
  void _init() {
    region ??= _getRegion();
    appIds ??= DexcomAppIds(
        us: "d89443d2-327c-4a6f-89e5-496bbb0317db",
        ous: "d89443d2-327c-4a6f-89e5-496bbb0317db",
        jp: "d8665ade-9673-4e27-9ff6-92db4ce13d13");

    if (username == null) {
      throw Exception("Username cannot be null.");
    }

    if (password == null) {
      throw Exception("Password cannot be null.");
    }
  }

  // Custom logging solution
  void _log(String message, {required String function}) {
    if (debug) {
      print("dexcom: $function: $message");
    }
  }
}
