/// Thrown by ApiClient on a non-2xx response, mirroring the
/// `throw new Error(errorMessage)` behavior in mobile/src/services/api.ts.
class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
