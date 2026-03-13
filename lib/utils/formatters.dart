/// 날짜/시간 포맷팅 유틸리티 함수들

/// 숫자를 2자리 문자열로 변환 (앞에 0 패딩)
String padZero(int num) {
  return num.toString().padLeft(2, '0');
}

/// 밀리초를 HH:MM:SS 형식으로 변환
String formatDuration(int? ms) {
  if (ms == null) return '00:00:00';
  final totalSeconds = (ms / 1000).floor();
  final hours = (totalSeconds / 3600).floor();
  final minutes = ((totalSeconds % 3600) / 60).floor();
  final seconds = totalSeconds % 60;
  return '${padZero(hours)}:${padZero(minutes)}:${padZero(seconds)}';
}

/// 날짜를 YYYY-MM-DD 형식으로 변환
String formatDate(DateTime date) {
  return '${date.year}-${padZero(date.month)}-${padZero(date.day)}';
}

/// 시간을 HH-MM-SS 형식으로 변환
String formatTime(DateTime date) {
  return '${padZero(date.hour)}-${padZero(date.minute)}-${padZero(date.second)}';
}

/// DateTime을 HH:MM:SS 형식으로 변환
String formatDateTime(DateTime? date) {
  if (date == null) return '--:--:--';
  return '${padZero(date.hour)}:${padZero(date.minute)}:${padZero(date.second)}';
}

/// 날짜와 시간을 파일명용으로 변환
String formatDateTimeForFile(DateTime date) {
  return '${formatDate(date)}_${formatTime(date)}';
}
