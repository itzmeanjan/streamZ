import 'dart:io' show InternetAddress;
import 'dart:isolate' show Isolate, ReceivePort, SendPort;
import 'package:streamZ/streamZ.dart' as streamZ;

// main entry point of application, I'm assuming while running application
// it should be invoked from this directory
//
// even when using `systemd` for automating whole thing, make sure
// WorkingDirectory is set as this directory

spawnHandler(SendPort sendPort) =>
    streamZ.createServer(InternetAddress.anyIPv4);

main(List<String> args) {
  int count = 1;
  if (args.isNotEmpty) {
    try {
      count = int.parse(args[0], radix: 10);
    } on Exception {
      count = 1;
    }
  }
  for (int i = 0; i < count; i++) {
    ReceivePort receivePort = ReceivePort();
    Isolate.spawn(spawnHandler, receivePort.sendPort, debugName: 'streamZ$i');
  }
}
