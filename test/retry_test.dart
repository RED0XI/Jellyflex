import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflex/core/retry.dart';

DioException _status(int code) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    response: Response(requestOptions: request, statusCode: code),
  );
}

void main() {
  test('Abfragen: 4xx nie wiederholen, sonst höchstens dreimal mit wachsender Pause', () {
    for (final code in [400, 401, 403, 404]) {
      expect(providerRetry(0, _status(code)), isNull, reason: '$code');
    }
    expect(providerRetry(0, _status(500)), const Duration(milliseconds: 500));
    expect(providerRetry(2, StateError('Zeitüberschreitung')), const Duration(seconds: 2));
    expect(providerRetry(3, _status(503)), isNull);
  });
}
