/*
  Performance statistics holder & decision maker, for how much data
  to be transferred in next request
*/
class PerformanceStatistics {
  String _deviceIP; // remote device identifier i.e. IP
  int _dataTransferred; // in bytes
  int _timeSpent; // in millisecond(s)
  int _decidedAmountToBeTransferred; // this is to be calculated every time
  // some request handler isolate tries to update statistics.
  // if present data transfer speed was good, next time we'll send double data
  // else data to be transferred is made half

  PerformanceStatistics(); // a simple constructor, indeed simple

  /*
    This method is expected to update device's performance
    indicating data i.e. amount of data transferred ( in bytes )
    & time spent on that operation, along with calculating
    what's the amount of data to be sent next time
  */
  updateStatistics(String ip, int data, int time) {
    if (_deviceIP == null) {
      _deviceIP = ip;
      _dataTransferred = data;
      _timeSpent = time;
      _decidedAmountToBeTransferred = _dataTransferred;
    } else if (_deviceIP == ip) {
      double past = _dataTransferred / _timeSpent;
      double present = data / time;
      _decidedAmountToBeTransferred = present >= past
          ? data * 2
          : (data / 2).floor() > 0 ? (data / 2).floor() : 1024 * 512;
      _dataTransferred = data;
      _timeSpent = time;
    }
  }

  // a simple getter
  int get getDecidedAmountInBytes => _decidedAmountToBeTransferred;

  // another simple getter, to be required for deciding whether we're
  // invoking proper object or not
  String get remoteIP => _deviceIP;
}
