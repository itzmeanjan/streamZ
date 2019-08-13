import 'dart:async';
import 'dart:convert';
import 'dart:isolate' show Isolate;
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
      
      Returns a Map<String, dynamic>, holding absolute path of target file & 
      content length in bytes

      If it's present we'll create a stream of requested range from that file,
      and send that to client.

      Remember at a time we can send at max 1MB ( 1024*1024 ) data, if requested data is larger than that,
      we'll send only 1MB else requested amount to be sent
    */
    Future<Map<String, dynamic>> isRequestedMoviePresent(
        String movieName, String targetPath) {
      Completer<Map<String, dynamic>> completer =
          Completer<Map<String, dynamic>>();
      File(targetPath)
          .openRead()
          .transform(utf8.decoder)
          .transform(json.decoder)
          .listen((content) {
        var tmp = Map<String, dynamic>.from(content).map(
          (key, val) => MapEntry(key, Map<String, dynamic>.from(val)),
        );
        completer.complete(tmp.containsKey(movieName) ? tmp[movieName] : {});
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
      case '/favicon.ico':
        httpRequest.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.parse('image/x-icon');
        await serveFile(path.normalize(
            path.join(path.current, '../frontend/images/favicon.ico')));
        break;
      default:
        if (httpRequest.requestedUri.path.substring(1).endsWith('webm') ||
            httpRequest.requestedUri.path.substring(1).endsWith('mp4')) {
          await isRequestedMoviePresent(
                  httpRequest.requestedUri.path.substring(1),
                  path.normalize(
                      path.join(path.current, '../data/playList.json')))
              .then(
            (Map<String, dynamic> targetMovieStat) async {
              if (targetMovieStat.isNotEmpty) {
                var range = httpRequest.headers.value('Range');
                if (range == null) {
                  httpRequest.response
                    ..statusCode = HttpStatus.ok
                    ..headers.contentType = ContentType.parse(
                        'video/${targetMovieStat['path'].split('.').last}')
                    ..headers.set('Content-Disposition',
                        'attachment; filename="${path.basename(targetMovieStat['path'])}"')
                    ..headers.contentLength = targetMovieStat['length'] as int;
                  await File(targetMovieStat['path']).openRead().pipe(httpRequest
                      .response); // if client is requesting a download of content, whole file to be sent to remote
                } else {
                  List<String> splitRange =
                      range.replaceFirst('bytes=', '').split('-');
                  int total = (targetMovieStat['length'] as int);
                  // total # of bytes present in our target file
                  int init = int.parse(splitRange[0],
                      radix:
                          10); // initial position requested by client ( it'll always be present in request headers )
                  int end = splitRange[1]
                          .isEmpty // if nothing is requested as max offset, we'll simply send next 1MB data, until & unless it crosses total size of file
                      ? (init + 1024 * 1024) >= total
                          ? total - 1
                          : init + 1024 * 1024
                      : int.parse(splitRange[1],
                          radix:
                              10); // and if there's something specific in request header, we'll simply send that data, until & unless it crosses 1Mb max threshold of data, can be sent at a time
                  httpRequest.response
                    ..statusCode = HttpStatus.partialContent
                    ..headers.contentType = ContentType.parse(
                        'video/${targetMovieStat['path'].split('.').last}')
                    ..headers.set('Accept-Ranges', 'bytes')
                    ..headers.set('Content-Range',
                        'bytes $init-$end/${targetMovieStat['length'] as int}')
                    ..headers.set('Content-Length', end - init + 1);
                  await File(targetMovieStat['path'])
                      .openRead(init, end + 1)
                      .pipe(httpRequest
                          .response); // end+1 as max offset, cause we'll read up to byte index `end` not (end + 1)
                }
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
      '${httpRequest.method}\t${httpRequest.requestedUri.path}\t${httpRequest.connectionInfo.remoteAddress.address}\t${DateTime.now().toString()}\t${Isolate.current.debugName}');
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
        print(
            '[+]${serverName} listening ( ${Isolate.current.debugName} ) ...\n');
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
