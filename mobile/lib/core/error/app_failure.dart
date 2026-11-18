/// Every error shown to the user is one of these. Data-layer code converts
/// exceptions (Dio, geolocator, parsing) into an [AppFailure] so the UI only has
/// to deal with a title, a message and whether retrying makes sense.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  String get title;
  bool get canRetry => true;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = "We couldn't reach the RideCompare server. Check your internet connection and try again.",
  ]);
  @override
  String get title => 'No connection';
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure([super.message = 'The server took too long to respond. Please try again.']);
  @override
  String get title => 'Taking too long';
}

class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {this.code, this.statusCode, this.reason});
  final String? code;
  final int? statusCode;

  /// Machine-readable sub-reason from the API, e.g. SAME_LOCATION.
  final String? reason;

  @override
  String get title => switch (code) {
    'VALIDATION_ERROR' => 'Check your trip',
    'NO_PROVIDERS_AVAILABLE' => 'No rides right now',
    'RATE_LIMITED' => 'Slow down a little',
    'NOT_FOUND' => 'Not found',
    _ => 'Something went wrong',
  };

  @override
  bool get canRetry => code != 'VALIDATION_ERROR';
}

class LocationFailure extends AppFailure {
  const LocationFailure(super.message, {this.openSettings = false});

  /// True when the user has to change a permission in system settings.
  final bool openSettings;

  @override
  String get title => 'Location unavailable';
}

class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure([super.message = 'Something unexpected happened. Please try again.']);
  @override
  String get title => 'Something went wrong';
}

AppFailure toFailure(Object error) => error is AppFailure ? error : const UnexpectedFailure();
