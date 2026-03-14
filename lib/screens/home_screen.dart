import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../services/capture_service.dart';
import '../services/gif_service.dart';
import '../widgets/camera_preview.dart';
import '../widgets/timer_display.dart';
import '../widgets/control_buttons.dart';
import '../utils/formatters.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

/// 메인 홈 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // 컨트롤러
  final TextEditingController _dailyGoalController = TextEditingController();
  String _username = '';

  // 서비스
  late CameraService _cameraService;
  late CaptureService _captureService;
  late GifService _gifService;

  // 상태
  CaptureState _captureState = CaptureState.idle;
  bool _isCameraInitialized = false;
  bool _isFallbackMode = false; // 카메라 없을 때 샘플 이미지 모드
  bool _isLoading = true;
  String? _errorMessage;

  // 타이머 관련
  DateTime? _startTime;
  int _totalPausedMs = 0;
  DateTime? _pauseStartTime;
  Timer? _durationTimer;
  int _durationMs = 0;
  bool _isBlinking = false;
  Timer? _blinkTimer;

  // 20분 알림
  static const int _twentyMinutesMs = 20 * 60 * 1000;
  bool _hasAlerted = false;

  // GIF 관련
  String? _gifDataUrl;
  double _gifProgress = 0;
  bool _isCreatingGif = false;

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _captureService = CaptureService();
    _gifService = GifService();
    _initializeApp();
  }

  @override
  void dispose() {
    _dailyGoalController.dispose();
    _durationTimer?.cancel();
    _blinkTimer?.cancel();
    _cameraService.dispose();
    _captureService.dispose();
    super.dispose();
  }

  /// 앱 초기화
  Future<void> _initializeApp() async {
    await _loadSavedData();
    await _initializeCamera();
  }

  /// 저장된 데이터 로드
  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedGoal = prefs.getString('dailyGoal') ?? '';
      setState(() {
        _username = prefs.getString('username') ?? '';
        _dailyGoalController.text = savedGoal;
      });
    } catch (e) {
      debugPrint('저장된 데이터 로드 오류: $e');
    }
  }

  /// 데이터 저장
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dailyGoal', _dailyGoalController.text);
    } catch (e) {
      debugPrint('데이터 저장 오류: $e');
    }
  }

  /// 카메라 초기화 — 실패 시 fallback 모드로 자동 전환
  Future<void> _initializeCamera() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _cameraService.initialize();
      setState(() {
        _isCameraInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Camera unavailable, switching to fallback mode: $e');
      setState(() {
        _isFallbackMode = true;
        _isLoading = false;
      });
    }
  }

  /// 시작
  void _onStart() {
    _saveData();

    setState(() {
      _captureState = CaptureState.capturing;
      _startTime = DateTime.now();
      _durationMs = 0;
      _totalPausedMs = 0;
      _hasAlerted = false;
      _gifDataUrl = null;
    });

    _startDurationTimer();

    // 카메라 있으면 실제 캡처, 없으면 타이머만
    if (_isCameraInitialized && _cameraService.videoElement != null) {
      _captureService.startCapturing(
        videoElement: _cameraService.videoElement!,
        userId: _username,
        dailyGoal: _dailyGoalController.text,
        onCapture: () => setState(() {}),
        getDuration: () => formatDuration(_durationMs),
      );
    }
  }

  /// 중지
  Future<void> _onStop() async {
    _durationTimer?.cancel();
    _blinkTimer?.cancel();

    // 카메라 있으면 캡처 중지
    if (_isCameraInitialized) {
      _captureService.stopCapturing(
        videoElement: _cameraService.videoElement,
        userId: _username,
        dailyGoal: _dailyGoalController.text,
        getDuration: () => formatDuration(_durationMs),
      );
    }

    setState(() {
      _captureState = CaptureState.finished;
      _isBlinking = false;
    });

    // 세션 기록 (자체 API)
    try {
      await ApiService.createSession(
        dailyGoal: _dailyGoalController.text,
        startedAt: _startTime!,
        durationMin: (_durationMs / 1000 / 60).round(),
      );
      _showSnackBar('Session logged!', isSuccess: true);
    } catch (e) {
      _showSnackBar('Session error: $e');
    }

    // GIF 생성 (카메라 있을 때만)
    if (_isCameraInitialized) {
      await _createGif();
    }
  }

  /// 일시정지/재개
  void _onPause() {
    if (_captureState == CaptureState.capturing) {
      // 일시정지
      _pauseStartTime = DateTime.now();
      _durationTimer?.cancel();
      _captureService.togglePause();
      _startBlinking();
      setState(() {
        _captureState = CaptureState.paused;
      });
    } else if (_captureState == CaptureState.paused) {
      // 재개
      _totalPausedMs += DateTime.now().difference(_pauseStartTime!).inMilliseconds;
      _pauseStartTime = null;
      _startDurationTimer();
      _captureService.togglePause();
      _stopBlinking();
      setState(() {
        _captureState = CaptureState.capturing;
      });
    }
  }

  /// 카메라 전환
  Future<void> _onSwitchCamera() async {
    try {
      await _cameraService.switchCamera();
    } catch (e) {
      _showSnackBar('Camera switch error: $e');
    }
  }

  /// 타이머 시작
  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startTime != null) {
        final now = DateTime.now();
        setState(() {
          _durationMs = now.difference(_startTime!).inMilliseconds - _totalPausedMs;
        });

        // 20분 알림
        if (_durationMs >= _twentyMinutesMs && !_hasAlerted) {
          _hasAlerted = true;
          _playBeepSound();
          _startBlinking();
        }
      }
    });
  }

  /// 깜빡임 시작
  void _startBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        _isBlinking = !_isBlinking;
      });
    });
  }

  /// 깜빡임 중지
  void _stopBlinking() {
    _blinkTimer?.cancel();
    setState(() {
      _isBlinking = false;
    });
  }

  /// 비프음 재생 (JavaScript eval 사용)
  void _playBeepSound() {
    try {
      // JavaScript를 통한 비프음 재생
      final script = html.ScriptElement();
      script.text = '''
        try {
          var audioContext = new (window.AudioContext || window.webkitAudioContext)();
          var oscillator = audioContext.createOscillator();
          var gainNode = audioContext.createGain();
          oscillator.connect(gainNode);
          gainNode.connect(audioContext.destination);
          oscillator.type = 'sine';
          oscillator.frequency.setValueAtTime(440, audioContext.currentTime);
          gainNode.gain.setValueAtTime(1, audioContext.currentTime);
          oscillator.start();
          oscillator.stop(audioContext.currentTime + 0.5);
        } catch(e) {
          console.log('Audio error:', e);
        }
      ''';
      html.document.body?.append(script);
      script.remove();
    } catch (e) {
      debugPrint('비프음 재생 오류: $e');
    }
  }

  /// GIF 생성
  Future<void> _createGif() async {
    debugPrint('[HomeScreen] 🎬 _createGif 호출됨');
    debugPrint('[HomeScreen] 📸 캡처된 이미지 수: ${_captureService.capturedImages.length}');
    
    if (_captureService.capturedImages.isEmpty) {
      debugPrint('[HomeScreen] ⚠️ 캡처된 이미지가 없어서 종료');
      return;
    }

    setState(() {
      _isCreatingGif = true;
      _gifProgress = 0;
    });

    _gifService.onProgress = (progress) {
      debugPrint('[HomeScreen] 📊 GIF 진행률 업데이트: ${(progress * 100).toStringAsFixed(1)}%');
      setState(() {
        _gifProgress = progress;
      });
    };

    try {
      debugPrint('[HomeScreen] 🚀 gifService.createGif 호출 시작');
      final dataUrl = await _gifService.createGif(_captureService.capturedImages);
      debugPrint('[HomeScreen] 📦 createGif 결과: ${dataUrl != null ? "성공 (길이: ${dataUrl.length})" : "null 반환"}');
      
      setState(() {
        _gifDataUrl = dataUrl;
        _isCreatingGif = false;
      });
      
      if (dataUrl != null) {
        debugPrint('[HomeScreen] ✅ GIF 생성 완료!');
      } else {
        debugPrint('[HomeScreen] ❌ GIF 생성 실패 (null 반환)');
        _showSnackBar('GIF generation failed.');
      }
    } catch (e, stackTrace) {
      debugPrint('[HomeScreen] ❌ GIF 생성 예외: $e');
      debugPrint('[HomeScreen] 스택트레이스: $stackTrace');
      setState(() {
        _isCreatingGif = false;
      });
      _showSnackBar('GIF error: $e');
    }
  }

  /// GIF 다운로드
  void _downloadGif() {
    if (_gifDataUrl != null) {
      _gifService.downloadGif(_gifDataUrl!);
    }
  }

  /// 스낵바 표시
  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? const Color(0xFF00D9A5) : const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B2A),
              Color(0xFF1B263B),
              Color(0xFF253449),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingView()
              : _buildMainView(),
        ),
      ),
    );
  }

  /// 로딩 뷰
  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF00D9A5)),
          SizedBox(height: 16),
          Text(
            'Initializing camera...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// 에러 뷰
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              size: 64,
              color: Color(0xFFFF6B6B),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeCamera,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 16),
            // 채팅방 바로가기
            OutlinedButton.icon(
              onPressed: () => _goToChat(),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Go to Chat'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00D9A5),
                side: const BorderSide(color: Color(0xFF00D9A5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 메인 뷰
  Widget _buildMainView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              // 헤더
              _buildHeader(),
              const SizedBox(height: 24),

              // 목표 입력
              _buildGoalInput(),
              const SizedBox(height: 24),

              // 카메라 프리뷰 or 폴백 플레이스홀더
              if (_isCameraInitialized)
                CameraPreview(
                  viewId: _cameraService.viewId,
                  isRecording: _captureState == CaptureState.capturing,
                )
              else if (_isFallbackMode)
                _buildFallbackPreview(),
              const SizedBox(height: 24),

              // 타이머
              TimerDisplay(
                duration: formatDuration(_durationMs),
                isBlinking: _isBlinking,
                isRecording: _captureState == CaptureState.capturing,
              ),
              const SizedBox(height: 24),

              // 컨트롤 버튼
              ControlButtons(
                state: _captureState,
                onStart: _onStart,
                onStop: _onStop,
                onPause: _onPause,
                onSwitchCamera: _onSwitchCamera,
                canSwitchCamera: _captureState == CaptureState.idle,
              ),
              const SizedBox(height: 24),

              // 캡처된 이미지 수
              if (_captureService.capturedCount > 0)
                _buildCaptureCount(),

              // GIF 생성 진행바
              if (_isCreatingGif) _buildGifProgress(),

              // GIF 프리뷰 및 다운로드
              if (_gifDataUrl != null) _buildGifPreview(),
            ],
          ),
        ),
      ),
    );
  }

  /// 채팅방으로 이동
  void _goToChat({String? gifBase64}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(pendingGifBase64: gifBase64),
      ),
    );
  }

  /// 로그아웃
  Future<void> _logout() async {
    await ApiService.clearTokens();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  /// 헤더
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BitHabit',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00D9A5),
              ),
            ),
            if (_username.isNotEmpty)
              Text(
                _username,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white54,
                ),
              ),
          ],
        ),
        Row(
          children: [
            // 채팅방 버튼
            IconButton(
              onPressed: () => _goToChat(),
              icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF00D9A5)),
              tooltip: 'Chat',
            ),
            // 로그아웃 버튼
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.white54),
              tooltip: 'Logout',
            ),
          ],
        ),
      ],
    );
  }

  /// 카메라 없을 때 보여주는 폴백 프리뷰
  Widget _buildFallbackPreview() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF253449),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _captureState == CaptureState.capturing
              ? const Color(0xFF00D9A5)
              : Colors.white.withOpacity(0.1),
          width: _captureState == CaptureState.capturing ? 2 : 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _captureState == CaptureState.capturing
                  ? Icons.timer
                  : Icons.videocam_off_rounded,
              size: 48,
              color: _captureState == CaptureState.capturing
                  ? const Color(0xFF00D9A5)
                  : Colors.white30,
            ),
            const SizedBox(height: 12),
            Text(
              _captureState == CaptureState.capturing
                  ? 'Timer running (no camera)'
                  : 'Camera not available',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _captureState == CaptureState.capturing
                  ? 'GIF will not be generated'
                  : 'Timer will work without camera',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// 목표 입력
  Widget _buildGoalInput() {
    return TextField(
      controller: _dailyGoalController,
      decoration: const InputDecoration(
        labelText: "Today's Goal",
        hintText: 'What are you studying today? (Optional)',
        prefixIcon: Icon(Icons.flag_outlined),
      ),
      enabled: _captureState == CaptureState.idle,
      onChanged: (_) => _saveData(),
    );
  }

  /// 캡처 수 표시
  Widget _buildCaptureCount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF253449).withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Captured: ${_captureService.capturedCount} frames',
        style: GoogleFonts.inter(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
    );
  }

  /// GIF 진행바
  Widget _buildGifProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            'Creating GIF... ${(_gifProgress * 100).toInt()}%',
            style: GoogleFonts.inter(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _gifProgress,
            backgroundColor: const Color(0xFF253449),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D9A5)),
          ),
        ],
      ),
    );
  }

  /// GIF 프리뷰
  Widget _buildGifPreview() {
    return Column(
      children: [
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            _gifDataUrl!,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 16),
        _buildGifInstructions(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _downloadGif,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9A5),
                foregroundColor: const Color(0xFF0D1B2A),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _goToChat(gifBase64: _gifDataUrl),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share to Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                foregroundColor: const Color(0xFF0D1B2A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// GIF 다운로드 안내
  Widget _buildGifInstructions() {
    final isIphone = html.window.navigator.userAgent.contains(RegExp(r'iPhone|iPad|iPod', caseSensitive: false));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF253449).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isIphone
                ? '1. Long-press the GIF above and tap "Save to Photos"'
                : '1. Tap the Download button below to save the GIF',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '2. Share the GIF in your group chat',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
