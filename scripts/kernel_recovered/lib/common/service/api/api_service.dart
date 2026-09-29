import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shortzz/common/manager/internet_connection_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/economy_state.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/utilities/const_res.dart';

class CancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void dispose() {
    _isCancelled = false;
  }
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  final Map<CancelToken, http.Client> _activeClients = {};

  Map<String, String> _maskHeaders(Map<String, String> headers) {
    final masked = <String, String>{};
    headers.forEach((k, v) {
      final key = k.toLowerCase();
      if (key.contains('authtoken') || key.contains('authorization') || key.contains('x-api-key')) {
        masked[k] = '***';
      } else {
        masked[k] = v;
      }
    });
    return masked;
  }

  Map<String, dynamic> _maskParams(Map<String, dynamic> params) {
    final masked = <String, dynamic>{};
    params.forEach((k, v) {
      final key = k.toLowerCase();
      if (key.contains('email') ||
          key.contains('mobile') ||
          key.contains('phone') ||
          key.contains('upi') ||
          key.contains('account_number') ||
          key.contains('bank_account_number') ||
          key.contains('paypal')) {
        masked[k] = '***';
      } else {
        masked[k] = v;
      }
    });
    return masked;
  }

  var header = {Params.apikey: apiKey};

  Future<T> get<T>({
    required String url,
    Map<String, dynamic>? param,
    CancelToken? cancelToken,
    bool cancelAuthToken = false,
    T Function(Map<String, dynamic> json)? fromJson,
    Function()? onError,
  }) async {
    // Save last action so NoInternetSheet can retry it.
    InternetConnectionManager.instance.retryLastAction = (String s, dynamic d) {
      ApiService.instance.get<T>(
        url: url,
        param: param,
        cancelToken: cancelToken,
        cancelAuthToken: cancelAuthToken,
        fromJson: fromJson,
        onError: onError,
      );
    };

    final client = http.Client();
    if (cancelToken != null && cancelToken.isCancelled) {
      _activeClients[cancelToken] = client;
    }

    Map<String, String> params = {};
    param?.removeWhere((key, value) => value == null || value == 'null' || value == '');
    param?.forEach((key, value) {
      params[key] = "$value";
    });

    final Map<String, String> requestHeaders = {
      Params.apikey: apiKey,
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    if (!cancelAuthToken) {
      requestHeaders[Params.authToken] = SessionManager.instance.getAuthToken();
    }

    final uri = Uri.parse(url).replace(queryParameters: params.isEmpty ? null : params);
    Loggers.info("URL: $uri");
    Loggers.info("header: $requestHeaders");
    Loggers.info("Parameters: ${params.isEmpty ? "Empty" : params}");
    try {
      http.Response response;
      int attempts = 0;
      while (true) {
        try {
          response = await client.get(uri, headers: requestHeaders);
          break;
        } on SocketException {
          if (attempts++ < 2) {
            await Future.delayed(Duration(milliseconds: 300 * attempts));
            continue;
          }
          rethrow;
        } on http.ClientException catch (e) {
          final msg = e.toString();
          if (attempts++ < 2 && msg.contains('Connection reset by peer')) {
            await Future.delayed(Duration(milliseconds: 300 * attempts));
            continue;
          }
          rethrow;
        }
      }
      Loggers.success(response.statusCode);

      if (cancelToken?.isCancelled ?? false) {
        if (kDebugMode) {
          Loggers.info("Request cancelled: $url");
        }
        throw Exception('Request was cancelled');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decodedResponse = jsonDecode(response.body) as Map<String, dynamic>;

        if (decodedResponse['message'] == 'this user is freezed!') {
          Loggers.error('User account is frozen');
          throw Exception('User account is frozen');
        }

        if (decodedResponse['status'] == false) {
          Loggers.error('API RESPONSE : ${decodedResponse['message']}');
          onError?.call();
        }

        if (kDebugMode) {
          final msg = '${decodedResponse['message'] ?? ''}';
          final safeMsg = msg.length > 120 ? '${msg.substring(0, 120)}…' : msg;
          Loggers.info(
            '[API_OK][GET] url=$url status=${decodedResponse['status']} message=$safeMsg keys=${decodedResponse.keys.length}',
          );
        }

        if (fromJson != null) {
          EconomyState.instance.ingestApi(decodedResponse);
          return fromJson(decodedResponse);
        }

        EconomyState.instance.ingestApi(decodedResponse);
        return decodedResponse as T;
      } else if (response.statusCode == 401) {
        Loggers.error('Unauthorized Error 401: ${response.statusCode}');
        throw Exception("Unauthorized Error: ${response.statusCode}");
      } else if (response.statusCode == 404) {
        Loggers.warning('404 Not Found: $url');
        throw Exception("URL Error: ${response.statusCode} - $url");
      } else {
        final errorBody = response.body;
        Loggers.error('HTTP Error ${response.statusCode}: $errorBody');
        throw Exception("HTTP Error: ${response.statusCode} - $errorBody");
      }
    } catch (e, st) {
      final msg = e.toString();
      if (msg.contains('URL Error: 404')) {
        // Known 404: avoid stacktrace spam; caller may have fallbacks
        Loggers.warning(msg);
      } else {
        Loggers.error(e);
        Loggers.error('ApiService.get stacktrace: $st');
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<T> call<T>({
    required String url,
    Map<String, dynamic>? param,
    CancelToken? cancelToken,
    bool cancelAuthToken = false,
    T Function(Map<String, dynamic> json)? fromJson,
    Function()? onError,
  }) async {
    // Save last action so NoInternetSheet can retry it.
    InternetConnectionManager.instance.retryLastAction = (String s, dynamic d) {
      ApiService.instance.call<T>(
        url: url,
        param: param,
        cancelToken: cancelToken,
        cancelAuthToken: cancelAuthToken,
        fromJson: fromJson,
        onError: onError,
      );
    };

    final client = http.Client();
    if (cancelToken != null && cancelToken.isCancelled) {
      _activeClients[cancelToken] = client;
    }

    final Map<String, dynamic> params = {};
    param?.forEach((key, value) {
      if (value == null) return;
      if (value is String) {
        final v = value.trim();
        if (v.isEmpty || v == 'null') return;
        params[key] = v;
        return;
      }
      if (value is List && value.isEmpty) return;
      if (value is Map && value.isEmpty) return;
      params[key] = value;
    });

    final Map<String, String> requestHeaders = {
      Params.apikey: apiKey,
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    if (!cancelAuthToken) {
      requestHeaders[Params.authToken] = SessionManager.instance.getAuthToken();
    }
    Loggers.info("URL: $url");
    Loggers.info("header: ${_maskHeaders(requestHeaders)}");
    Loggers.info("Parameters: ${params.isEmpty ? "Empty" : _maskParams(params)}");
    try {
      http.Response response;
      int attempts = 0;
      while (true) {
        try {
          response = await client.post(
            Uri.parse(url),
            headers: requestHeaders,
            body: jsonEncode(params),
          );
          break;
        } on SocketException {
          if (attempts++ < 2) {
            await Future.delayed(Duration(milliseconds: 300 * attempts));
            continue;
          }
          rethrow;
        } on http.ClientException catch (e) {
          final msg = e.toString();
          if (attempts++ < 2 && msg.contains('Connection reset by peer')) {
            await Future.delayed(Duration(milliseconds: 300 * attempts));
            continue;
          }
          rethrow;
        }
      }
      Loggers.success(response.statusCode);
      if (cancelToken?.isCancelled ?? false) {
        if (kDebugMode) {
          Loggers.info("Request cancelled: $url");
        }
        throw Exception('Request was cancelled');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decodedResponse =
            jsonDecode(response.body) as Map<String, dynamic>;

        if (decodedResponse['message'] == 'this user is freezed!') {
          Loggers.error('User account is frozen');
          throw Exception('User account is frozen');
        }

        if (decodedResponse['status'] == false) {
          Loggers.error('API RESPONSE : ${decodedResponse['message']}');
          onError?.call();
        }

        if (kDebugMode) {
          final msg = '${decodedResponse['message'] ?? ''}';
          final safeMsg = msg.length > 120 ? '${msg.substring(0, 120)}…' : msg;
          Loggers.info(
            '[API_OK][POST] url=$url status=${decodedResponse['status']} message=$safeMsg keys=${decodedResponse.keys.length}',
          );
        }

        // Use the provided `fromJson` function to parse the response
        if (fromJson != null) {
          // Global economy sync
          EconomyState.instance.ingestApi(decodedResponse);
          return fromJson(decodedResponse);
        }

        // If no `fromJson` is provided, return the raw response
        EconomyState.instance.ingestApi(decodedResponse);
        return decodedResponse as T;
      } else if (response.statusCode == 401) {
        Loggers.error('Unauthorized Error 401: ${response.statusCode}');
        throw Exception("Unauthorized Error: ${response.statusCode}");
      } else if (response.statusCode == 404) {
        Loggers.warning('404 Not Found: $url');
        throw Exception("URL Error: ${response.statusCode} - $url");
      } else {
        final errorBody = response.body;
        // Some backends incorrectly return 500 even on success.
        // If the body is a JSON map with `status:true`, treat it as success.
        try {
          final decoded = jsonDecode(errorBody);
          if (decoded is Map<String, dynamic>) {
            if (decoded['status'] == true) {
              EconomyState.instance.ingestApi(decoded);
              if (fromJson != null) {
                return fromJson(decoded);
              }
              return decoded as T;
            }
            final msg = decoded['message'] ?? decoded['error'] ?? response.reasonPhrase;
            Loggers.error('HTTP Error ${response.statusCode}: $msg');
            throw Exception('HTTP Error: ${response.statusCode} - $msg');
          }
        } catch (_) {
          // fallthrough to default handling
        }
        final errorMessage = _extractErrorMessage(errorBody);
        Loggers.error('HTTP Error: $errorMessage');
        throw Exception("HTTP Error: ${response.statusCode} - ${response.reasonPhrase}");
      }
    } on HttpException {
      throw Exception('Could not connect to the server');
    } on FormatException catch (e) {
      // Handle JSON decoding errors
      Loggers.error("Invalid JSON format: ${e.message}");
      throw Exception("Invalid JSON format: ${e.message}");
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('URL Error: 404')) {
        // Known 404: reduce noise; higher-level code may fall back
        Loggers.warning(msg);
        rethrow;
      }
      Loggers.error("Unexpected error : $e");
      rethrow;
    } finally {
      _cleanupClient(cancelToken);
    }
  }

  String _extractErrorMessage(String responseBody) {
    final regex = RegExp(
      r'<!--\s*(.*?)\s*#0 ', // Matches everything between <!-- and #0
      dotAll: true,
    );
    final match = regex.firstMatch(responseBody);
    return match?.group(1)?.trim() ??
        "Unknown error occurred: ${_shorten(responseBody)}";
  }

  /// Shortens the response body if no specific error is found
  String _shorten(String responseBody) {
    const maxLength = 100;
    return responseBody.length > maxLength
        ? "${responseBody.substring(0, maxLength)}..."
        : responseBody;
  }

  Future<T> callGet<T>({required String url}) async {
    http.Response response = await http.get(Uri.parse(url));
    return jsonDecode(response.body);
  }

  Future<T> multiPartCallApi<T>({
    required String url,
    Map<String, dynamic>? param,
    required Map<String, List<XFile?>> filesMap,
    Function(double percentage)? onProgress,
    CancelToken? cancelToken,
    T Function(Map<String, dynamic> json)? fromJson,
  }) async {
    // Save last action so NoInternetSheet can retry it.
    InternetConnectionManager.instance.retryLastAction = (String s, dynamic d) {
      ApiService.instance.multiPartCallApi<T>(
        url: url,
        param: param,
        filesMap: filesMap,
        onProgress: onProgress,
        cancelToken: cancelToken,
        fromJson: fromJson,
      );
    };

    final client = http.Client();
    if (cancelToken != null) {
      _activeClients[cancelToken] = client;
    }

    final request = MultipartRequest(
      'POST',
      Uri.parse(url),
      onProgress: (bytes, totalBytes) {
        if (onProgress != null) {
          onProgress(bytes / totalBytes);
        }
      },
    );

    Map<String, String> params = {};
    param?.removeWhere((key, value) => value == null || value == 'null');
    param?.forEach((key, value) {
      params[key] = "$value";
    });

    request.fields.addAll(params);
    request.headers.addAll({Params.apikey: apiKey});
    request.headers[Params.authToken] = SessionManager.instance.getAuthToken();

    filesMap.forEach((keyName, files) {
      for (var xFile in files) {
        if (xFile != null && xFile.path.isNotEmpty) {
          final file = File(xFile.path);
          final multipartFile = http.MultipartFile(
              keyName, file.readAsBytes().asStream(), file.lengthSync(),
              filename: xFile.name);
          request.files.add(multipartFile);
        }
      }
    });
    Loggers.info("URL : $url");
    Loggers.info("HEADERS : ${_maskHeaders(request.headers)}");
    Loggers.info("FIELDS : ${_maskParams(request.fields)}");
    Loggers.info("FILES : ${request.files.map((e) => e)}");

    try {
      final responseStream = await client.send(request);

      if (cancelToken?.isCancelled ?? false) {
        if (kDebugMode) {
          Loggers.error("Request cancelled: $url");
        }
        throw Exception('Request was cancelled');
      }

      final responseStr = await responseStream.stream.bytesToString();
      final statusCode = responseStream.statusCode;
      final contentType = (responseStream.headers['content-type'] ?? '').toLowerCase();

      Loggers.info('[MULTIPART_RESPONSE] status=$statusCode content-type=$contentType url=$url');

      Map<String, dynamic> decodedResponse;
      try {
        decodedResponse = jsonDecode(responseStr) as Map<String, dynamic>;
      } on FormatException catch (e) {
        final snippet = responseStr.length > 300 ? responseStr.substring(0, 300) : responseStr;
        Loggers.error(
          '[MULTIPART_INVALID_JSON] url=$url status=$statusCode content-type=$contentType error=${e.message} snippet=${snippet.replaceAll('\n', ' ')}',
        );
        throw Exception(
          'Invalid server response. status=$statusCode content-type=$contentType snippet=${snippet.replaceAll('\n', ' ')}',
        );
      }

      if (kDebugMode) {
        // Loggers.info(responseStr);
      }

      if (statusCode >= 400) {
        final msg = decodedResponse['message'] ?? decodedResponse['error'] ?? 'HTTP $statusCode';
        Loggers.error('[MULTIPART_HTTP_ERROR] status=$statusCode url=$url message=$msg');
        Loggers.error(
          '[MULTIPART_HTTP_ERROR_BODY] ${responseStr.length > 600 ? responseStr.substring(0, 600) : responseStr}',
        );
      }

      if (decodedResponse['status'] == false) {
        final msg = decodedResponse['message'] ?? decodedResponse['error'] ?? 'Request failed';
        Loggers.error('[MULTIPART_API_STATUS_FALSE] status=$statusCode url=$url message=$msg');
        Loggers.error(
          '[MULTIPART_API_STATUS_FALSE_BODY] ${responseStr.length > 600 ? responseStr.substring(0, 600) : responseStr}',
        );
      }
      // Use the provided `fromJson` function to parse the response
      if (fromJson != null) {
        // Global economy sync
        EconomyState.instance.ingestApi(decodedResponse);
        return fromJson(decodedResponse);
      }

      // If no `fromJson` is provided, return the raw response
      EconomyState.instance.ingestApi(decodedResponse);
      return decodedResponse as T;
    } finally {
      _cleanupClient(cancelToken);
    }
  }

  void _cleanupClient(CancelToken? cancelToken) {
    if (cancelToken != null) {
      _activeClients[cancelToken]?.close();
      _activeClients.remove(cancelToken);
    }
  }

  Future<void> useAndDeleteFile(File file) async {
    try {
      // Use the file as needed
      Loggers.warning('File path: ${file.path}');

      // Delete the file after use
      if (await file.exists()) {
        await file.delete();
        Loggers.success('File deleted from: ${file.path}');
      }
    } catch (e) {
      Loggers.error('Error: $e');
    }
  }
}

class MultipartRequest extends http.MultipartRequest {
  MultipartRequest(
    super.method,
    super.url, {
    this.onProgress,
  });

  final void Function(int bytes, int totalBytes)? onProgress;

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final total = contentLength;
    int bytes = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytes += data.length;
        if (onProgress != null) {
          onProgress!(bytes, total);
        }
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}
