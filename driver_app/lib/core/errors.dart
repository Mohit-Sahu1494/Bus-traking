class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class GpsDisabledException implements Exception {
  const GpsDisabledException([this.message = 'Device GPS is turned off. Please enable Location in settings.']);
  final String message;
  @override
  String toString() => message;
}

class LocationPermissionException implements Exception {
  const LocationPermissionException(this.message, {this.permanentlyDenied = false});
  final String message;
  final bool permanentlyDenied;
  @override
  String toString() => message;
}

class LocationAcquisitionException implements Exception {
  const LocationAcquisitionException([this.message = 'Unable to get your current location. Please make sure GPS is enabled and you are in an area with a location signal.']);
  final String message;
  @override
  String toString() => message;
}

String humanizeError(Object error) {
  if (error is GpsDisabledException) return error.message;
  if (error is LocationPermissionException) return error.message;
  if (error is LocationAcquisitionException) return error.message;
  if (error is ApiException) return error.message;
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'Internet unavailable. Check your connection.';
  }
  if (text.contains('Timeout')) return 'The server is taking too long to respond.';
  return text.replaceFirst('Exception: ', '');
}
