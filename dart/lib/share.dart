/// Library that uses the Dexcom Share API.
library share;

import 'dart:async'; // Manages timers and streams
import 'dart:convert'; // Convert JSON into URL body

import 'package:http/http.dart'
    as http; // Fetch account ID, session ID, and user data
import 'package:intl/intl.dart'; // Get region
import 'package:dexcom/_api/all.dart';

export '_api/all.dart';

// Gets the current locale using Intl.
DexcomRegion _getRegion() {
  String locale = Intl.getCurrentLocale();
  List<String> localeParts = locale.split('_');
  String countryCode = localeParts.length > 1 ? localeParts[1] : 'OUS';

  if (countryCode == 'US') {
    return DexcomRegion.us;
  } else if (countryCode == 'JP') {
    return DexcomRegion.jp;
  } else {
    return DexcomRegion.ous;
  }
}

// Lists all the endpoints for the requests
Map _dexcomData = {
  "endpoint": {
    "session": "General/LoginPublisherAccountById",
    "account": "General/AuthenticatePublisherAccount",
    "data": "Publisher/ReadPublisherLatestGlucoseValues"
  }
};

String _getBaseUrl(DexcomRegion region) {
  switch (region) {
    case DexcomRegion.us: return "https://share2.dexcom.com/ShareWebServices/Services";
    case DexcomRegion.ous: return "https://shareous1.dexcom.com/ShareWebServices/Services";
    case DexcomRegion.jp: return "https://share.dexcom.jp/ShareWebServices/Services";
  }
}

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
  String get({DexcomRegion? code}) {
    code ??= _getRegion();
    switch (code) {
      case DexcomRegion.us:
        if (us != null) {
          return us!;
        } else {
          throw Exception("A US app ID was not provided.");
        }
      case DexcomRegion.ous:
        if (ous != null) {
          return ous!;
        } else {
          throw Exception("An out-of-US app ID was not provided.");
        }
      case DexcomRegion.jp:
        if (jp != null) {
          return jp!;
        } else {
          throw Exception("A Japanese app ID was not provided.");
        }
    }
  }

  @override
  String toString() {
    return "DexcomAppIds(us: ${us != null}, ous: ${ous != null}, jp: ${jp != null})";
  }
}

/// Main class that controls all of the functions.
class Dexcom {
  /// Region used to decide which server and app ID to use.
  DexcomRegion? region;

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

  /// Application IDs to be used.
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

  DexcomTrend _getTrend(String trend) {
    switch (trend) {
      case "Flat":
        return DexcomTrend.flat;
      case "FortyFiveDown":
        return DexcomTrend.fortyFiveDown;
      case "FortyFiveUp":
        return DexcomTrend.fortyFiveUp;
      case "SingleDown":
        return DexcomTrend.singleDown;
      case "SingleUp":
        return DexcomTrend.singleUp;
      case "DoubleDown":
        return DexcomTrend.doubleDown;
      case "DoubleUp":
        return DexcomTrend.doubleUp;
      case "NonComputable":
        return DexcomTrend.nonComputable;
      case "None":
        return DexcomTrend.none;
      default:
        throw ArgumentError("Invalid trend: $trend");
    }
  }

  // Processes each reading and turns them into [DexcomReading]s
  List<DexcomReading> _process(List<Map<String, dynamic>> data) {
    List<DexcomReading> items = [];
    data.forEach((item) {
      DexcomReading reading = DexcomReading(systemTime: DateTime.parse(item["ST"]), displayTime: DateTime.parse(item["DT"]), value: item["Value"], trend: _getTrend(item["Trend"]));
      items.add(reading);
    });
    return items;
  }

  Future<String> _getAccountId() async {
    _init();
    try {
      final url = Uri.parse(
          "${_getBaseUrl(region!)}/${_dexcomData["endpoint"]["account"]}");
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
          "${_getBaseUrl(region!)}/${_dexcomData["endpoint"]["session"]}");
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

  Future<List<DexcomReading>> _getGlucoseReadings(
      {int? minutes, int? maxCount}) async {
    minutes ??= this.minutes;
    maxCount ??= this.maxCount;

    try {
      final url = Uri.parse(
          "${_getBaseUrl(region!)}/${_dexcomData["endpoint"]["data"]}");
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
  Future<List<DexcomReading>?> getGlucoseReadings(
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
  @Deprecated("Use verify instead. This function was deprecated as of 1.0.0.")
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

/// Class that provides a stream that you can listen to. This will automatically fetch new readings when the old readings have hit the interval (defaults to 300 seconds).
class DexcomStreamProvider {
  /// The Dexcom object that is listened to.
  final Dexcom object;

  /// Interval (in seconds) that the listener will automatically fetch new readings when the interval is hit. This should not be changed.
  int _interval = 300;

  /// Buffer (in seconds) that is added onto interval to give the client's Dexcom time to upload readings. This can help prevent skipping over a reading.
  int buffer;

  // Controller of the Dexcom reading stream.
  StreamController<List>? _controller;

  /// Debug mode (default is set to object's setting)
  bool? debug;

  /// How many pieces of data should be sent with each new incoming data. This is recommended to be a low number.
  int maxCount;

  /// Timer for the listener. Should not be cahnged
  int? time;

  // To track if someone is already listening.
  bool _isListening = false;

  /// Requires an object (which is a Dexcom object) for listening to.
  DexcomStreamProvider(this.object,
      {this.buffer = 0, this.maxCount = 2, this.debug}) {
    if (buffer < 0) {
      throw Exception("Buffer cannot be negative.");
    }

    if (maxCount < 1) {
      throw Exception("Max count cannot be less than 1.");
    }
  }

  /// Converts the current DexcomStreamProvider object to a string.
  @override
  String toString() {
    return "DexcomStreamProvider(object: $object, buffer: $buffer, maxCount: $maxCount, debug: $debug)";
  }

  /// Refresh the listener.
  void refresh() {
    time = 0;
  }

  /// Start listening to incoming Dexcom readings.
  void listen(
      {void Function(List<dynamic> data)? onData,
      void Function(Error error)? onError,
      void Function(int time)? onTimerChange,
      bool cancelOnError = false}) async {
    if (_isListening == true) {
      throw Exception("This stream is already being listened to.");
    } else {
      _isListening = true;
    }

    _init();
    bool _isProcessing = false;
    _controller = StreamController<List>();
    time = null;

    Timer.periodic(Duration(seconds: 1), (Timer timer) async {
      if (_controller!.isClosed) {
        timer.cancel();
        return;
      }

      if (_isProcessing == false) {
        if (time == null || ((time ?? 0) >= (_interval + buffer))) {
          _isProcessing = true;
          time ??= 0;

          try {
            _log("Getting glucose data", function: "listen.Timer");
            List data = (await object.getGlucoseReadings(maxCount: maxCount))!;
            time = (data[0]["TimeSince"] / 1000).toInt();

            if (time! >= _interval) {
              time = 0;
            }

            _controller!.add(data);
            (onData ?? () {})(data);
          } catch (e) {
            _controller!.addError(e);
            (onError ?? () {})(e);
            print("DexcomStreamProvider listen error: $e");

            if (cancelOnError) {
              rethrow;
            }
          } finally {
            _isProcessing = false;
          }
        }
      }

      time = (time == null ? 0 : time! + 1);
      (onTimerChange ?? () {})(time);
    });
  }

  /// Close the stream listening to the Dexcom readings.
  void close() {
    if (_isListening == false) {
      print("The stream is already closed.");
    }

    _init();
    time = null;
    _controller!.close();
    _isListening = false;
  }

  // Custom logging solution
  void _log(String message, {required String function}) {
    _init();
    if (debug!) {
      print("dexcom provider: $function: $message");
    }
  }

  // Initialize variables and checks
  void _init() {
    debug ??= object.debug;
  }

  /// Stream that can be listened to for new Dexcom readings.
  Stream<List>? get stream => _controller?.stream;
}