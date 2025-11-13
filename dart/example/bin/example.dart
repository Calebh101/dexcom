import 'dart:io';

import 'package:args/args.dart';
import 'package:example/example.dart' as example;

// For username and password, first we check optional parameters, then we take from environmental variables.
// However, if arguments are provided (using --username and --password), we use those.

void main(List<String> arguments, {String? username, String? password}) {
  username ??= Platform.environment['DEXCOM_USERNAME'] ?? "";
  password ??= Platform.environment['DEXCOM_PASSWORD'] ?? "";

  ArgParser parser =
      ArgParser()
        ..addOption("username", abbr: "u", help: "Dexcom account username")
        ..addOption("password", abbr: "p", help: "Dexcom account password")
        ..addFlag("verbose", abbr: "v", help: "Verbose mode");

  late ArgResults args;

  try {
    args = parser.parse(arguments);
  } catch (_) {
    print(parser.usage);
    exit(1);
  }

  if (args["username"] != null) username = args["username"];
  if (args["password"] != null) password = args["password"];

  example.main(
    username: username!,
    password: password!,
    verbose: args["verbose"] ?? false,
  );
}
