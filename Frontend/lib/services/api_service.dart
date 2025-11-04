import 'dart:convert';
import 'package:http/http.dart' as http;

/// TODO: 把 baseUrl 换成你后端的地址
const String baseUrl = 'http://localhost:8080';

class ApiService {
  static Future<Map<String, dynamic>> register(String email, String password) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> sendVerification(String email) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/send-verification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> verifyCode(String email, String code) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/request-reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return _parseResponse(resp);
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code, 'newPassword': newPassword}),
    );
    return _parseResponse(resp);
  }

  static Map<String, dynamic> _parseResponse(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      return {
        'statusCode': resp.statusCode,
        'body': body,
      };
    } catch (e) {
      return {
        'statusCode': resp.statusCode,
        'body': {'message': 'Invalid response from server'},
      };
    }
  }
}
