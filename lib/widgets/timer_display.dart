import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 타이머 표시 위젯
class TimerDisplay extends StatelessWidget {
  final String duration;
  final bool isBlinking;
  final bool isRecording;

  const TimerDisplay({
    super.key,
    required this.duration,
    this.isBlinking = false,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isBlinking ? 0.3 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isRecording
                ? [
                    const Color(0xFF1B263B).withOpacity(0.9),
                    const Color(0xFF253449).withOpacity(0.9),
                  ]
                : [
                    const Color(0xFF253449).withOpacity(0.7),
                    const Color(0xFF253449).withOpacity(0.5),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRecording
                ? const Color(0xFF00D9A5).withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: isRecording ? 2 : 1,
          ),
          boxShadow: isRecording
              ? [
                  BoxShadow(
                    color: const Color(0xFF00D9A5).withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '진행 시간',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white60,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              duration,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: isRecording
                    ? const Color(0xFF00D9A5)
                    : Colors.white,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
