/// Library that uses the Dexcom Share API.
library dexcom;

import 'dart:async'; // Manages timers and streams
import 'dart:convert'; // Convert JSON into URL body

import 'package:http/http.dart'
    as http; // Fetch account ID, session ID, and user data
import 'package:intl/intl.dart'; // Get region

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
    case DexcomRegion.us:
      return "https://share2.dexcom.com/ShareWebServices/Services";
    case DexcomRegion.ous:
      return "https://shareous1.dexcom.com/ShareWebServices/Services";
    case DexcomRegion.jp:
      return "https://share.dexcom.jp/ShareWebServices/Services";
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
      throw DexcomInitializationError("At least one app ID must be provided.");
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
          throw DexcomInitializationError("A US app ID was not provided.");
        }
      case DexcomRegion.ous:
        if (ous != null) {
          return ous!;
        } else {
          throw DexcomInitializationError(
              "An out-of-US app ID was not provided.");
        }
      case DexcomRegion.jp:
        if (jp != null) {
          return jp!;
        } else {
          throw DexcomInitializationError(
              "A Japanese app ID was not provided.");
        }
    }
  }

  @override
  String toString() {
    return "DexcomAppIds(us: ${us != null}, ous: ${ous != null}, jp: ${jp != null})";
  }
}

/// Thrown when an error occurs during Dexcom account authentication.
class DexcomAuthorizationException implements Exception {
  /// Message of the exception.
  final String? message;

  /// Message is optional.
  DexcomAuthorizationException([this.message]);

  /// Converts the exception to a string.
  /// Called when thrown.
  @override
  String toString() {
    return ["DexcomAuthorizationException", if (message != null) message]
        .join(": ");
  }
}

/// Thrown when an error occurs during Dexcom glucose retrieval.
class DexcomGlucoseRetrievalException implements Exception {
  /// Message of the exception.
  final String? message;

  /// Message is optional.
  DexcomGlucoseRetrievalException([this.message]);

  /// Converts the exception to a string.
  /// Called when thrown.
  @override
  String toString() {
    return ["DexcomGlucoseRetrievalException", if (message != null) message]
        .join(": ");
  }
}

/// Thrown when an error occurs intializing a [Dexcom] or a [DexcomStreamProvider].
class DexcomInitializationError implements Error {
  /// Message of the error.
  final String? message;

  /// Stack trace of the error.
  @override
  final StackTrace stackTrace;

  /// Message is optional.
  DexcomInitializationError([this.message])
      : this.stackTrace = StackTrace.current;

  /// Converts the error to a string.
  /// Called when thrown.
  @override
  String toString() {
    return ["DexcomInitializationError", if (message != null) message]
        .join(": ");
  }
}

/// Used when verifying a user's credentials.
class DexcomVerificationResult {
  /// If true, then user verified. If false, then not verified.
  final bool status;

  /// Status is required.
  const DexcomVerificationResult(this.status);

  @override
  String toString() {
    return "DexcomVerificationResult(status: $status)";
  }
}

/// Main class that controls all of the functions.
class Dexcom {
  // Region used to decide which server and app ID to use.
  DexcomRegion? _region;

  // Application IDs to be used.
  DexcomAppIds? _appIds;

  /// Region used to decide which server and app ID to use.
  DexcomRegion get region => _region ?? _getRegion();

  /// Application IDs to be used.
  DexcomAppIds get appIds =>
      _appIds ??
      DexcomAppIds(
        us: "d89443d2-327c-4a6f-89e5-496bbb0317db",
        ous: "d89443d2-327c-4a6f-89e5-496bbb0317db",
        jp: "d8665ade-9673-4e27-9ff6-92db4ce13d13",
      );

  /// Username used to login to the Dexcom Share API; can be email, username, or phone number.
  final String? username;

  /// Password used to login to the Dexcom Share API.
  final String? password;

  // Account ID for the account using username and password.
  String? _accountId;

  // Session ID for the session, using account ID and password.
  String? _sessionId;

  /// Debug mode (shows extra logging).
  final bool debug;

  /// Default amount of minutes fetched (from now).
  final int minutes;

  /// Default maximum amount of glucose readings that can be fetched.
  final int maxCount;

  /// Makes a Dexcom with the username, password, and region (optional).
  Dexcom(
      {this.username,
      this.password,
      this.debug = false,
      this.minutes = 60,
      this.maxCount = 12,
      DexcomRegion? region,
      DexcomAppIds? appIds}) {
    if (maxCount < 1) {
      throw DexcomInitializationError("Max count cannot be less than 1.");
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

    DateTime formatTime(String time) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(
          (RegExp(r"Date\((.*)\)").firstMatch(time)!.group(1)!).split('-')[0]));
    }

    data.forEach((item) {
      DexcomReading reading = DexcomReading(
          systemTime: formatTime(item["ST"]),
          displayTime: formatTime(item["DT"]),
          value: item["Value"],
          trend: _getTrend(item["Trend"]));
      items.add(reading);
    });

    return items;
  }

  Future<String> _getAccountId() async {
    _init();
    try {
      final url = Uri.parse(
          "${_getBaseUrl(region)}/${_dexcomData["endpoint"]["account"]}");
      _log("Fetching account ID from $url", function: "_getAccountId");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountName': username,
          'password': password,
          'applicationId': appIds.get(code: region),
        }),
      );

      if (response.statusCode == 200) {
        return _formatUuid(response.body);
      } else {
        throw DexcomAuthorizationException('Could not retrieve Account ID');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _getSessionId() async {
    try {
      final url = Uri.parse(
          "${_getBaseUrl(region)}/${_dexcomData["endpoint"]["session"]}");
      _log("Fetching session ID from $url", function: "_getSessionId");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountId': _accountId,
          'password': password,
          'applicationId': appIds.get(code: region),
        }),
      );
      if (response.statusCode == 200) {
        String responseS = _formatUuid(response.body);
        return responseS;
      } else {
        throw DexcomAuthorizationException('Could not retrieve Session ID');
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
        throw DexcomAuthorizationException(
            "Could not retrieve Account ID: Account ID returned null.");
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
          "${_getBaseUrl(region)}/${_dexcomData["endpoint"]["data"]}");
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
        throw DexcomGlucoseRetrievalException(
            "Unable to fetch readings: Status code ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Gets glucose readings using minutes and maxCount.
  ///
  /// The latest reading is the first
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
        rethrow;
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
  Future<DexcomVerificationResult> verify() async {
    _init();
    try {
      await _createSession();
      return DexcomVerificationResult(true);
    } catch (e) {
      _log("$e", function: "verify");
      return DexcomVerificationResult(false);
    }
  }

  /*/// Verifies that the user has the correct username and password by creating a session and optionally getting the data to confirm that the user used valid credentials.
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
  }*/

  // Takes care of variables and pre-flight checks
  void _init() {
    if (username == null) {
      throw DexcomInitializationError("Username cannot be null.");
    }

    if (password == null) {
      throw DexcomInitializationError("Password cannot be null.");
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
  final int buffer;

  // Controller of the Dexcom reading stream.
  StreamController<List>? _controller;

  /// Debug mode (default is set to object's setting).
  bool get debug => _debug ?? object.debug;

  // Contains debug mode.
  bool? _debug;

  /// How many pieces of data should be sent with each new incoming data. This is recommended to be a low number.
  final int maxCount;

  /// Timer for the listener.
  int get time => _time ?? 0;

  // Timer for the listener.
  int? _time;

  // To track if someone is already listening.
  bool _isListening = false;

  // To trigger a refresh;
  bool _refresh = false;

  // Last time the timer ticked.
  DateTime _lastTick = DateTime.now();

  // Previous tick time to compare with the current tick.
  DateTime _previousTick = DateTime.now();

  // Called when a refresh is triggered.
  void Function()? _onRefresh;

  // Last time a refresh started. This is used for detecting how long a refresh took.
  DateTime _lastRefreshStart = DateTime.now();

  /// Requires an object (which is a Dexcom object) for listening to.
  DexcomStreamProvider(this.object,
      {this.buffer = 0, this.maxCount = 2, bool? debug}) {
    if (buffer < 0) {
      throw DexcomInitializationError("Buffer cannot be negative.");
    }
    if (maxCount < 1) {
      throw DexcomInitializationError("Max count cannot be less than 1.");
    }

    _debug = debug;
  }

  /// Converts the current DexcomStreamProvider object to a string.
  @override
  String toString() {
    return "DexcomStreamProvider(object: $object, buffer: $buffer, maxCount: $maxCount, debug: $debug)";
  }

  /// Refresh the listener.
  void refresh() {
    _log("Refreshing...", function: "provider.refresh");
    _refresh = true;
    _lastRefreshStart = DateTime.now();
    if (_onRefresh != null) _onRefresh!();
  }

  void _onTickDebug() {
    DateFormat format = DateFormat('HH:mm:ss.SSS');
    _log(
        "Tick: ${format.format(DateTime.now())} (last tick: ${format.format(_lastTick)}) (previous last tick: ${format.format(_previousTick)})",
        function: "provider._onTickDebug");
  }

  /// Start listening to incoming Dexcom readings.
  /// Make sure to call [close] when done listening to free up resources.
  ///
  /// [onData] outputs data with the latest reading being the first.
  ///
  /// [onError] outputs any errors that occur.
  ///
  /// [onTimerChange] outputs the current time since the last reading (in seconds). Note that this may not be accurate, and can vary/freeze if the app goes to sleep or multiple refreshes are triggered.
  ///
  /// [onRefresh] outputs when a refresh is triggered.
  ///
  /// [onRefreshEnd] outputs when a refresh ends. This can be used to calculate how long a refresh took. [onRefreshEnd] outputs the seconds taken as a [Duration].
  void listen(
      {void Function(List<DexcomReading> data)? onData,
      void Function(Object error)? onError,
      void Function(int time)? onTimerChange,
      void Function()? onRefresh,
      void Function(Duration timeTaken)? onRefreshEnd,
      bool cancelOnError = false}) async {
    if (_isListening == true) {
      throw DexcomInitializationError(
          "This stream is already being listened to.");
    } else {
      _isListening = true;
    }

    _init();
    _onRefresh = onRefresh;
    bool _isProcessing = false;
    _controller = StreamController<List>();
    _time = null;

    Timer.periodic(Duration(seconds: 1), (Timer timer) async {
      _previousTick = _lastTick;
      if (DateTime.now().difference(_lastTick).inSeconds > 10) refresh();
      _lastTick = DateTime.now();

      if (_controller!.isClosed) {
        timer.cancel();
        return;
      }

      if (_isProcessing == false) {
        if (_refresh ||
            _time == null ||
            ((_time ?? 0) >= (_interval + buffer))) {
          _refresh = false;
          _isProcessing = true;
          _time ??= 0;

          try {
            _log("Getting glucose data", function: "listen.Timer");
            List<DexcomReading> data =
                (await object.getGlucoseReadings(maxCount: maxCount))!;
            if (data.isNotEmpty)
              _time =
                  DateTime.now().difference(data.first.displayTime).inSeconds;

            if (_time! >= _interval) {
              _time = 0;
            }

            _controller!.add(data);
            if (onData != null) onData(data);
          } catch (e) {
            _controller!.addError(e);
            if (onError != null) onError(e);
            _log("DexcomStreamProvider listen error: $e",
                function: "listen.Timer");

            if (cancelOnError) {
              rethrow;
            }
          } finally {
            _isProcessing = false;
            if (onRefreshEnd != null)
              onRefreshEnd(DateTime.now().difference(_lastRefreshStart));
          }
        }
      }

      _onTickDebug();
      _time = (_time == null ? 0 : _time! + 1);
      if (onTimerChange != null) onTimerChange(_time!);
    });
  }

  /// Close the stream listening to the Dexcom readings.
  void close() {
    if (_isListening == false) {
      print("The stream is already closed.");
    }

    _init();
    _time = null;
    _controller!.close();
    _isListening = false;
  }

  // Custom logging solution
  void _log(String message, {required String function}) {
    _init();
    if (_debug!) print("dexcom.provider: $function: $message");
  }

  // Initialize variables and checks
  void _init() {}

  /// Stream that can be listened to for new Dexcom readings.
  Stream<List>? get stream => _controller?.stream;
}

/// Identifiers for Dexcom regions. This is used in both the Share API and the Web API.
enum DexcomRegion {
  /// US
  us,

  /// Out of US
  ous,

  /// Japan
  jp,
}

/// Provides extra functions for a DexcomTrend.
extension DexcomTrendExtension on DexcomTrend {
  /// Convert a DexcomTrend to a string.
  String convert([DexcomTrend? trend]) {
    trend ??= this;
    switch (trend) {
      case DexcomTrend.flat:
        return "Flat";
      case DexcomTrend.fortyFiveDown:
        return "FortyFiveDown";
      case DexcomTrend.fortyFiveUp:
        return "FortyFiveUp";
      case DexcomTrend.singleDown:
        return "SingleDown";
      case DexcomTrend.singleUp:
        return "SingleUp";
      case DexcomTrend.doubleDown:
        return "DoubleDown";
      case DexcomTrend.doubleUp:
        return "DoubleUp";
      case DexcomTrend.nonComputable:
        return "NonComputable";
      case DexcomTrend.none:
        return "None";
    }
  }
}

/// The trend of a Dexcom reading.
enum DexcomTrend {
  /// Steady
  flat,

  /// Slowly falling (-1/minute)
  fortyFiveDown,

  /// Slowly rising (+1/minute)
  fortyFiveUp,

  /// Falling (-2/minute)
  singleDown,

  /// Rising (+2/minute)
  singleUp,

  /// Quickly falling (-3/minute)
  doubleDown,

  /// Quickly rising (+3/minute)
  doubleUp,

  /// No trend
  none,

  /// The graph is too wonky for Dexcom to know which way the glucose levels are going.
  /// You can try to compute it yourself if you want to.
  nonComputable,
}

/// An individual Dexcom CGM reading.
class DexcomReading {
  /// systemTime is the UTC time according to the device.
  final DateTime systemTime;

  /// displayTime is the time being shown on the device to the user.
  /// Depending on the device, this time may be user-configurable, and can therefore change its offset relative to systemTime.
  /// Note that systemTime is not "true" UTC time because of drift and/or user manipulation of the devices' clock.
  final DateTime displayTime;

  /// Blood glucose level. This is always mg/dL.
  final int value;

  /// Trend of the current glucose.
  final DexcomTrend trend;

  /// All options are required.
  DexcomReading(
      {required this.systemTime,
      required this.displayTime,
      required this.value,
      required this.trend});

  /// Convert the reading to JSON.
  Map toJson() {
    return {
      "ST": systemTime,
      "DT": displayTime,
      "Value": value,
      "Trend": trend.convert(),
    };
  }

  /// Convert the reading to a string.
  @override
  String toString() {
    return "DexcomReading(systemTime: $systemTime, displayTime: $displayTime, value: $value, trend: ${trend.convert()})";
  }
}
