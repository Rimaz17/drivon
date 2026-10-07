import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

/// Converts a Dio failure into an [AppException] the UI can explain.
AppException mapDioException(DioException error) {
  final cause = error.error;
  if (cause is AppException) return cause;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const ServerTimeoutException();
    case DioExceptionType.connectionError:
      return const NoConnectionException();
    case DioExceptionType.badResponse:
      final response = error.response;
      return response == null
          ? UnexpectedException(error)
          : problemFromResponse(response);
    case DioExceptionType.unknown:
      return cause is SocketException
          ? const NoConnectionException()
          : UnexpectedException(error);
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
      return UnexpectedException(error);
  }
}

/// Reads the Problem Details body (`code`, `detail`, `errors`) of an error
/// response. Falls back to an `HTTP_<status>` code for non-JSON bodies.
ApiProblemException problemFromResponse(Response<dynamic> response) {
  final status = response.statusCode ?? 0;
  final body = _asJsonMap(response.data);
  final fieldErrors = <String, String>{};
  final errors = body?['errors'];
  if (errors is List) {
    for (final item in errors) {
      if (item is Map<String, dynamic>) {
        final field = item['field'];
        final message = item['message'];
        if (field is String && message is String) {
          fieldErrors.putIfAbsent(field, () => message);
        }
      }
    }
  }
  final code = body?['code'];
  final detail = body?['detail'];
  return ApiProblemException(
    statusCode: status,
    code: code is String ? code : 'HTTP_$status',
    detail: detail is String ? detail : null,
    fieldErrors: fieldErrors,
    properties: body ?? const {},
  );
}

Map<String, dynamic>? _asJsonMap(Object? data) {
  if (data is Map<String, dynamic>) return data;
  if (data is String && data.isNotEmpty) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      return null;
    }
  }
  return null;
}
