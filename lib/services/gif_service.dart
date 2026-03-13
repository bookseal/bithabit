// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/formatters.dart';

/// GIF 생성 및 다운로드를 담당하는 서비스
class GifService {
  /// GIF 생성 진행률 콜백
  Function(double)? onProgress;

  /// GIF 생성 (폴링 방식)
  Future<String?> createGif(List<String> imageDataUrls) async {
    if (imageDataUrls.isEmpty) {
      debugPrint('[GIF] ❌ 캡처된 이미지가 없습니다.');
      return null;
    }

    try {
      debugPrint('[GIF] 🚀 GIF 생성 시작: ${imageDataUrls.length}장');

      // 상태 초기화
      js.context.callMethod('eval', ['''
        window._gifState = {
          progress: 0,
          complete: false,
          result: null,
          error: null
        };
      ''']);

      // JavaScript 실행 (콜백 없이 전역 변수에 결과 저장)
      final script = html.ScriptElement()
        ..text = '''
          (function() {
            console.log('[JS GIF] 🚀 시작');
            
            try {
              var container = document.getElementById('_bithabit_captured_images');
              if (!container) {
                console.log('[JS GIF] ❌ 이미지 컨테이너 없음');
                window._gifState.error = 'No image container';
                window._gifState.complete = true;
                return;
              }
              
              var images = container.querySelectorAll('img._captured_img');
              console.log('[JS GIF] 📦 이미지:', images.length + '장');
              
              if (images.length === 0) {
                window._gifState.error = 'No images';
                window._gifState.complete = true;
                return;
              }
              
              var firstImage = images[0];
              console.log('[JS GIF] 📐 크기:', firstImage.naturalWidth + 'x' + firstImage.naturalHeight);
              
              var gif = new GIF({
                workers: 2,
                quality: 10,
                width: firstImage.naturalWidth,
                height: firstImage.naturalHeight,
                workerScript: 'gif.worker.js'
              });
              
              gif.addFrame(images[0], {delay: 1000});
              var step = images.length >= 70 ? 2 : 1;
              for (var j = images.length - 1; j >= 0; j -= step) {
                gif.addFrame(images[j], {delay: 300});
              }
              console.log('[JS GIF] ✓ 프레임 추가 완료');
              
              gif.on('progress', function(p) {
                window._gifState.progress = p;
                console.log('[JS GIF] 📊 ' + Math.round(p * 100) + '%');
              });
              
              gif.on('finished', function(blob) {
                console.log('[JS GIF] ✅ 완료! ' + blob.size + ' bytes');
                var reader = new FileReader();
                reader.onloadend = function() {
                  window._gifState.result = reader.result;
                  window._gifState.complete = true;
                  console.log('[JS GIF] 📤 DataURL 준비 완료');
                };
                reader.readAsDataURL(blob);
              });
              
              console.log('[JS GIF] 🎥 렌더링 시작...');
              gif.render();
              
            } catch(e) {
              console.log('[JS GIF] ❌ 예외:', e);
              window._gifState.error = e.toString();
              window._gifState.complete = true;
            }
          })();
        ''';

      html.document.body?.append(script);
      script.remove();

      // 폴링으로 결과 확인
      final result = await _pollForResult();
      return result;

    } catch (e, stackTrace) {
      debugPrint('[GIF] ❌ 예외: $e');
      debugPrint('[GIF] 스택: $stackTrace');
      return null;
    }
  }

  /// 폴링으로 GIF 생성 결과 확인
  Future<String?> _pollForResult() async {
    const maxWaitTime = Duration(minutes: 5);
    const pollInterval = Duration(milliseconds: 500);
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < maxWaitTime) {
      await Future.delayed(pollInterval);

      try {
        // 진행률 확인
        final progress = js.context.callMethod('eval', ['window._gifState.progress']) as num?;
        if (progress != null) {
          onProgress?.call(progress.toDouble());
        }

        // 완료 여부 확인
        final complete = js.context.callMethod('eval', ['window._gifState.complete']) as bool?;
        if (complete == true) {
          // 에러 확인
          final error = js.context.callMethod('eval', ['window._gifState.error']);
          if (error != null) {
            debugPrint('[GIF] ❌ 에러: $error');
            return null;
          }

          // 결과 확인
          final result = js.context.callMethod('eval', ['window._gifState.result']) as String?;
          if (result != null) {
            debugPrint('[GIF] ✅ 결과 수신 완료');
            return result;
          }
        }
      } catch (e) {
        debugPrint('[GIF] 폴링 오류: $e');
      }
    }

    debugPrint('[GIF] ⏰ 시간 초과');
    return null;
  }

  /// GIF 다운로드
  void downloadGif(String dataUrl, {String? fileName}) {
    final now = DateTime.now();
    final name = fileName ?? 'BitHabit-${formatDateTimeForFile(now)}.gif';
    
    final anchor = html.AnchorElement(href: dataUrl)
      ..setAttribute('download', name)
      ..style.display = 'none';
    
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    
    debugPrint('[GIF] 📥 다운로드: $name');
  }

  /// 프리뷰 URL
  String? getPreviewUrl(List<String> imageDataUrls) {
    if (imageDataUrls.isEmpty) return null;
    return imageDataUrls.last;
  }
}
