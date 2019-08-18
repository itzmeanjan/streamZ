import 'dart:async';
import 'dart:convert';
import 'dart:isolate' show Isolate, SendPort;
import 'dart:isolate';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:math' show Random;

import 'package:streamZ/movies.dart';
import 'package:streamZ/playList.dart';

/*
  Handling a GET request is done here, with the help of switch statements,
  so that each supported path can be handled properly
  
  Other requestedURI(s) are to discarded, while sending HttpStatus `notFound`
*/
_handleGETRequest(
    HttpRequest httpRequest, List<SendPort> sendPorts, List<Movie> movies) {
  /*
    a closure, basically used for writing response of a legit & supported GET request
   */
  Future<void> getMethodResponseWriter() async {
    /*
      a closure, which writes content of a certain file, whose path is provided,
      to response sink & on completion closes http connection
     */
    serveFile(String filePath) =>
        httpRequest.response.addStream(File(filePath).openRead()).then(
              (val) async => await httpRequest.response.close(),
              onError: (e) async => await httpRequest.response.close(),
            );

    try {
      switch (httpRequest.requestedUri.path) {
        case '/':
          httpRequest.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html;
          await serveFile(path.normalize(
              path.join(path.current, '../frontend/pages/index.html')));
          break;
        case '/index.js':
          httpRequest.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.parse('text/javascript');
          await serveFile(path.normalize(
              path.join(path.current, '../frontend/scripts/index.js')));
          break;
        case '/index.css':
          httpRequest.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.parse('text/css');
          await serveFile(path.normalize(
              path.join(path.current, '../frontend/styles/index.css')));
          break;
        case '/movies':
          httpRequest.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'path': movies.map((elem) => elem.id).toList(growable: false)
            }));
          await httpRequest.response.close(); // closing connection
          break;
        case '/favicon.ico':
          httpRequest.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.parse('image/x-icon');
          await serveFile(path.normalize(
              path.join(path.current, '../frontend/images/favicon.ico')));
          break;
        default:
          String requestedMovie = httpRequest.requestedUri.path.substring(1);
          int foundElementIndex = movies.indexWhere((elem) =>
              elem.id ==
              requestedMovie); // trying to find out whether requested movie can be streamed or not
          if (foundElementIndex == -1) {
            // not it can't be streamed, cause we don't have it
            httpRequest.response.statusCode = HttpStatus.notFound;
            await httpRequest.response.close(); // closing connection
          } else {
            // well we're trying to stream it
            var range = httpRequest.headers.value('Range');
            if (range == null) {
              // user just requested a download, starting a download
              httpRequest.response
                ..statusCode = HttpStatus.ok
                ..headers.contentType = ContentType.parse(
                    'video/${movies[foundElementIndex].id.split('.').last}')
                ..headers.set('Content-Disposition',
                    'attachment; filename="${path.basename(movies[foundElementIndex].path)}"')
                ..headers.contentLength = movies[foundElementIndex].size;
              await serveFile(movies[foundElementIndex].path);
            } else {
              // trying to stream movie
              httpRequest.response
                ..statusCode = HttpStatus.partialContent
                ..headers.contentType = ContentType.parse(
                    'video/${movies[foundElementIndex].id.split('.').last}')
                ..headers.set(
                    'Accept-Ranges', 'bytes'); // setting some response headers
              String remoteAddress =
                  httpRequest.connectionInfo.remoteAddress.address;
              List<String> splitRange =
                  range.replaceFirst('bytes=', '').split('-');
              // total # of bytes present in our target file
              int init = int.parse(splitRange[0],
                  radix:
                      10); // initial position requested by client ( it'll always be present in request headers )
              ReceivePort receivePort =
                  ReceivePort(); // we'll request performance stat holder Isolate to give us amount of data to be transferred in this response ( in bytes )
              receivePort.listen(
                (transferThisMuchData) {
                  // decision to be taken by considering performance of this client ( & also backend ) in last request
                  int end = splitRange[1]
                          .isEmpty // if nothing is requested as max offset by client, we'll simply choose best possible value ( while considering performance in previous request ), until & unless it crosses total size of file
                      ? (init + transferThisMuchData as int) >=
                              movies[foundElementIndex].size
                          ? movies[foundElementIndex].size - 1
                          : init + transferThisMuchData as int
                      : int.parse(splitRange[1],
                          radix:
                              10); // and if there's something specific in request header, we'll simply send that data, until & unless it crosses 1Mb max threshold of data, can be sent at a time
                  httpRequest.response
                    ..headers.set('Content-Range',
                        'bytes $init-$end/${movies[foundElementIndex].size}')
                    ..headers.set('Content-Length', end - init + 1);
                  var stopWatch = Stopwatch()
                    ..start(); // we're going to calculate how much time we had to spend for completing this transfer ( in milliseconds )
                  File(movies[foundElementIndex].path)
                      .openRead(init, end + 1)
                      .pipe(httpRequest.response)
                      .then(
                    (val) async {
                      await httpRequest.response.close(); // closing connection
                      stopWatch.stop(); // stopping it
                      sendPorts[1].send({
                        remoteAddress: {
                          'data': end - init + 1,
                          'time': stopWatch.elapsed.inMilliseconds,
                        },
                      }); // feeding performance, which is to be used in next request, for this client
                      receivePort.close(); // closing not required stream
                    },
                    onError: (e) async {
                      await httpRequest.response.close(); // closing connection
                      stopWatch.stop();
                      sendPorts[1].send({
                        remoteAddress: {
                          'data': 0,
                          // something went badly wrong, so next time we'll get back to lowest data transferring value, which is 512KB ( to be set in target Isolate )
                          'time': stopWatch.elapsed.inMilliseconds,
                        },
                      });
                      receivePort.close(); // closing this stream
                    },
                  ); // end+1 as max offset, cause we'll read up to byte index `end` not (end + 1)
                },
                onError: (e) async => await httpRequest.response.close(),
                cancelOnError: true,
              );
              sendPorts[0].send([
                receivePort.sendPort,
                remoteAddress,
              ]); // sending query to performance stat holder Isolate, what's the amount of data to be transferred this time, to be returned in response
            }
          }
      }
    } on Exception {
      httpRequest.response.statusCode = HttpStatus
          .internalServerError; // if something goes wrong at backend, we'll send thi status code
      await httpRequest.response.close(); // closing connection
    }
  }

  // for simple logging purpose
  print(
      '${httpRequest.method}\t${httpRequest.requestedUri.path}\t${httpRequest.connectionInfo.remoteAddress.address}\t${DateTime.now().toString()}\t${Isolate.current.debugName}');
  // we'll not consider any content of request body, but rather write some meaningful response depending upon requestedURI
  httpRequest.drain().then(
        (val) => getMethodResponseWriter(),
        onError: (e) async => await httpRequest.response.close(),
      );
}

_handlePUTRequest(HttpRequest httpRequest) {
  print(
      '${httpRequest.method}\t${httpRequest.requestedUri.path}\t${httpRequest.connectionInfo.remoteAddress.address}\t${DateTime.now().toString()}\t${Isolate.current.debugName}');
  httpRequest.listen(
    (data) => print(data),
    onError: (e) => print(e),
    onDone: () async {
      httpRequest.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(<String, String>{
          'status': 'success',
        }));
      await httpRequest.response.close();
    },
    cancelOnError: true,
  );
}

/*
  Here we plan to handle any kind of requests other than GET,
  which are to be simply discarded & to be responded using HttpStatus `methodNotAllowed`
 */
_handleOtherRequest(HttpRequest httpRequest) {
  /*
    This closure will write response & close connection ( which is pretty important )
   */
  Future<void> methodNotSupportedResponseWriter() async {
    httpRequest.response
      ..statusCode = HttpStatus.methodNotAllowed
      ..headers.contentType = ContentType.text
      ..reasonPhrase = 'method not supported'
      ..write('Method not supported');
    await httpRequest.response.close();
  }

  // not interested in any content of this request body, so simply draining content of this stream
  // when completed, to be notified via callback methods
  httpRequest.drain().then(
        (val) => methodNotSupportedResponseWriter(),
        onError: (e) async => await httpRequest.response.close(),
      );
}

/*
  Creates a http server, accessible on provided host & default port 8000, if nothing specific supplied
  
  Server is supposed to entertain only GET request ( as per current situation ),
  so anything else will return `methodNotAllowed` status
  
  GET requests are to be handled in a different method
  
  Sharing this IP & Port will let us create multiple isolates, while all of
  them listening on this same IP & Port, for serving many more request(s) efficiently.
*/
createServer(InternetAddress host, List<SendPort> sendPorts,
        {int port = 8000, String serverName = 'streamZ_v1.0.0'}) =>
    HttpServer.bind(host, port, shared: true).then(
      (httpServer) => build().then(
        (List<Movie> data) {
          if (data.isEmpty) {
            Isolate.current.kill(
              priority: Isolate.immediate,
            ); // as we don't have any movies, we won't start server, we'll simply kill ourselves
          } else {
            List<Movie> movies = data;
            // setting up a periodic timer here, so that list of available movies can be
            // refreshed every 30 minutes & some random seconds
            // ( cause we may be running multiple Isolates), if & only if timer is active
            Timer.periodic(
                Duration(
                    minutes: 30,
                    seconds: Random(DateTime.now().millisecondsSinceEpoch)
                        .nextInt(59)), (timer) async {
              if (timer.isActive) {
                movies = await build();
              }
            });
            httpServer.serverHeader = serverName;
            print(
                '[+]${serverName} listening ( ${Isolate.current.debugName} ) ...\n');
            httpServer.listen(
              (httpRequest) {
                switch (httpRequest.method) {
                  case 'GET':
                    _handleGETRequest(httpRequest, sendPorts, movies);
                    break;
                  case 'PUT':
                    _handlePUTRequest(httpRequest);
                    break;
                  default:
                    _handleOtherRequest(httpRequest);
                }
              },
              onError: (e) => print('[!]Failed'),
              cancelOnError: true,
            );
          }
        },
      ),
      onError: (e) => print('[!]Failed'),
    );
