class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

String humanizeError(Object error) {
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'Internet unavailable. Check your connection.';
  }
  if (text.contains('Timeout')) return 'The server is taking too long to respond.';
  return text.replaceFirst('Exception: ', '');
}
