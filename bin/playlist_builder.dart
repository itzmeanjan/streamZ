import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' show join, basename;

main() {
  String target_file = '../data/playList.json';
  Map<String, String> playList = {};
  Directory(join(Platform.environment['HOME'], 'Videos')).list().listen(
        (movie) => playList.addAll({basename(movie.path): movie.path}),
        onDone: () {
          File(target_file).exists().then(
            (result) {
              if (!result) {
                File(target_file).create(recursive: true).then(
                  (file) {
                    file
                        .writeAsString(jsonEncode(playList),
                            encoding: Encoding.getByName('utf-8'),
                            mode: FileMode.write)
                        .then(
                          (file) => print('Success'),
                          onError: (e) => print('Failure'),
                        );
                  },
                  onError: (e) => print('Failure'),
                );
              } else {
                File(target_file)
                    .writeAsString(jsonEncode(playList),
                        encoding: Encoding.getByName('utf-8'),
                        mode: FileMode.write)
                    .then(
                      (file) => print('Success'),
                      onError: (e) => print('Failure'),
                    );
              }
            },
            onError: (e) => print('Failure'),
          );
        },
        cancelOnError: true,
        onError: (e) => print('Failure'),
      );
}
