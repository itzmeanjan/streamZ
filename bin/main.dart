import 'dart:io' show InternetAddress;
import 'package:streamZ/streamZ.dart' as streamZ;
import 'dart:isolate' as iso;

// main entry point of application, I'm assuming while running application
// it should be invoked from this directory
//
// even when using `systemd` for automating whole thing, make sure
// WorkingDirectory is set as this directory

main() {
  streamZ.createServer(InternetAddress.anyIPv4);
}
