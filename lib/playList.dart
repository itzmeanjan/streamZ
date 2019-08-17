import 'dart:async' show Completer;
import 'dart:io' show Directory, Platform, File;
import 'package:path/path.dart' show join, basename;
import 'package:streamZ/movies.dart';

/*
  Generates list of available movies ( generally placed in ~/Videos directory )
  and returns back list of Movie objects as Future
*/
Future<List<Movie>> build() {
  var completer = Completer<List<Movie>>();
  var movies = <Movie>[];
  Directory(join(Platform.environment['HOME'], 'Videos')).list().listen(
    (movie) {
      // considering only mp4 & webm videos, cause only they're supported by major browsers
      if (movie.path.endsWith('mp4') || movie.path.endsWith('webm')) {
        File(movie.path).length().then(
              (lengthOfMovie) => movies.add(
                Movie(basename(movie.path).split(' ').join('.'), movie.path,
                    lengthOfMovie),
              ),
            );
      }
    },
    onError: (e) => completer.complete(movies),
    cancelOnError: true,
    onDone: () => completer.complete(movies),
  );
  return completer.future;
}
