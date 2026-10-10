import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// A request the API signed for the app to send straight to file storage.
/// It must go out exactly as given: the headers are part of the signature.
@immutable
class PresignedRequest {
  const PresignedRequest({
    required this.url,
    required this.method,
    required this.headers,
    required this.expiresAt,
  });

  /// Reads the API's `PresignedUrlResponse`.
  factory PresignedRequest.fromJson(Map<String, dynamic> json) =>
      PresignedRequest(
        url: Uri.parse(json['url'] as String),
        method: json['method'] as String,
        headers: (json['headers'] as Map<String, dynamic>).map(
          (name, value) => MapEntry(name, value as String),
        ),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );

  final Uri url;
  final String method;
  final Map<String, String> headers;
  final DateTime expiresAt;
}

/// Sends files to presigned storage URLs. It deliberately has its own HTTP
/// client without the API's interceptors: the access token must never reach
/// the storage service. Throws AppExceptions.
class StorageClient {
  StorageClient(this._dio);

  final Dio _dio;

  /// Uploads [bytes] with the signed method and headers. [onProgress] gets
  /// the fraction sent, from 0 to 1.
  Future<void> upload(
    PresignedRequest request,
    Uint8List bytes, {
    void Function(double fraction)? onProgress,
  }) => guardApi(() async {
    await _dio.requestUri<void>(
      request.url,
      // A stream (rather than a byte list) is sent as is, with the signed
      // Content-Length instead of a chunked body.
      data: Stream<List<int>>.value(bytes),
      options: Options(
        method: request.method,
        headers: {
          ...request.headers,
          Headers.contentLengthHeader: bytes.length,
        },
        contentType: request.headers[Headers.contentTypeHeader],
        responseType: ResponseType.plain,
      ),
      onSendProgress: onProgress == null
          ? null
          : (sent, total) {
              if (total > 0) onProgress(sent / total);
            },
    );
  });
}

final storageClientProvider = Provider<StorageClient>((ref) {
  // Uploads of a few megabytes on a mobile connection need more time than
  // API calls; the URL itself stays valid for ten minutes.
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(minutes: 3),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  ref.onDispose(dio.close);
  return StorageClient(dio);
});
