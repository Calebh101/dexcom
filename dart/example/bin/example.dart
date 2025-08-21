import 'dart:io';

import 'package:example/example.dart' as example;

void main(List<String> arguments, {String? username, String? password}) {
  username ??= Platform.environment['DEXCOM_USERNAME'] ?? "";
  password ??= Platform.environment['DEXCOM_PASSWORD'] ?? "";

  if (arguments.length >= 2) {
    username = arguments[0];
    password = arguments[1];
  }

  example.main(username: username, password: password);
}
