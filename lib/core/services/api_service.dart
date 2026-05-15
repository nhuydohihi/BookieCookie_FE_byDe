// lib/core/services/api_service.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000/api';
  static const Duration _timeout = Duration(seconds: 12);

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
          .timeout(_timeout);

      return _parseResponse(response);
    } on TimeoutException {
      throw const ApiException(
        'Server phản hồi quá lâu. Hãy kiểm tra backend đang chạy và thử lại.',
      );
    } on SocketException {
      throw const ApiException(
        'Không kết nối được tới server. Nếu đang dùng Android emulator hãy chạy backend ở cổng 5000.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Kết nối mạng tới server thất bại. Hãy thử lại sau.',
      );
    } on FormatException {
      throw const ApiException(
        'Server trả về dữ liệu không hợp lệ. Hãy kiểm tra backend đang chạy đúng API JSON.',
      );
    }
  }

  Future<Map<String, dynamic>> getByUrl(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(_timeout);

      return _parseResponse(response);
    } on TimeoutException {
      throw const ApiException(
        'Yeu cau toi dich vu sach online qua lau. Hay thu lai sau.',
      );
    } on SocketException {
      throw const ApiException(
        'Khong the ket noi toi Google Books API. Hay kiem tra mang va thu lai.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Ket noi toi Google Books API that bai. Hay thu lai sau.',
      );
    } on FormatException {
      throw const ApiException(
        'Google Books API tra ve du lieu khong hop le.',
      );
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
    {Map<String, String>? headers}
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              ...?headers,
            },
            body: jsonEncode(data),
          )
          .timeout(_timeout);

      return _parseResponse(response);
    } on TimeoutException {
      throw const ApiException(
        'Server phản hồi quá lâu. Hãy kiểm tra backend đang chạy và thử lại.',
      );
    } on SocketException {
      throw const ApiException(
        'Không kết nối được tới server. Nếu đang dùng Android emulator hãy chạy backend ở cổng 5000.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Kết nối mạng tới server thất bại. Hãy thử lại sau.',
      );
    } on FormatException {
      throw const ApiException(
        'Server trả về dữ liệu không hợp lệ. Hãy kiểm tra backend đang chạy đúng API JSON.',
      );
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    String? fileField,
    String? filePath,
    Map<String, String>? headers,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      )
        ..headers.addAll(headers ?? {})
        ..fields.addAll(fields);

      if (fileField != null &&
          filePath != null &&
          filePath.trim().isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
      }

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _parseResponse(response);
    } on TimeoutException {
      throw const ApiException(
        'Server phản hồi quá lâu. Hãy kiểm tra backend đang chạy và thử lại.',
      );
    } on SocketException {
      throw const ApiException(
        'Không kết nối được tới server. Nếu đang dùng Android emulator hãy chạy backend ở cổng 5000.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Kết nối mạng tới server thất bại. Hãy thử lại sau.',
      );
    } on FormatException {
      throw const ApiException(
        'Server trả về dữ liệu không hợp lệ. Hãy kiểm tra backend đang chạy đúng API JSON.',
      );
    }
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    final dynamic decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    final result = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return result;
    }

    if (response.statusCode == 429) {
      throw const ApiException(
        'Dich vu sach online dang gioi han qua nhieu yeu cau. Hay doi mot luc roi thu lai.',
      );
    }

    throw ApiException(
      result['message'] as String? ?? 'Server trả về lỗi ${response.statusCode}.',
    );
  }
}
