import 'dart:io' show InternetAddress;
import 'dart:isolate' show Isolate, ReceivePort, SendPort;
import 'package:streamZ/streamZ.dart' as streamZ;

// main entry point of application, I'm assuming while running application
// it should be invoked from this directory
//
// even when using `systemd` for automating whole thing, make sure
// WorkingDirectory is set as this directory

/*
  This method is expected to be invoked when creating multiple server instance(s),
  ( listening on same IP & Port on this machine ), each on a separate multiple Isolate.
  
  It'll receive two SendPorts, where it can either enquire or set performance statistics of a
  certain peer.
 */
spawnHandler(SendPort sendPort) {
  ReceivePort receivePort = ReceivePort();
  List<SendPort> sendPorts;
  receivePort.listen(
    (ports) {
      sendPorts = List<SendPort>.from(ports);
      receivePort.close();
    },
    cancelOnError: true,
    onDone: () => streamZ.createServer(InternetAddress.anyIPv4, sendPorts),
  );
  sendPort.send(receivePort.sendPort);
}

/*
  This method is supposed to be run in a different isolate, which will let us
  enquire performance statistics of a certain peer i.e. time spent in handling last
  request / was connection fast enough / did remote consume data pretty fast etc.
  
  Implementation not yet completed, requires work !!!
*/
requestHandlingStatisticsMaintainer(SendPort sendPort) {
  Map<String, double> stat = <String, double>{};
  ReceivePort getPerformanceReceivePort = ReceivePort()
    ..listen(
      (requestFromRemote) {
        requestFromRemote = List<dynamic>.from(requestFromRemote);
        SendPort sendResponseTo = requestFromRemote[0] as SendPort;
      },
      cancelOnError: true,
    );
  ReceivePort setPerformanceReceivePort = ReceivePort()
    ..listen(
      (requestFromRemote) {
        requestFromRemote = Map<String, double>.from(
            requestFromRemote); // here we'll simply set stat of a certain remote 
        // so no feedback path required, which was required in previous one, cause that was a query
      },
      cancelOnError: true,
    );
  sendPort.send([
    getPerformanceReceivePort.sendPort,
    setPerformanceReceivePort.sendPort,
  ]);
}

main(List<String> args) async {
  int count = 1;
  if (args.isNotEmpty) {
    try {
      count = int.parse(args[0], radix: 10);
    } on Exception {
      count = 1;
    }
  }
  SendPort sendPortToGetPerformance;
  SendPort sendPortToSetPerformance;
  ReceivePort performanceInfoHolderReceivePort = ReceivePort();
  performanceInfoHolderReceivePort.listen(
    (ports) {
      ports = List<SendPort>.from(ports);
      sendPortToGetPerformance = ports[0];
      sendPortToSetPerformance = ports[1];
      performanceInfoHolderReceivePort.close();
    },
    cancelOnError: true,
  );
  await Isolate.spawn(
    requestHandlingStatisticsMaintainer,
    performanceInfoHolderReceivePort.sendPort,
    debugName: 'performanceInfoHolderIsolate',
  ); // creating a new Isolate to keep track of performance i.e. how request(s)
  // are being handled by this machine & how is remote cooperating in that.
  for (int i = 0; i < count; i++) {
    ReceivePort receivePort = ReceivePort();
    receivePort.listen(
      (port) {
        (port as SendPort).send([
          sendPortToGetPerformance,
          sendPortToSetPerformance,
        ]);
        receivePort.close(); // cause this listener is no more required
      },
      cancelOnError: true,
    );
    await Isolate.spawn(spawnHandler, receivePort.sendPort,
        debugName: 'streamZ$i');
  }
}
