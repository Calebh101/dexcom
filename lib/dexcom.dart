/// Library that uses the Dexcom Share API.
library dexcom;

import 'dart:async'; // Manages timers and streams
import 'dart:convert'; // Convert JSON into URL body

import 'package:http/http.dart'
    as http; // Fetch account ID, session ID, and user data
import 'package:intl/intl.dart'; // Get region, and date formatting

// The last time we got an HTTP response of 429.
DateTime? _tooManyRequestsReceived;

// This is ran when this package logs. This is only used in debug mode.
//
// Set this with [Dexcom.setLoggerCallback].
void Function(String) _loggerCallback = print;

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

// Get a time from a reading's ST/DT/WT.
DateTime? _getReadingTime(String time) {
  try {
    DateTime? parseOutput = DateTime.tryParse(time);
    if (parseOutput != null) return parseOutput;

    // The API returns the date in a different format.
    return DateTime.fromMillisecondsSinceEpoch(int.parse(
        (RegExp(r"Date\((.*)\)").firstMatch(time)!.group(1)!).split('-')[0]));
  } catch (e) {
    print("Unable to get reading time: $e");
    return null;
  }
}

// Debug function
void __log(String _class, String function, String input) {
  _loggerCallback.call("[${DateTime.now().toUtc()}] [dexcom.$_class] [$function] $input");
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
  ///
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

  /// Return a `Map<String, String?>` of this object.
  Map<String, String?> toJson() {
    return {
      "us": us,
      "ous": ous,
      "jp": jp,
    };
  }

  @override
  String toString() {
    return "DexcomAppIds(us: ${us != null}, ous: ${ous != null}, jp: ${jp != null})";
  }
}

/// An object representing a web request made to Dexcom's servers for glucose data retrieval.
class DexcomGlucoseRequest {
  /// The method of the request, like `GET`, `POST`, etcetera.
  final String method;

  /// The actual URL of the request.
  final Uri url;

  /// The optional body of the request.
  final Map<String, dynamic>? body;

  /// The headers of the request.
  final Map<String, String> headers;

  /// Whether we should be verbose about the output.
  final bool verbose;

  /// An object representing a web request made to Dexcom's servers for glucose data retrieval.
  ///
  /// All parameters are required.
  const DexcomGlucoseRequest({
    required this.method,
    required this.url,
    required this.body,
    required this.headers,
    this.verbose = false,
  });

  @override
  String toString() {
    return "DexcomGlucoseRequest(url: $url, body: ${body != null ? (verbose ? jsonEncode(body) : "${jsonEncode(body).length} characters") : "null"} characters, headers: ${verbose ? jsonEncode(headers) : "${jsonEncode(headers).length} characters"}${verbose ? ", CURL request: ${toCurl()}" : ""})";
  }

  /// Turn this [DexcomGlucoseRequest] into an executable CURL command.
  String toCurl() {
    String escape(String input) {
      return input.replaceAll("'", r"'\''");
    }

    return "curl -X ${method.toUpperCase()} ${url} ${List.generate(headers.length, (i) {
      final h = headers.entries.elementAt(i);
      return "-H '${escape(h.key)}: ${escape(h.value)}'";
    }).join(" ")} ${body != null ? "-d '${escape(jsonEncode(body))}'" : ""}"
        .trim();
  }
}

/// Used when verifying a user's credentials.
class DexcomVerificationResult {
  /// If true, then user verified. If false, then not verified.
  final bool status;

  /// The potential error returned from the result.
  final Object? error;

  /// Status is required.
  const DexcomVerificationResult(this.status, [this.error]);

  @override
  String toString() {
    return "DexcomVerificationResult(status: $status)";
  }

  /// Turn this object into a `Map<String, Object?>`, containing [status] and [error].
  Map<String, Object?> toJson() {
    return {
      "status": status,
      "error": error,
    };
  }
}

/// Thrown when an error occurs during Dexcom account authentication.
class DexcomAuthorizationException implements Exception {
  /// Message of the exception.
  final String? message;

  /// Thrown when an error occurs during Dexcom account authentication.
  DexcomAuthorizationException(this.message);

  /// Converts the exception to a string.
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

  /// Status code of the exception. This will be either HTTP status code, or `-1` if it's not related to HTTP.
  final int code;

  /// The [DexcomGlucoseRequest] object that represents the request made to Dexcom.
  final DexcomGlucoseRequest request;

  /// Thrown when an error occurs during Dexcom glucose retrieval.
  DexcomGlucoseRetrievalException(this.message, this.code, this.request);

  /// Converts the exception to a string.
  @override
  String toString() {
    return [
      "DexcomGlucoseRetrievalException",
      if (message != null) ": $message, request: ${request}",
      " (code: $code)",
    ].join("");
  }
}

/// Thrown when an error occurs intializing a [Dexcom] or a [DexcomStreamProvider].
class DexcomInitializationError implements Error {
  /// Message of the error.
  final String? message;

  /// Stack trace of the error.
  @override
  final StackTrace stackTrace;

  /// Thrown when an error occurs intializing a [Dexcom] or a [DexcomStreamProvider].
  DexcomInitializationError(this.message)
      : this.stackTrace = StackTrace.current;

  /// Converts the error to a string.
  @override
  String toString() {
    return ["DexcomInitializationError", if (message != null) message]
        .join(": ");
  }
}

/// Main class that controls all of the functions.
///
/// `onStatusUpdate` is called when something happens. It's called when we start fetching the account ID, when we finish fetching the account ID, we start fetching the session ID, when we finish fetching the session ID, we start fetching glucose readings, and when we finish fetching glucose readings. `status` represents the operation being referenced, and `finished` is false when the operation starts, and true when the operation ends. (Note that this means`onStatusUpdate` is called again when the operation finishes.)
///
/// `onAccountIdUpdate` is called *only* when a new account ID is received, or the account ID is reset. The account ID is never reset automatically. `onAccountIdUpdate` is also not called when this object is initialized.
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

  /// Account ID for the account using username and password.
  ///
  /// If this is uninitialized, it will be fetched.
  String? accountId;

  // Session ID for the session, using account ID and password.
  String? _sessionId;

  /// Debug mode (shows extra logging).
  final bool debug;

  /// Default amount of minutes fetched (from now).
  final int minutes;

  /// Default maximum amount of glucose readings that can be fetched.
  final int maxCount;

  /// The unit used for reading values.
  final DexcomGlucoseUnit unit;

  // Called when the status updates, like we start fetching the account ID.
  final void Function(DexcomUpdateStatus status, bool finished) _onStatusUpdate;

  // Called when an account ID is received.
  final void Function(String? id) _onAccountIdUpdate;

  /// Makes a Dexcom with the username, password, and region (optional).
  ///
  /// [onStatusUpdate] is called when something happens. It's called when we start fetching the account ID, when we finish fetching the account ID, we start fetching the session ID, when we finish fetching the session ID, we start fetching glucose readings, and when we finish fetching glucose readings. `status` represents the operation being referenced, and `finished` is false when the operation starts, and true when the operation ends. (Note that this means [onStatusUpdate] is called again when the operation finishes.)
  ///
  /// [onAccountIdUpdate] is called *only* when a new account ID is received, or the account ID is reset. The account ID is never reset automatically. [onAccountIdUpdate] is also not called when this object is initialized.
  Dexcom(
      {this.username,
      this.password,
      this.debug = false,
      this.minutes = 60,
      this.maxCount = 12,
      this.accountId = null,
      this.unit = DexcomGlucoseUnit.mgdL,
      DexcomRegion? region,
      DexcomAppIds? appIds,
      void Function(DexcomUpdateStatus status, bool finished)? onStatusUpdate,
      void Function(String? id)? onAccountIdUpdate})
      : _onStatusUpdate =
            onStatusUpdate ?? ((DexcomUpdateStatus status, bool finished) {}),
        _onAccountIdUpdate = onAccountIdUpdate ?? ((String? id) {}) {
    if (maxCount < 1) {
      throw DexcomInitializationError("Max count cannot be less than 1.");
    }

    _region = region;
    _appIds = appIds;
  }

  /// Converts the current Dexcom object to a string.
  /// Does not show the password of the object by default.
  @override
  String toString({bool showPassword = false}) {
    _init();
    return "Dexcom(username: ${username ?? "null"}, password: ${password != null ? (showPassword ? password : ("*" * password!.length)) : "null"}, region: $region, debug: $debug)";
  }

  /// Set the logging function used for debug logs.
  ///
  /// This defaults to [print].
  static void setLoggerCallback(void Function(String) callback) {
    _loggerCallback = callback;
  }

  // Removes quotes from the uuids.
  static String _formatUuid(String uuid) {
    return uuid.replaceAll('"', '');
  }

  static DexcomTrend _getTrend(String trend) {
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

  /// Set [accountId] to null.
  ///
  /// Note that this does call `onAccountIdUpdate`.
  void resetAccountId() {
    accountId = null;
    _onAccountIdUpdate(null);
  }

  void _updateStatus(DexcomUpdateStatus status, bool finished) {
    _log("Status update: $status (${status.pretty}) (finished: $finished)",
        function: "_updateStatus");
    _onStatusUpdate.call(status, finished);
  }

  // Processes each reading and turns them into [DexcomReading]s.
  List<DexcomReading> _process(List<Map<String, dynamic>> data) {
    List<DexcomReading> items = [];

    data.forEach((item) {
      try {
        DexcomReading reading = DexcomReading.fromJson(item);
        items.add(reading);
      } catch (e) {
        _log("Invalid reading: $e", function: "_process");
      }
    });

    return items;
  }

  Future<String> _getAccountId() async {
    _init();
    _updateStatus(DexcomUpdateStatus.fetchingAccountId, false);

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
        _updateStatus(DexcomUpdateStatus.fetchingAccountId, true);
        String result = _formatUuid(response.body);
        _onAccountIdUpdate(result);
        return result;
      } else {
        throw DexcomAuthorizationException('Could not retrieve Account ID');
      }
    } catch (e) {
      _updateStatus(DexcomUpdateStatus.fetchingAccountId, true);
      rethrow;
    }
  }

  Future<String> _getSessionId() async {
    _init();
    _updateStatus(DexcomUpdateStatus.fetchingSessionId, false);

    try {
      final url = Uri.parse(
          "${_getBaseUrl(region)}/${_dexcomData["endpoint"]["session"]}");
      _log("Fetching session ID from $url", function: "_getSessionId");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountId': accountId,
          'password': password,
          'applicationId': appIds.get(code: region),
        }),
      );
      if (response.statusCode == 200) {
        String responseS = _formatUuid(response.body);
        _updateStatus(DexcomUpdateStatus.fetchingSessionId, true);
        return responseS;
      } else {
        throw DexcomAuthorizationException('Could not retrieve Session ID');
      }
    } catch (e) {
      _updateStatus(DexcomUpdateStatus.fetchingSessionId, true);
      rethrow;
    }
  }

  // Creates a session by getting the accountId, then passing that into _getSessionId(), which will create a new session ready to be used
  Future<void> _createSession() async {
    _init();
    try {
      accountId ??= await _getAccountId();
      _log("Retrieved account ID", function: "_createSession");
      if (accountId != null) {
        _sessionId = await _getSessionId();
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
    _init();
    _updateStatus(DexcomUpdateStatus.fetchingGlucose, false);

    minutes ??= this.minutes;
    maxCount ??= this.maxCount;

    final url =
        Uri.parse("${_getBaseUrl(region)}/${_dexcomData["endpoint"]["data"]}");
    final request = DexcomGlucoseRequest(
        method: "POST",
        url: url,
        body: {
          'sessionId': _sessionId,
          'minutes': minutes,
          'maxCount': maxCount,
        },
        headers: {
          'Content-Type': 'application/json',
        },
        verbose: debug);

    _log("Fetching glucose readings from $url: $request",
        function: "_getGlucoseReadings");

    try {
      final response = await http.post(
        url,
        headers: request.headers,
        body: jsonEncode(request.body),
      );

      if (response.statusCode == 200) {
        _updateStatus(DexcomUpdateStatus.fetchingGlucose, true);
        return _process(
            List<Map<String, dynamic>>.from(jsonDecode(response.body)));
      } else {
        if (response.statusCode == 429) {
          _log("Got signal for too many requests, delaying by 15 seconds.",
              function: "_getGlucoseReadings");
          _tooManyRequestsReceived = DateTime.now();
        }

        throw DexcomGlucoseRetrievalException(
            "Unable to fetch readings: Status code ${response.statusCode}, body: ${() {
              try {
                return jsonEncode(response.body);
              } catch (_) {
                return response.body;
              }
            }()}",
            response.statusCode,
            request);
      }
    } catch (e) {
      _updateStatus(DexcomUpdateStatus.fetchingGlucose, true);

      if (e is DexcomGlucoseRetrievalException) {
        rethrow;
      } else {
        throw DexcomGlucoseRetrievalException("Unknown error: $e", -1, request);
      }
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
    DexcomGlucoseRetrievalException? e;

    if (_sessionId != null) {
      try {
        final readings =
            await _getGlucoseReadings(minutes: minutes, maxCount: maxCount);
        return readings;
      } catch (_e) {
        if (_e is DexcomGlucoseRetrievalException) {
          e = _e;
        }
      }
    }

    if (allowRetrySession && e?.code != -1 && e?.code != 429) {
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
    _updateStatus(DexcomUpdateStatus.verifying, false);

    try {
      await _createSession();
      _updateStatus(DexcomUpdateStatus.verifying, true);
      return DexcomVerificationResult(true);
    } catch (e) {
      _log("Error verifying:$e", function: "verify");
      _updateStatus(DexcomUpdateStatus.verifying, true);
      return DexcomVerificationResult(false, e);
    }
  }

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
      __log("Dexcom", function, message);
    }
  }
}

/// Class that provides a stream that you can listen to. This will automatically fetch new readings when the old readings have hit the interval (defaults to 300 seconds).
class DexcomStreamProvider {
  /// The Dexcom object that is listened to.
  final Dexcom object;

  /// Interval (in seconds) that the listener will automatically fetch new readings when the interval is hit. This should not be changed.
  int _interval = 300;

  /// Buffer that is added onto interval to give the client's Dexcom time to upload readings. This can help prevent skipping over a reading.
  ///
  /// Only seconds is used here; milliseconds won't count.
  final Duration buffer;

  // Controller of the Dexcom reading stream.
  StreamController<List>? _controller;

  /// Debug mode (default is set to object's setting).
  bool get debug => _debug ?? object.debug;

  // Contains debug mode.
  bool? _debug;

  /// How many pieces of data should be sent with each new incoming data. This is recommended to be a low number.
  final int maxCount;

  /// How long at least we should wait in between refresh attempts. This is measured in milliseconds.
  ///
  /// This is used to avoid getting rate limited by Dexcom.
  final int minimumRefreshInterval = 5000;

  /// How long we should wait before requesting again if we get rate-limited. This is measured in milliseconds.
  final int toWaitOnTooManyRequestsReceived = 35000;

  /// Timer for the listener.
  ///
  /// You can set this to an updated time if you want.
  int get time => _time ?? 0;

  set time(int value) {
    _time = value;
  }

  // Timer for the listener.
  int? _time;

  // To track if someone is already listening.
  bool _isListening = false;

  // To trigger a refresh.
  bool _refresh = false;

  // To pause the listener(s).
  bool _paused = false;

  /// To pause the listener(s).
  bool get paused => _paused;

  // Last time the timer ticked.
  DateTime _lastTick = DateTime.now();

  // Previous tick time to compare with the current tick.
  DateTime _previousTick = DateTime.now();

  // The time of the last reading.
  DateTime? _lastReadingTime;

  // The time of the last refresh. This is used differently than [_lastRefreshStart].
  DateTime? _lastRefresh;

  // If we've passed [_lastRefresh].
  bool _pastMinimumRefreshInterval = true;

  // Called when a refresh is triggered.
  void Function()? _onRefresh;

  // Last time a refresh started. This is used for detecting how long a refresh took.
  DateTime _lastRefreshStart = DateTime.now();

  /// Requires an object (which is a Dexcom object) for listening to.
  DexcomStreamProvider(this.object,
      {this.buffer = const Duration(seconds: 10),
      this.maxCount = 2,
      bool? debug}) {
    if (buffer.inSeconds < 0) {
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
    return "DexcomStreamProvider(object: $object, buffer: ${buffer.inSeconds} seconds, maxCount: $maxCount, debug: $debug)";
  }

  // Internally trigger the listener to fetch new data.
  void _startRefresh(bool auto) {
    _setPastMinimumRefreshInterval();
    if (auto && !_pastMinimumRefreshInterval) return;
    _log("Refreshing...", function: "DexcomStreamProvider.refresh");
    _refresh = true;
    _lastRefreshStart = DateTime.now();
    if (_onRefresh != null) _onRefresh!();
  }

  /// Trigger the listener to fetch new data.
  void refresh() {
    _startRefresh(false);
  }

  /// Pause all listeners.
  /// The timers will still be active; call [close] to stop them.
  void pause() {
    _log("Pausing listeners", function: "pause");
    _paused = true;
  }

  /// Unpause all listeners.
  void unpause() {
    _log("Unpausing listeners", function: "unpause");
    _paused = false;
  }

  void _onTickDebug() {
    DateFormat format = DateFormat('HH:mm:ss.SSS');
    _log(
        "Tick: ${format.format(DateTime.now())} (last tick: ${format.format(_lastTick)}) (previous last tick: ${format.format(_previousTick)})",
        function: "DexcomStreamProvider._onTickDebug");
  }

  // Updates [_pastMinimumRefreshInterval].
  //
  // First, we check if we've gotten a 429 too many requests recently. Then, we check if it's been a while since our last reading, and we've recently refreshed (last 3 minutes). Then, we check if we refreshed in just the last [minimumRefreshInterval] milliseconds.
  void _setPastMinimumRefreshInterval() {
    if (_tooManyRequestsReceived != null &&
        // If we've recently gotten hit with 429
        DateTime.now().difference(_tooManyRequestsReceived!).inMilliseconds <
            toWaitOnTooManyRequestsReceived) {
      _pastMinimumRefreshInterval = false;
    } else {
      _pastMinimumRefreshInterval = _lastRefresh != null
          ? (_lastReadingTime != null &&
                  DateTime.now().difference(_lastReadingTime!).inSeconds > 420
              // If it's been a while since our last reading, we shouldn't constantly refresh anymore
              ? DateTime.now().difference(_lastRefresh!).inSeconds > 180
              // If we've already recently refreshed
              : DateTime.now().difference(_lastRefresh!).inMilliseconds >=
                  minimumRefreshInterval)
          : true;
    }
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
      if (_paused) {
        return;
      }

      if (_controller!.isClosed) {
        timer.cancel();
        return;
      }

      _previousTick = _lastTick;
      if (!_isProcessing) {
        if (DateTime.now().difference(_lastTick).inSeconds > 10) {
          _startRefresh(true); // If old readings
        } else if ((_time ?? 0) >= (_interval + buffer.inSeconds)) {
          _startRefresh(
              true); // If we've waited longer than _interval and buffer
        }
      }
      _lastTick = DateTime.now();

      _setPastMinimumRefreshInterval();

      if (!_isProcessing &&
          (_lastRefresh == null || _pastMinimumRefreshInterval) &&
          (_refresh ||
              (_time == null) ||
              (_time! >= (_interval + buffer.inSeconds)))) {
        _lastRefresh = DateTime.now();
        _refresh = false;
        _isProcessing = true;
        _time ??= 0;

        // Make it run in the background
        (() async {
          try {
            _log("Getting glucose data",
                function: "DexcomStreamProvider.listen.Timer");
            List<DexcomReading> data =
                (await object.getGlucoseReadings(maxCount: maxCount))!;

            if (data.isNotEmpty) {
              final newReadingTime = data.first.displayTime;

              if (_lastReadingTime == null ||
                  newReadingTime.isAfter(_lastReadingTime!)) {
                _lastReadingTime = newReadingTime;
                _time = DateTime.now().difference(newReadingTime).inSeconds;
              }
            }

            _controller!.add(data);
            if (onData != null) onData(data);
          } catch (e) {
            _controller!.addError(e);
            if (onError != null) onError(e);
            _log("DexcomStreamProvider listen error: $e",
                function: "DexcomStreamProvider.listen.Timer");

            if (cancelOnError) {
              rethrow;
            }
          } finally {
            _isProcessing = false;
            if (onRefreshEnd != null) {
              onRefreshEnd(DateTime.now().difference(_lastRefreshStart));
            }
          }
        })();
      }

      _onTickDebug();
      if (_lastReadingTime != null) {
        _time = DateTime.now().difference(_lastReadingTime!).inSeconds;
      }
      if (_lastReadingTime != null && onTimerChange != null) {
        onTimerChange(_time!);
      }
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

    if (_debug ?? false) {
      __log("DexcomStreamProvider", function, message);
    }
  }

  // Initialize variables and checks
  void _init() {}

  /// Stream that can be listened to for new Dexcom readings.
  Stream<List>? get stream => _controller?.stream;
}

/// Identifiers for regions that Dexcom uses. This is used in both the Share API and the Web API.
enum DexcomRegion {
  /// US
  us,

  /// Out of US
  ous,

  /// Japan
  jp,
}

/// The unit used for reading calculation.
enum DexcomGlucoseUnit {
  /// Milligrams per deciliter.
  mgdL,

  /// Millimoles.
  mmolL,
}

/// The status of the current Dexcom object.
enum DexcomUpdateStatus {
  /// Fetching the account ID.
  fetchingAccountId("Fetching account ID"),

  /// Fetching a new session ID.
  fetchingSessionId("Fetching session ID"),

  /// Fetching glucose readings.
  fetchingGlucose("Fetching glucose readings"),

  /// Verifying account with credentials.
  verifying("Verifying account");

  /// A pretty name for the enum.
  final String pretty;

  const DexcomUpdateStatus(this.pretty);
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

/// Provides extra functions for a DexcomTrend.
extension DexcomTrendExtension on DexcomTrend {
  /// Convert a DexcomTrend to a string.
  String stringify() {
    switch (this) {
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

  /// Convert a DexcomTrend to a string.
  ///
  /// [trend] is no longer used.
  @Deprecated("Use stringify instead.")
  String convert([DexcomTrend? trend]) {
    return stringify();
  }
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
  final num mgdL;

  /// The glucose value in your chosen [DexcomGlucoseUnit] unit.
  final num value;

  /// Trend of the current glucose.
  final DexcomTrend trend;

  /// An individual Dexcom CGM reading.
  ///
  /// [mgdL] is the raw value in mg/dL, and [value] is the value based on [unit].
  DexcomReading(
      {required this.systemTime,
      required this.displayTime,
      required this.mgdL,
      required this.trend,
      required DexcomGlucoseUnit unit}) : value = _convert(unit, mgdL);

  /// Get a [DexcomReading] from a `Map<String, dynamic>`.
  factory DexcomReading.fromJson(Map<String, dynamic> input) {
    return DexcomReading(
        systemTime: _getReadingTime(input["ST"])!,
        displayTime: _getReadingTime(input["DT"])!,
        mgdL: input["Value"],
        trend: Dexcom._getTrend(input["Trend"]),
        unit: DexcomGlucoseUnit.mgdL);
  }

  /// Convert the reading to JSON.
  Map<String, dynamic> toJson() {
    return {
      "ST": systemTime.toIso8601String(),
      "DT": displayTime.toIso8601String(),
      "Value": mgdL,
      "Trend": trend.stringify(),
    };
  }

  /// Convert the reading to a string.
  @override
  String toString() {
    return "DexcomReading(systemTime: $systemTime, displayTime: $displayTime, mg/dL: $mgdL, trend: ${trend.stringify()})";
  }

  static num _convert(DexcomGlucoseUnit unit, num mgdL) {
    switch (unit) {
      case DexcomGlucoseUnit.mgdL: return mgdL;
      case DexcomGlucoseUnit.mmolL: return mgdL * 0.0555;
    }
  }
}
