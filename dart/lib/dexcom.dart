import 'dart:convert'; // Convert JSON into URL body

import 'package:http/http.dart'
    as http; // Fetch account ID, session ID, and user data
import 'package:intl/intl.dart'; // Get region

/// Gets the current region of the user
String getRegion() {
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

/// Lists all the application IDs, base URLs, and endpoints for the requests
Map dexcomVar = {
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
    "session": "General/LoginPublisherAccountById",
    "account": "General/AuthenticatePublisherAccount",
    "data": "Publisher/ReadPublisherLatestGlucoseValues"
  }
};

/// Main class that controls all of the functions
class Dexcom {
  /// Gets the region of the user using getRegion()
  final String region = getRegion();
  final String _username;
  final String _password;
  String? _accountId;
  String? _sessionId;
  final String _applicationId = dexcomVar["appId"][getRegion()];

  /// Makes a Dexcom with the username and password
  Dexcom(this._username, this._password);

  /// Removes quotes from the uuids
  String formatUuid(String uuid) {
    return uuid.replaceAll('"', '');
  }

  Future<String> _getAccountId() async {
    try {
      if (!dexcomVar["baseUrl"].containsKey(region)) {
        throw Exception('Invalid region: $region');
      }

      final url = Uri.parse(
          "${dexcomVar["baseUrl"][region]}/${dexcomVar["endpoint"]["account"]}");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountName': _username,
          'password': _password,
          'applicationId': dexcomVar["appId"][region],
        }),
      );

      if (response.statusCode == 200) {
        return formatUuid(response.body);
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
          "${dexcomVar["baseUrl"][region]}/${dexcomVar["endpoint"]["session"]}");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountId': _accountId,
          'password': _password,
          'applicationId': _applicationId,
        }),
      );
      if (response.statusCode == 200) {
        String responseS = formatUuid(response.body);
        return responseS;
      } else {
        throw Exception(
            'Failed to authenticate: Could not retrieve Session ID: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Creates a session by getting the accountId, then passing that into _getSessionId(), which will create a new session
  Future<void> createSession() async {
    try {
      _accountId ??= await _getAccountId();
      if (_accountId != null) {
        _sessionId ??= await _getSessionId();
      }
    } catch (e) {
      throw Exception("Unable to create session: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _getGlucoseReadings({
    int minutes = 60,
    int maxCount = 100,
  }) async {
    Map status = await _runSystemChecks();
    if (status["status"]) {
      try {
        final url = Uri.parse(
            "${dexcomVar["baseUrl"][region]}/${dexcomVar["endpoint"]["data"]}");
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
          return List<Map<String, dynamic>>.from(jsonDecode(response.body));
        } else {
          throw Exception("Unable to fetch readings");
        }
      } catch (e) {
        rethrow;
      }
    } else {
      throw Exception(status["error"]);
    }
  }

  /// Gets glucose readings using minutes and maxCount
  Future<List<Map<String, dynamic>>> getGlucoseReadings(
      {int minutes = 60,
      int maxCount = 100,
      bool allowRetrySession = true}) async {
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
      await createSession();
      final readings =
          await getGlucoseReadings(minutes: minutes, maxCount: maxCount);
      return readings;
    } else {
      return [
        {"success": false, "error": "readings"}
      ];
    }
  }

  /// Verifies that the user has the correct username and password by creating a session and optionally getting the data to confirm that the user is valid
  Future<Map<String, dynamic>> verifyLogin(String username, String password,
      {bool getReadings = true}) async {
    try {
      await createSession();
      if (getReadings) {
        try {
          await getGlucoseReadings(
              minutes: 7200, maxCount: 1, allowRetrySession: false);
          return {"success": true, "error": "none"};
        } catch (e) {
          return {"success": false, "error": "session"};
        }
      } else {
        return {"success": true, "error": "none"};
      }
    } catch (e) {
      return {"success": false, "error": "readings"};
    }
  }

  Future<Map<String, dynamic>> _runSystemChecks() async {
    try {
      await http.get(Uri.parse('https://www.google.com/'));
      return {"status": true};
    } catch (e) {
      return {"status": false, "error": "No Internet"};
    }
  }
}
