import 'package:example/share.dart' as share;
import 'package:example/web.dart' as web;

enum DexcomAPI {
  share,
  web,
}

void main(
  List<String> arguments, {
  DexcomAPI type = DexcomAPI.share,
}) {
  if (arguments.contains("--web")) {
    type = DexcomAPI.web;
  }

  if (type == DexcomAPI.share) {
    share.main(username: arguments[0], password: arguments[1]);
  } else {
    web.main(clientId: arguments[0], clientSecret: arguments[1], redirectUri: arguments[3], token: arguments[2]);
  }
}
