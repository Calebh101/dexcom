import 'package:dexcom/_api/all.dart';
import 'package:intl/intl.dart';

/// Gets the current locale using Intl.
DexcomRegion getRegion() {
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