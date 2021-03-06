import 'dart:async';
import 'dart:convert';

import 'package:dart_http/dart_http.dart';
import 'package:http/http.dart' as http;

import 'package:dart_http/src/http_exception.dart';

/// HTTP Request method as enum for integrity
enum HTTPMethod {
  get,
  post,
  delete,
  put,
}

class HTTPRequest {
  static int _requestId = 0;
  var client = http.Client();

  Future<http.Response> sendRequest(
      HTTPMethod requestMethod, String absolutePath,
      {dynamic body,
      Map<String, dynamic> params,
      Map<String, dynamic> headers,
      bool isUrlEncoded = false,
      Duration timeout = const Duration(seconds: 20)}) async {
    assert(requestMethod != HTTPMethod.post ||
        (requestMethod == HTTPMethod.post &&
            body != null &&
            (body is String || body is List || body is Map)));

    var httpMethod = requestMethod.toString().split(".")[1].toUpperCase();

    var apiUri = Uri.parse(absolutePath);
    var uri = Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      path: apiUri.path,
      queryParameters: params,
    );

    var request = http.Request(httpMethod, uri);
    request.headers['Content-Type'] = 'application/json';

    if (headers != null) {
      headers.forEach(
        (key, value) => () {
              request.headers[key] = value;
            },
      );
    }

    if (body != null) {
      if (!isUrlEncoded) {
        body = json.encoder.convert(body);
      }

      if (body is String) {
        request.body = body;
      } else if (body is List) {
        request.bodyBytes = List.castFrom(body);
      } else if (body is Map) {
        /// headers 'Content-Type' will be overriden
        /// see https://github.com/dart-lang/http/blob/ffe786a872c0d443cc4fa6baa923d69059b66399/lib/src/client.dart#L60-L62
        request.bodyFields = Map.castFrom(body);
      } else {
        throw new ArgumentError(
            'Invalid request body type "${body.toString()}".');
      }
    }

    var timer = Stopwatch();
    var currentRequestId = _requestId++;
    _preRequestLog(currentRequestId, timer,
        "[$currentRequestId] > $httpMethod ${uri.toString()}");

    var req = await client.send(request).timeout(timeout, onTimeout: () {
      _postResponseLog(currentRequestId, timer,
          "[$currentRequestId] < Timeout after ${timeout}s!");
      throw RequestTimeoutException(message: "Timeout Limit Exceeded");
    });

    var response = await http.Response.fromStream(req);

    _postResponseLog(currentRequestId, timer,
        "[$currentRequestId] < ${response.statusCode} ${response.body}");

    return response;
  }

  void _preRequestLog(int requestId, Stopwatch timer, String logMessage) {
    assert(() {
      timer.start();
      print(logMessage);
      return true;
    }());
  }

  void _postResponseLog(int requestId, Stopwatch timer, String logMessage) {
    assert(() {
      timer.stop();
      var elapsedMiliseconds = timer.elapsedMilliseconds;
      print(logMessage);
      print("[$requestId] < Took ${elapsedMiliseconds}ms");
      return true;
    }());
  }
}
