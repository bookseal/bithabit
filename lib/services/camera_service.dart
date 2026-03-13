// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';

/// 웹캠 접근 및 제어를 담당하는 서비스
class CameraService {
  html.VideoElement? _videoElement;
  html.MediaStream? _stream;
  String _currentFacingMode = 'environment';
  bool _isInitialized = false;
  
  final String _viewId = 'camera-view-${DateTime.now().millisecondsSinceEpoch}';

  /// 뷰 ID 반환 (HtmlElementView에서 사용)
  String get viewId => _viewId;

  /// 초기화 여부 확인
  bool get isInitialized => _isInitialized;

  /// 비디오 요소 반환
  html.VideoElement? get videoElement => _videoElement;

  /// 모바일 기기 여부 확인
  bool _isMobileDevice() {
    final userAgent = html.window.navigator.userAgent;
    return RegExp(r'Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini', 
        caseSensitive: false).hasMatch(userAgent);
  }

  /// 카메라 초기화
  Future<void> initialize() async {
    try {
      // 브라우저 지원 확인
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('브라우저가 카메라 접근을 지원하지 않습니다.');
      }

      // 비디오 요소 생성
      _videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)'; // 거울 효과

      // HtmlElementView 등록
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => _videoElement!,
      );

      // 모바일에서는 후면 카메라, 데스크탑에서는 전면 카메라
      _currentFacingMode = _isMobileDevice() ? 'environment' : 'user';

      // 카메라 스트림 가져오기
      await _startStream();

      _isInitialized = true;
      debugPrint('카메라 초기화 성공');
    } catch (e) {
      debugPrint('카메라 초기화 오류: $e');
      rethrow;
    }
  }

  /// 카메라 스트림 시작
  Future<void> _startStream() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('미디어 장치를 사용할 수 없습니다.');
      }

      _stream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': _currentFacingMode,
        },
        'audio': false,
      });

      if (_videoElement != null && _stream != null) {
        _videoElement!.srcObject = _stream;
        await _videoElement!.play();
      }
    } on html.DomException catch (e) {
      String errorMessage;
      if (e.name == 'NotAllowedError') {
        errorMessage = '카메라 권한을 허용해주세요.';
      } else if (e.name == 'NotFoundError') {
        errorMessage = '카메라를 찾을 수 없습니다.';
      } else if (e.name == 'NotSupportedError') {
        errorMessage = '브라우저가 카메라를 지원하지 않습니다.';
      } else {
        errorMessage = '카메라 오류: ${e.message}';
      }
      throw Exception(errorMessage);
    }
  }

  /// 카메라 전환 (전면 <-> 후면)
  Future<void> switchCamera() async {
    _currentFacingMode = _currentFacingMode == 'user' ? 'environment' : 'user';
    
    // 기존 스트림 중지
    _stopStream();
    
    // 새 스트림 시작
    await _startStream();
  }

  /// 스트림 중지
  void _stopStream() {
    if (_stream != null) {
      _stream!.getTracks().forEach((track) => track.stop());
      _stream = null;
    }
  }

  /// 카메라 종료
  void dispose() {
    _stopStream();
    _videoElement?.pause();
    _videoElement = null;
    _isInitialized = false;
  }

  /// 현재 프레임 캡처 (Canvas로 그리기 위한 데이터 반환)
  Map<String, dynamic>? captureFrame() {
    if (_videoElement == null || !_isInitialized) return null;

    return {
      'videoElement': _videoElement,
      'videoWidth': _videoElement!.videoWidth,
      'videoHeight': _videoElement!.videoHeight,
    };
  }
}
