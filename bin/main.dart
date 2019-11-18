import 'dart:io' show InternetAddress;
import 'dart:isolate' show Isolate, ReceivePort, SendPort;
import 'package:streamZ/streamZ.dart' as streamz;
import 'package:streamZ/performance.dart';

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
      receivePort.close(); // no more required, so closing it
    },
    cancelOnError: true,
    onDone: () => streamz.createServer(InternetAddress.anyIPv4, sendPorts),
  );
  sendPort.send(receivePort.sendPort);
}

/*
  This method is supposed to be run in a different isolate, which will let us
  enquire performance statistics of a certain peer i.e. time spent in handling last
  request / was connection fast enough / did remote consume data pretty fast etc.

  Depending upon which a decision is to be taken, how much amount of data to be
  transferred in next request from this certain peer.

  It may be thought of as a load balancing mechanism, which will increment
  amount of data to be transferred to a certain peer by 2 ( next time ) if previous
  request was handled efficiently
  else we'll simply half that amount

  But one point that's important to be noted, minimum amount that can be sent to be peer
  at a certain time, is fixed at 512KB i.e. 1024*512 bytes.
*/
requestHandlingStatisticsMaintainer(SendPort sendPort) {
  List<PerformanceStatistics> stat = [];
  ReceivePort getPerformanceReceivePort = ReceivePort()
    ..listen(
      (requestFromRemote) {
        requestFromRemote = List<dynamic>.from(requestFromRemote);
        int tmp = stat.indexWhere(
            (elem) => elem.remoteIP == (requestFromRemote[1] as String));
        (requestFromRemote[0] as SendPort)
            .send(tmp == -1 ? 1024 * 512 : stat[tmp].getDecidedAmountInBytes);
      },
      cancelOnError: true,
    );
  ReceivePort setPerformanceReceivePort = ReceivePort()
    ..listen(
      (requestFromRemote) {
        requestFromRemote = Map<String, dynamic>.from(
            requestFromRemote); // here we'll simply set stat of a certain remote
        // so no feedback path required, which was required in previous one, cause that was a query
        requestFromRemote.forEach(
          (String key, dynamic val) {
            var actualData = Map<String, dynamic>.from(val);
            int tmp = stat.indexWhere((elem) => elem.remoteIP == key);
            tmp == -1
                ? stat.add(PerformanceStatistics()
                  ..updateStatistics(key, actualData['data'] as int,
                      actualData['time'] as int))
                : stat[tmp].updateStatistics(
                    key, actualData['data'] as int, actualData['time'] as int);
          },
        );
      },
      cancelOnError: true,
    );
  sendPort.send([
    getPerformanceReceivePort.sendPort,
    setPerformanceReceivePort.sendPort,
  ]);
}

/*
  main entry point of application, I'm assuming while running application
  you're invoking it from this directory
  
  Even when using `systemd` for automating whole thing, make sure
  WorkingDirectory is set as this directory

  You may consider running multiple instances of this streaming service
  by putting a positive integer as command line argument while invoking this application

  $ dart2aot main.dart main.dart.aot
  $ dartaotruntime main.dart.aot 2

  Will simply invoke two instances of this application, while
  each of them running in a different Isolate
*/
main(List<String> args) {
  int count = 2;
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
  Isolate.spawn(
    requestHandlingStatisticsMaintainer,
    performanceInfoHolderReceivePort.sendPort,
    debugName: 'performanceInfoHolderIsolate',
  ).then((val) {
    for (int i = 0; i < count; i++) {
      ReceivePort receivePort = ReceivePort();
      receivePort.listen(
        (port) {
          (port as SendPort).send([
            sendPortToGetPerformance,
            sendPortToSetPerformance,
          ]);
        },
        cancelOnError: true,
      );
      Isolate.spawn(spawnHandler, receivePort.sendPort, debugName: 'streamZ$i');
    }
  }); // creating a new Isolate to keep track of performance i.e. how request(s)
  // are being handled by this machine & how is remote cooperating in that.
}
