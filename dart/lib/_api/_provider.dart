import 'dart:async';
import 'package:dexcom/_api/_main.dart';

/// Class that provides a stream that you can listen to. This will automatically fetch new readings when the old readings have hit the interval (defaults to 300 seconds).
class DexcomStreamProvider {
  /// The Dexcom object that is listened to.
  final Dexcom object;

  /// Interval (in seconds) that the listener will automatically fetch new readings when the interval is hit. This should not be changed.
  int _interval = 300;

  /// Buffer (in seconds) that is added onto interval to give the client's Dexcom time to upload readings. This can help prevent skipping over a reading.
  int buffer;

  // Controller of the Dexcom reading stream.
  StreamController<List>? _controller;

  /// Debug mode (default is set to object's setting)
  bool? debug;

  /// How many pieces of data should be sent with each new incoming data. This is recommended to be a low number.
  int maxCount;

  /// Timer for the listener. Should not be cahnged
  int? time;

  // To track if someone is already listening.
  bool _isListening = false;

  /// Requires an object (which is a Dexcom object) for listening to.
  DexcomStreamProvider(this.object,
      {this.buffer = 0, this.maxCount = 2, this.debug}) {
    if (buffer < 0) {
      throw Exception("Buffer cannot be negative.");
    }

    if (maxCount < 1) {
      throw Exception("Max count cannot be less than 1.");
    }
  }

  /// Converts the current DexcomStreamProvider object to a string.
  @override
  String toString() {
    return "DexcomStreamProvider(object: $object, buffer: $buffer, maxCount: $maxCount, debug: $debug)";
  }

  /// Refresh the listener.
  void refresh() {
    time = 0;
  }

  /// Start listening to incoming Dexcom readings.
  void listen(
      {void Function(List<dynamic> data)? onData,
      void Function(Error error)? onError,
      void Function(int time)? onTimerChange,
      bool cancelOnError = false}) async {
    if (_isListening == true) {
      throw Exception("This stream is already being listened to.");
    } else {
      _isListening = true;
    }

    _init();
    bool _isProcessing = false;
    _controller = StreamController<List>();
    time = null;

    Timer.periodic(Duration(seconds: 1), (Timer timer) async {
      if (_controller!.isClosed) {
        timer.cancel();
        return;
      }

      if (_isProcessing == false) {
        if (time == null || ((time ?? 0) >= (_interval + buffer))) {
          _isProcessing = true;
          time ??= 0;

          try {
            _log("Getting glucose data", function: "listen.Timer");
            List data = (await object.getGlucoseReadings(maxCount: maxCount))!;
            time = (data[0]["TimeSince"] / 1000).toInt();

            if (time! >= _interval) {
              time = 0;
            }

            _controller!.add(data);
            (onData ?? () {})(data);
          } catch (e) {
            _controller!.addError(e);
            (onError ?? () {})(e);
            print("DexcomStreamProvider listen error: $e");

            if (cancelOnError) {
              rethrow;
            }
          } finally {
            _isProcessing = false;
          }
        }
      }

      time = (time == null ? 0 : time! + 1);
      (onTimerChange ?? () {})(time);
    });
  }

  /// Close the stream listening to the Dexcom readings.
  void close() {
    if (_isListening == false) {
      print("The stream is already closed.");
    }

    _init();
    time = null;
    _controller!.close();
    _isListening = false;
  }

  // Custom logging solution
  void _log(String message, {required String function}) {
    _init();
    if (debug!) {
      print("dexcom provider: $function: $message");
    }
  }

  // Initialize variables and checks
  void _init() {
    debug ??= object.debug;
  }

  /// Stream that can be listened to for new Dexcom readings.
  Stream<List>? get stream => _controller?.stream;
}
