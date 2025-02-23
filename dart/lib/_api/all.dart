/// Identifiers for Dexcom regions. This is used in both the Share API and the Web API.
enum DexcomRegion {
  /// US
  us,
  
  /// Out of US
  ous,

  /// Japan
  jp,
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
  final String systemTime;

  /// displayTime is the time being shown on the device to the user.
  /// Depending on the device, this time may be user-configurable, and can therefore change its offset relative to systemTime.
  /// Note that systemTime is not "true" UTC time because of drift and/or user manipulation of the devices' clock.
  final String displayTime;

  /// This is undocumented.
  final String wt;

  /// Blood glucose level. This is always mg/dL.
  final int value;

  /// Trend of the current glucose.
  final DexcomTrend trend;

  // Trend of the current glucose as a string.
  String? _trendString;

  /// All options are required.
  DexcomReading({required this.systemTime, required this.displayTime, required this.wt, required this.value, required this.trend}) {
    switch (trend) {
      case DexcomTrend.flat: _trendString = "Flat";
      case DexcomTrend.fortyFiveDown: _trendString = "FortyFiveDown";
      case DexcomTrend.fortyFiveUp: _trendString = "FortyFiveUp";
      case DexcomTrend.singleDown: _trendString = "SingleDown";
      case DexcomTrend.singleUp: _trendString = "SingleUp";
      case DexcomTrend.doubleDown: _trendString = "DoubleDown";
      case DexcomTrend.doubleUp: _trendString= "DoubleUp";
      case DexcomTrend.nonComputable: _trendString = "NonComputable";
      case DexcomTrend.none: _trendString = "None";
    }
  }

  /// Convert the reading to JSON.
  Map toJson() {
    return {
      "ST": systemTime,
      "DT": displayTime,
      "WT": wt,
      "Value": value,
      "Trend": _trendString,
    };
  }

  /// Convert the reading to a string.
  @override
  String toString() {
    return "DexcomReading(systemTime: $systemTime, displayTime: $displayTime, wt: $wt, value: $value, trend: $_trendString)";
  }
}