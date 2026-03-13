// API service with JWT token management
// Handles: auth, messages, token refresh, auto-login
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// API 서비스 클래스 (JWT 토큰 관리 포함)
class ApiService {
  // 토큰 저장 키
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';

  // 백엔드 URL
  static String get baseUrl {
    final host = html.window.location.host;
    final protocol = html.window.location.protocol;
    return '$protocol//$host/api';
  }

  // ============ 토큰 관리 ============

  /// 저장된 access_token 가져오기
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  /// 토큰 저장
  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
  }

  /// 토큰 삭제 (로그아웃)
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove('user_id');
    await prefs.remove('username');
  }

  /// Authorization 헤더 생성
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 자동 로그인 시도: 토큰 유효하면 유저 정보 반환, 아니면 null
  static Future<Map<String, dynamic>?> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_keyAccessToken);
    if (accessToken == null) return null;

    // access_token으로 /auth/me 호출
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    // access_token 만료 → refresh_token으로 갱신
    final refreshToken = prefs.getString(_keyRefreshToken);
    if (refreshToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(data['access_token'], data['refresh_token']);
        await prefs.setInt('user_id', data['user']['id']);
        await prefs.setString('username', data['user']['username']);
        return data['user'];
      }
    } catch (_) {}

    // 둘 다 실패 → 토큰 정리
    await clearTokens();
    return null;
  }

  // ============ 인증 API ============

  /// 회원가입 (닉네임 + 이메일)
  static Future<Map<String, dynamic>> register(
      String username, String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '회원가입 실패');
    }
  }

  /// OTP 발송
  static Future<void> sendOtp(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'OTP 발송 실패');
    }
  }

  /// OTP 검증 → JWT 토큰 수신 + 저장
  static Future<Map<String, dynamic>> verifyOtp(
      String email, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // JWT 토큰 저장
      await saveTokens(data['access_token'], data['refresh_token']);
      return data['user'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '인증 실패');
    }
  }

  // ============ 메시지 API ============

  /// 메시지 목록 조회
  static Future<List<Map<String, dynamic>>> getMessages({int? beforeId}) async {
    var url = '$baseUrl/messages?limit=50';
    if (beforeId != null) url += '&before_id=$beforeId';

    final headers = await _authHeaders();
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('메시지 조회 실패');
    }
  }

  /// 메시지 전송 (GIF base64 포함 가능)
  static Future<Map<String, dynamic>> sendMessage({
    required int userId,
    String? text,
    String? gifBase64,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/messages'));

    // JWT 토큰 첨부
    final token = await getAccessToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.fields['user_id'] = userId.toString();
    if (text != null) request.fields['text'] = text;
    if (gifBase64 != null) request.fields['gif_base64'] = gifBase64;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '메시지 전송 실패');
    }
  }

  /// WebSocket URL
  static String get wsUrl {
    final host = html.window.location.host;
    final protocol =
        html.window.location.protocol == 'https:' ? 'wss:' : 'ws:';
    return '$protocol//$host/api/ws';
  }
}
