// holding information related to a certain movie
class Movie {
  String id; // actually this is what is to be sent to client
  String path; // where movie is residing in local file system ( in backend )
  int size; // total size of movie, we could've calculated it while handling every request
  // but doing this will ensure we're not doing unnecessary computation

  Movie(this.id, this.path, this.size);

  // this method will be helping us in getting an instance of this class from JSON data, which is read from target file, and converted into Map<String, Map<String, dynamic>>
  static Movie fromJSON(String movieName, Map<String, dynamic> movieData) =>
      Movie(movieName, movieData['path'], movieData['length'] as int);
}
