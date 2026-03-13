import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 상태 열거형
enum CaptureState {
  idle,      // 대기 중
  capturing, // 캡처 중
  paused,    // 일시정지
  finished,  // 완료
}

/// 컨트롤 버튼 위젯
class ControlButtons extends StatelessWidget {
  final CaptureState state;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onPause;
  final VoidCallback onSwitchCamera;
  final bool canSwitchCamera;

  const ControlButtons({
    super.key,
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.onPause,
    required this.onSwitchCamera,
    this.canSwitchCamera = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 카메라 전환 버튼
        _buildIconButton(
          icon: Icons.cameraswitch_rounded,
          onPressed: canSwitchCamera && state != CaptureState.capturing
              ? onSwitchCamera
              : null,
          tooltip: '카메라 전환',
        ),
        const SizedBox(width: 16),

        // 메인 버튼 (Start/Stop)
        _buildMainButton(),

        const SizedBox(width: 16),

        // 일시정지 버튼
        _buildIconButton(
          icon: state == CaptureState.paused
              ? Icons.play_arrow_rounded
              : Icons.pause_rounded,
          onPressed: state == CaptureState.capturing || state == CaptureState.paused
              ? onPause
              : null,
          tooltip: state == CaptureState.paused ? '재개' : '일시정지',
        ),
      ],
    );
  }

  Widget _buildMainButton() {
    IconData icon;
    String label;
    Color backgroundColor;
    VoidCallback? onPressed;

    switch (state) {
      case CaptureState.idle:
        icon = Icons.play_arrow_rounded;
        label = 'Start';
        backgroundColor = const Color(0xFF00D9A5);
        onPressed = onStart;
        break;
      case CaptureState.capturing:
      case CaptureState.paused:
        icon = Icons.stop_rounded;
        label = 'Stop';
        backgroundColor = const Color(0xFFFF6B6B);
        onPressed = onStop;
        break;
      case CaptureState.finished:
        icon = Icons.check_rounded;
        label = '출석완료';
        backgroundColor = const Color(0xFF00D9A5).withOpacity(0.5);
        onPressed = null;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: state == CaptureState.finished
              ? Colors.white
              : const Color(0xFF0D1B2A),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: state == CaptureState.finished ? 0 : 4,
        ),
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        opacity: onPressed != null ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF253449),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 28),
            color: Colors.white70,
            padding: const EdgeInsets.all(12),
          ),
        ),
      ),
    );
  }
}
