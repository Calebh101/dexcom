/// Library that uses the Dexcom Web API.
/// The Dexcom Share API fetches real-time blood glucose values, while the Dexcom Web API fetches retrospective data.
/// 
/// The Dexcom Web API can fetch more than just blood glucose, it can also fetch calibration data, sensor data, data in a specific time range, and more.
library web;

import 'dart:convert';

import 'package:dexcom/_api/all.dart';
import 'package:dexcom/_api/private.dart';
import 'package:http/http.dart' as http;

export '_api/main.dart';

/// Object for a DexcomWeb object.
class DexcomWeb {
  /// DexcomUser object that defines the client using your package.
  final DexcomUser user;

  /// Application credentials.
  final DexcomApplication application;

  /// Region of the user.
  DexcomRegion? region;

  /// Access and refresh tokens.
  DexcomTokens? tokens;

  bool _sandbox = false;

  /// Application is required.
  DexcomWeb({required this.user, required this.application, this.region}) {
    region ??= getRegion();
    _sandbox = user.sandbox;
  }

  /// Converts the current DexcomWeb object to a string.
  @override
  String toString() {
    return "Dexcom(user: $user, application: $application, region: $region)";
  }

  /// Build a URL based on the specified endpoint and arguments.
  Uri BuildApiUrl(String endpoint, {Map<String, dynamic>? args, String version = "v3"}) {
    String subdomain = _sandbox ? "sandbox-api" : "api";
    String host = '';

    switch (region) {
      case DexcomRegion.us: host = 'dexcom.com';
      case DexcomRegion.ous: host = 'dexcom.eu';
      case DexcomRegion.jp: host = 'dexcom.jp';
      default: throw Exception("A region was not provided.");
    }

    Uri url = Uri.https('$subdomain.$host', '/$version/$endpoint', args);
    return url;
  }

  /// Initialize the authorization process.
  Future<bool> auth() async {
    Map body = {
      'grant_type': 'refresh_token',
      'client_id': application.clientId,
      'client_secret': application.clientSecret,
      'refresh_token': tokens?.refreshToken ?? user.token,
    };

    http.Response response = await http.post(
      Uri.parse('https://${_sandbox ? "sandbox-api" : "api"}.dexcom.com/v2/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    print("$body");
    Map data = jsonDecode(response.body);
    if (data.containsKey("error")) {
      throw Exception("DexcomWeb: init: ${data["error"]} (code ${response.statusCode})");
    }

    tokens = DexcomTokens(refreshToken: data["refresh_token"], accessToken: data["access_token"]);
    return true;
  }
}

/// Container for access and refresh tokens.
class DexcomTokens {
  /// Access token. This is the token used in API requests.
  String refreshToken;

  /// Refresh token. This is the token used in access token requests.
  String accessToken;

  /// Both tokens are required.
  DexcomTokens({required this.refreshToken, required this.accessToken});
}

/// Generates an authorization URL that can be used to authenticate the user.
Uri GenerateDexcomAuthorizationUrl({String? state, required DexcomApplication application, bool sandbox = false}) {
  String redirectUri = application.redirectUri;
  Map<String, dynamic> args = {"client_id": application.clientId, "redirect_uri": "$redirectUri", "response_type": "code", "scope": "offline_access"};

  if (state != null) {
    args["state"] = state;
  }

  Uri url = Uri.https('${sandbox ? "sandbox-api" : "api"}.dexcom.com', '/v2/oauth2/login', args);
  return url;
}

/// Credentials for your Dexcom application.
class DexcomApplication {
  /// Client ID.
  final String clientId;

  /// Client secret (password).
  final String clientSecret;

  /// One of the application's redirect URIs. This is separate from the one specified when generating an authorization link.
  final String redirectUri;

  /// All credentials are required.
  DexcomApplication({required this.clientId, required this.clientSecret, required this.redirectUri});
  
  /// Converts the current DexcomUser object to a string.
  /// Does not show the password of the object by default.
  @override
  String toString({bool showPassword = false}) {
    return "DexcomApplication(clientId: $clientId, clientSecret: ${showPassword ? clientSecret : ("*" * clientSecret.length)}, redirectUri: $redirectUri)";
  }
}

/// Defines a Dexcom client.
/// DexcomUser.share: For the Dexcom Share API.
/// DexcomUser.sandbox: For the Dexcom Web API when using sandbox data.
class DexcomUser {
  /// Private sandbox decider of the user.
  /// Do not change this.
  bool sandbox = false;

  /// Previous refresh token.
  String? token;

  /// For use with the Dexcom Web API when using sandbox data.
  DexcomUser.sandbox() {
    sandbox = true;
  }

  /// For use with the Dexcom Web API
  DexcomUser({required this.token}) {}

  /// Converts the current DexcomUser object to a string.
  /// Does not show the password of the object by default.
  @override
  String toString() {
    return "DexcomUser(sandbox: $sandbox)";
  }
}