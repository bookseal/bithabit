// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/formatters.dart';

/// 이미지 캡처 및 오버레이 처리를 담당하는 서비스
class CaptureService {
  final List<String> _capturedImages = [];
  Timer? _captureTimer;
  bool _isCapturing = false;
  bool _isPaused = false;
  html.DivElement? _imageContainer;

  /// 캡처 간격 (초)
  static const int captureIntervalSeconds = 40;

  /// 캡처된 이미지 목록
  List<String> get capturedImages => List.unmodifiable(_capturedImages);

  /// 캡처 중인지 확인
  bool get isCapturing => _isCapturing;

  /// 일시정지 상태인지 확인
  bool get isPaused => _isPaused;

  /// 캡처된 이미지 수
  int get capturedCount => _capturedImages.length;

  /// DOM 컨테이너 초기화
  void _initContainer() {
    // 기존 컨테이너 제거
    _imageContainer?.remove();
    
    // 새 컨테이너 생성
    _imageContainer = html.DivElement()
      ..id = '_bithabit_captured_images'
      ..style.display = 'none';
    html.document.body?.append(_imageContainer!);
    debugPrint('[Capture] 📦 이미지 컨테이너 초기화');
  }

  /// DOM에 이미지 추가
  void _addImageToContainer(String imageDataUrl) {
    if (_imageContainer == null) return;
    
    final img = html.ImageElement()
      ..src = imageDataUrl
      ..className = '_captured_img';
    _imageContainer!.append(img);
  }

  /// 캡처 시작
  void startCapturing({
    required html.VideoElement videoElement,
    required String userId,
    required String dailyGoal,
    required VoidCallback onCapture,
    required String Function() getDuration,
  }) {
    if (_isCapturing) return;

    _isCapturing = true;
    _isPaused = false;
    _capturedImages.clear();
    _initContainer();

    // 시작 시 즉시 캡처
    _captureImage(
      videoElement: videoElement,
      userId: userId,
      dailyGoal: dailyGoal,
      getDuration: getDuration,
    );
    onCapture();

    // 주기적 캡처 시작
    _captureTimer = Timer.periodic(
      Duration(seconds: captureIntervalSeconds),
      (_) {
        if (!_isPaused) {
          _captureImage(
            videoElement: videoElement,
            userId: userId,
            dailyGoal: dailyGoal,
            getDuration: getDuration,
          );
          onCapture();
        }
      },
    );
  }

  /// 캡처 일시정지/재개
  void togglePause() {
    _isPaused = !_isPaused;
  }

  /// 캡처 중지
  void stopCapturing({
    html.VideoElement? videoElement,
    String? userId,
    String? dailyGoal,
    String Function()? getDuration,
  }) {
    if (!_isCapturing) return;

    // 종료 시 마지막 캡처
    if (videoElement != null && userId != null && dailyGoal != null && getDuration != null) {
      _captureImage(
        videoElement: videoElement,
        userId: userId,
        dailyGoal: dailyGoal,
        getDuration: getDuration,
      );
    }

    _captureTimer?.cancel();
    _captureTimer = null;
    _isCapturing = false;
    _isPaused = false;
    
    debugPrint('[Capture] ✅ 캡처 완료: ${_capturedImages.length}장');
  }

  /// 이미지 캡처 및 오버레이 추가
  void _captureImage({
    required html.VideoElement videoElement,
    required String userId,
    required String dailyGoal,
    required String Function() getDuration,
  }) {
    if (_isPaused) return;

    try {
      final videoWidth = videoElement.videoWidth;
      final videoHeight = videoElement.videoHeight;

      if (videoWidth == 0 || videoHeight == 0) return;

      // 스케일 계산 (240x320에 맞추기)
      final scaleFactor = _calculateScaleFactor(videoWidth, videoHeight);
      final newWidth = (videoWidth * scaleFactor).floor();
      final newHeight = (videoHeight * scaleFactor).floor();

      // 캔버스 생성
      final canvas = html.CanvasElement(width: newWidth, height: newHeight);
      final context = canvas.context2D;

      // 비디오 프레임 그리기 (좌우 반전)
      context.save();
      context.translate(newWidth.toDouble(), 0);
      context.scale(-1, 1);
      context.drawImageScaled(videoElement, 0, 0, newWidth, newHeight);
      context.restore();

      // 오버레이 그리기
      _drawOverlay(
        context: context,
        width: newWidth,
        height: newHeight,
        userId: userId,
        dailyGoal: dailyGoal,
        duration: getDuration(),
      );

      // 이미지 데이터 저장
      final imageDataUrl = canvas.toDataUrl('image/jpeg', 0.8);
      _capturedImages.add(imageDataUrl);
      _addImageToContainer(imageDataUrl);

      // 최대 200장까지만 유지
      if (_capturedImages.length > 200) {
        _capturedImages.removeAt(0);
        // DOM에서도 첫 번째 이미지 제거
        _imageContainer?.children.first.remove();
      }

      debugPrint('[Capture] 📸 이미지 캡처: ${_capturedImages.length}장');
    } catch (e) {
      debugPrint('[Capture] ❌ 캡처 오류: $e');
    }
  }

  /// 스케일 팩터 계산
  double _calculateScaleFactor(int videoWidth, int videoHeight) {
    const maxWidth = 240;
    const maxHeight = 320;
    return [maxWidth / videoWidth, maxHeight / videoHeight]
        .reduce((a, b) => a < b ? a : b);
  }

  /// 오버레이 그리기
  void _drawOverlay({
    required html.CanvasRenderingContext2D context,
    required int width,
    required int height,
    required String userId,
    required String dailyGoal,
    required String duration,
  }) {
    const barHeight = 40;
    final centerY = (height - barHeight) / 2;
    final bottomY = height - 2;

    // 상단 반투명 바 (목표)
    context.globalAlpha = 0.5;
    context.fillStyle = 'white';
    context.fillRect(0, 0, width, barHeight);

    // 중앙 반투명 바 (사용자 정보)
    context.fillRect(0, centerY, width.toDouble(), barHeight.toDouble());
    context.globalAlpha = 1.0;

    // 폰트 설정
    context.font = '12px "Helvetica Neue", Arial, sans-serif';
    context.fillStyle = 'black';

    // 상단: 목표
    context.textAlign = 'center';
    context.fillText('Goal: $dailyGoal', width / 2, barHeight / 2 + 4);

    // 중앙 좌측: 진행 시간
    context.textAlign = 'left';
    context.fillText(duration, 3, centerY + barHeight / 2 + 4);

    // 중앙 가운데: 사용자 ID
    context.textAlign = 'center';
    context.fillText(userId, width / 2, centerY + barHeight / 2 + 4);

    // 중앙 우측: 브랜드
    context.textAlign = 'right';
    context.font = '10px "Helvetica Neue", Arial, sans-serif';
    context.fillText('BitHabit', width - 3, centerY + barHeight / 2 + 4);

    // 하단: 날짜/시간
    final now = DateTime.now();
    final dateTimeText = '${formatDate(now)} ${formatDateTime(now)}';
    context.font = '10px "Helvetica Neue", Arial, sans-serif';
    context.textAlign = 'center';
    context.fillStyle = 'white';
    context.strokeStyle = 'black';
    context.lineWidth = 1;
    context.strokeText(dateTimeText, width / 2, bottomY.toDouble());
    context.fillText(dateTimeText, width / 2, bottomY.toDouble());
  }

  /// 캡처된 이미지 초기화
  void clearImages() {
    _capturedImages.clear();
    _imageContainer?.innerHtml = '';
  }

  /// 리소스 정리
  void dispose() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _capturedImages.clear();
    _imageContainer?.remove();
    _imageContainer = null;
    _isCapturing = false;
    _isPaused = false;
  }
}
