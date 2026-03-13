import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// 카메라 프리뷰 위젯
class CameraPreview extends StatelessWidget {
  final String viewId;
  final bool isRecording;

  const CameraPreview({
    super.key,
    required this.viewId,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isRecording 
                ? const Color(0xFFFF6B6B).withOpacity(0.3)
                : Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: isRecording ? 2 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            children: [
              // 카메라 프리뷰
              Positioned.fill(
                child: HtmlElementView(viewType: viewId),
              ),
              // 녹화 중 표시
              if (isRecording)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _RecordingIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 녹화 중 표시 위젯
class _RecordingIndicator extends StatefulWidget {
  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xFFFF6B6B),
                    const Color(0xFFFF6B6B).withOpacity(0.3),
                    _controller.value,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'REC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
