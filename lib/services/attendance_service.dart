import 'package:http/http.dart' as http;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Google Sheets로 출석 데이터를 전송하는 서비스
class AttendanceService {
  // Google Apps Script 웹앱 URL
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbz8xJpNZmECdex3fcykRQEyQ_UpHzYDe3vKl_nNGC1ELgA0JWzwLRbdaaCKuccZ4h8Lxg/exec';

  /// 출석 데이터를 Google Sheets로 전송
  /// 
  /// [id] - 사용자 ID
  /// [dailyGoal] - 오늘의 목표
  /// [startTime] - 시작 시간
  /// [durationMs] - 공부 시간 (밀리초)
  Future<bool> submitAttendance({
    required String id,
    required String dailyGoal,
    required DateTime startTime,
    required int durationMs,
  }) async {
    if (id.isEmpty) {
      throw Exception('ID를 입력해주세요.');
    }

    final formData = _prepareFormData(
      id: id,
      dailyGoal: dailyGoal,
      startTime: startTime,
      durationMs: durationMs,
    );

    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        body: formData,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('출석 체크 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('출석 체크 중 오류 발생: $e');
    }
  }

  /// 폼 데이터 준비
  Map<String, String> _prepareFormData({
    required String id,
    required String dailyGoal,
    required DateTime startTime,
    required int durationMs,
  }) {
    return {
      'id': id.toLowerCase(),
      'dailyGoal': dailyGoal,
      'in': startTime.toIso8601String(),
      'duration': (durationMs / 1000 / 60).round().toString(), // 분 단위
      'device': _getDeviceInfo(),
      'browser': _getBrowserInfo(),
    };
  }

  /// 디바이스 정보 가져오기
  String _getDeviceInfo() {
    return html.window.navigator.platform ?? 'Unknown Device';
  }

  /// 브라우저 정보 가져오기
  String _getBrowserInfo() {
    return html.window.navigator.userAgent;
  }
}
