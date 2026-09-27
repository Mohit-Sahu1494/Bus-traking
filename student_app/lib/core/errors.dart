class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code, this.details});
  final String message;
  final int? status;
  final String? code;
  final dynamic details;

  @override
  String toString() => message;
}

String humanizeError(Object error) {
  if (error is ApiException) {
    if (error.status == 401) {
      return 'Your session has expired. Please login again.';
    }
    if (error.status == 403 && error.code != 'EMAIL_NOT_VERIFIED') {
      return error.message.isNotEmpty
          ? error.message
          : 'You are not authorized to perform this action.';
    }
    if (error.status == 404) {
      return error.message.isNotEmpty
          ? error.message
          : 'The requested resource was not found.';
    }
    if (error.status == 409) {
      return error.message.isNotEmpty
          ? error.message
          : 'This account already exists.';
    }
    if (error.status == 429) {
      return error.message.isNotEmpty
          ? error.message
          : 'Too many attempts. Please wait and try again.';
    }
    if (error.status != null && error.status! >= 500) {
      return 'Something went wrong on the server. Please try again.';
    }
    return error.message;
  }

  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('NetworkImageLoadException') ||
      text.contains('ClientException') ||
      text.contains('Connection refused') ||
      text.contains('Connection closed')) {
    return 'Unable to connect to the server. Please check your internet connection.';
  }
  if (text.contains('Timeout') || text.contains('TimeoutException')) {
    return 'Request timed out. Please try again.';
  }
  if (text.contains('FormatException')) {
    return 'Unexpected server response. Please try again.';
  }

  return text
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');
}
