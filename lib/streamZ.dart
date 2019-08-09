import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as path;
import 'dart:io';

/*
  Handling a GET request is done here, with the help of switch statements,
  so that each supported path can be handled properly
  
  Other requestedURI(s) are to discarded, while sending HttpStatus `notFound`
 */
_handleGETRequest(HttpRequest httpRequest) {
  /*
    a closure, basically used for writing response of a legit & supported GET request
   */
  Future<void> getMethodResponseWriter() async {
    /*
      a closure, which writes content of a certain file, whose path is provided,
      to response sink
     */
    serveFile(String filePath) =>
        httpRequest.response.addStream(File(filePath).openRead());

    /*
      This function checks whether a requested movie can be streamed or not,
      for that we need to check whether target file is present or not.

      If it's present we'll create a stream of requested range from that file,
      and send that to client.

      Remember at a time we can send at max 1MB ( 1024*1024 ) data, if requested data is larger than that,
      we'll send only 1MB else requested amount to be sent
    */
    Future<String> isRequestedMoviePresent(
        String movieName, String targetPath) {
      Completer<String> completer = Completer<String>();
      File(targetPath)
          .openRead()
          .transform(utf8.decoder)
          .transform(json.decoder)
          .listen((content) {
        var tmp = Map<String, String>.from(content);
        completer.complete(tmp.containsKey(movieName) ? tmp[movieName] : '');
      });
      return completer.future;
    }

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
          ..headers.contentType = ContentType.json;
        await serveFile(
            path.normalize(path.join(path.current, '../data/playList.json')));
        break;
      default:
        if (httpRequest.requestedUri.path.substring(1).endsWith('mp4')) {
          await isRequestedMoviePresent(
                  httpRequest.requestedUri.path.substring(1),
                  path.normalize(
                      path.join(path.current, '../data/playList.json')))
              .then(
            (String targetMoviePath) async {
              if (targetMoviePath.isNotEmpty) {
                var range = httpRequest.headers.value('Range');
                List<String> splitRange =
                    range.replaceFirst('bytes=', '').split('-');
                int init = int.parse(splitRange[0], radix: 10);
                int end = splitRange[1].isEmpty
                    ? (init + 1024 * 1024)
                    : (int.parse(splitRange[1], radix: 10) - init > 1024 * 1024)
                        ? (init + 1024 * 1024)
                        : int.parse(splitRange[1], radix: 10);
                httpRequest.response
                  ..statusCode = HttpStatus.partialContent
                  ..headers.contentType = ContentType.parse('video/mp4')
                  ..headers.set('Content-Range',
                      'bytes $init-$end/${File(targetMoviePath).lengthSync()}')
                  ..headers.set('Accept-Ranges', 'bytes')
                  ..headers.set('Content-Length', end - init + 1);
                await httpRequest.response
                    .addStream(File(targetMoviePath).openRead(init, end + 1));
              } else {
                httpRequest.response.statusCode = HttpStatus.notFound;
              }
            },
            onError: (e) =>
                httpRequest.response.statusCode = HttpStatus.notFound,
          );
        } else {
          httpRequest.response.statusCode = HttpStatus.notFound;
        }
    }
    // closing connection
    await httpRequest.response.close();
  }

  // for simple logging purpose
  print(
      '${httpRequest.method}\t${httpRequest.requestedUri.path}\t${httpRequest.connectionInfo.remoteAddress.address}\t${DateTime.now().toString()}');
  // we'll not consider any content of request body, but rather write some meaningful response depending upon requestedURI
  httpRequest.drain().then(
        (val) => getMethodResponseWriter(),
        onError: (e) async => await httpRequest.response.close(),
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
 */
createServer(InternetAddress host,
        {int port = 8000, String serverName = 'streamZ_v1.0.0'}) =>
    HttpServer.bind(host, port, shared: true).then(
      (httpServer) {
        httpServer.serverHeader = serverName;
        print('[+]${serverName} listening ...\n');
        httpServer.listen(
          (httpRequest) {
            switch (httpRequest.method) {
              case 'GET':
                _handleGETRequest(httpRequest);
                break;
              default:
                _handleOtherRequest(httpRequest);
            }
          },
          onError: (e) => print('[!]Failed'),
          cancelOnError: true,
        );
      },
      onError: (e) => print('[!]Failed'),
    );
