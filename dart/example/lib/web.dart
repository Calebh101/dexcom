import 'package:dexcom/web.dart';

void main({String? clientId, String? clientSecret, String? token, String? redirectUri}) async {
  DexcomApplication app = DexcomApplication(clientId: clientId!, clientSecret: clientSecret!, redirectUri: redirectUri!);
  DexcomWeb dexcom = DexcomWeb(user: DexcomUser(token: token), application: app);
  print("DexcomWeb: $dexcom");
  print("auth url: ${GenerateDexcomAuthorizationUrl(application: app, sandbox: false)}");
  await dexcom.auth();
}
