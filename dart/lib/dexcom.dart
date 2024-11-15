import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

String getRegion() {
  String region = "us";
  String locale = Platform.localeName;
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

class Dexcom {
  final String region = getRegion();
  final String _username;
  final String _password;
  String? _accountId;
  String? _sessionId;
  final String _applicationId = dexcomVar["appId"][getRegion()];

  Dexcom(this._username, this._password);

  String formatUuid(String uuid) {
    return uuid.replaceAll('"', '');
  }

  Future<String> _getAccountId() async {
    try {
      if (!dexcomVar["baseUrl"].containsKey(region)) {
        throw Exception('Invalid region: $region');
      }

      final url = Uri.parse("${dexcomVar["baseUrl"][region]}/${dexcomVar["endpoint"]["account"]}");
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
        String responseS = formatUuid(response.body);
        try {
          Uuid.parse(responseS);
          return responseS;
        } catch (e) {
          throw Exception('Account ID format is invalid. $responseS');
        }
      } else {
        throw Exception('Failed to authenticate: Could not retrieve Account ID');
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
        throw Exception('Failed to authenticate: Could not retrieve Session ID');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createSession() async {
    _accountId ??= await _getAccountId();
    if (_accountId != null) {
      _sessionId ??= await _getSessionId();
    }
  }

  Future<List<Map<String, dynamic>>> _getGlucoseReadings({
    int minutes = 60,
    int maxCount = 100,
  }) async {
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
        throw Exception('Failed to fetch glucose readings: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getGlucoseReadings({
    int minutes = 60,
    int maxCount = 100,
    bool allowRetrySession = true
  }) async {
    if (_sessionId != null) {
      try {
        final readings = await _getGlucoseReadings(minutes: minutes, maxCount: maxCount);
        return readings;
      } catch (e) {
        throw Exception('Failed to fetch glucose readings: $e');
      }
    }

    if (allowRetrySession) { 
      await createSession();
      final readings = await getGlucoseReadings(minutes: minutes, maxCount: maxCount);
      return readings;
    } else {
      return [{"success": false, "error": "readings"}];
    }
  }

  Future<Map<String, dynamic>> verifyLogin(
    String username,
    String password,
    {bool getReadings = true}
  ) async {
    try {
      await createSession();
      if (getReadings) {
        try {
          await getGlucoseReadings(minutes: 7200, maxCount: 1, allowRetrySession: false);
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
}