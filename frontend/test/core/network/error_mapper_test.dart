import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/network/error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _response(int status, Object? data) {
  final request = RequestOptions(path: '/api/v1/vehicles');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: request,
    response: Response<dynamic>(
      requestOptions: request,
      statusCode: status,
      data: data,
    ),
  );
}

void main() {
  test('reads code, detail and field errors from Problem Details', () {
    final error = mapDioException(
      _response(400, {
        'code': 'VALIDATION_FAILED',
        'detail': 'One or more fields are invalid.',
        'errors': [
          {'field': 'make', 'message': 'must not be blank'},
          {'field': 'year', 'message': 'must be greater than or equal to 1900'},
        ],
      }),
    );

    expect(
      error,
      isA<ApiProblemException>()
          .having((e) => e.statusCode, 'status', 400)
          .having((e) => e.code, 'code', ApiErrorCodes.validationFailed)
          .having((e) => e.fieldErrors.keys, 'fields', ['make', 'year']),
    );
  });

  test('parses a problem body delivered as a string', () {
    final error = mapDioException(
      _response(422, '{"code":"VEHICLE_LIMIT_REACHED","detail":"Max two."}'),
    );

    expect(
      error,
      isA<ApiProblemException>().having(
        (e) => e.code,
        'code',
        ApiErrorCodes.vehicleLimitReached,
      ),
    );
  });

  test('keeps rule-specific members such as the allowed odometer range', () {
    final error =
        mapDioException(
              _response(422, {
                'code': 'ODOMETER_OUT_OF_ORDER',
                'minKm': 45000,
                'maxKm': 47000,
              }),
            )
            as ApiProblemException;

    expect(error.intProperty('minKm'), 45000);
    expect(error.intProperty('maxKm'), 47000);
    expect(error.intProperty('missing'), isNull);
  });

  test('falls back to an HTTP status code for non-JSON bodies', () {
    final error = mapDioException(_response(502, '<html>Bad gateway</html>'));

    expect(
      error,
      isA<ApiProblemException>().having((e) => e.code, 'code', 'HTTP_502'),
    );
  });

  test('maps timeouts to a server timeout', () {
    final error = mapDioException(
      DioException.receiveTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: RequestOptions(),
      ),
    );

    expect(error, isA<ServerTimeoutException>());
  });

  test('maps connection failures to no connection', () {
    expect(
      mapDioException(
        DioException.connectionError(
          requestOptions: RequestOptions(),
          reason: 'refused',
        ),
      ),
      isA<NoConnectionException>(),
    );
    expect(
      mapDioException(
        DioException(
          requestOptions: RequestOptions(),
          error: const SocketException('no route'),
        ),
      ),
      isA<NoConnectionException>(),
    );
  });

  test('passes through app exceptions attached by interceptors', () {
    final error = mapDioException(
      DioException(
        requestOptions: RequestOptions(),
        error: const SessionExpiredException(),
      ),
    );

    expect(error, isA<SessionExpiredException>());
  });
}
