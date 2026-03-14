// Login screen with email OTP authentication (no password)
// Flow: email input → OTP sent → OTP verify → logged in
// Supports register mode: username + email
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

/// 로그인 화면 위젯
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// 로그인 단계
enum _LoginStep { email, otp, register }

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _usernameController = TextEditingController();

  _LoginStep _step = _LoginStep.email;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  /// 이메일로 OTP 발송
  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.sendOtp(email);
      setState(() => _step = _LoginStep.otp);
    } on Exception catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      // 가입되지 않은 이메일 → 회원가입 단계로
      if (msg.contains('not registered') || msg.contains('가입되지 않은')) {
        // 이메일 @ 앞부분을 닉네임 기본값으로 설정
        final email = _emailController.text.trim();
        _usernameController.text = email.split('@').first;
        setState(() => _step = _LoginStep.register);
      } else {
        setState(() => _errorMessage = msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// OTP 검증 → 로그인
  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ApiService.verifyOtp(_emailController.text.trim(), otp);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', user['id']);
      await prefs.setString('username', user['username']);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on Exception catch (e) {
      setState(() =>
          _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 회원가입 후 OTP 발송
  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (username.length < 2) {
      setState(() => _errorMessage = 'Nickname must be at least 2 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.register(username, email);
      await ApiService.sendOtp(email);
      setState(() => _step = _LoginStep.otp);
    } on Exception catch (e) {
      setState(() =>
          _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 로고
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D9A5),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      size: 60,
                      color: Color(0xFF0D1B2A),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'BitHabit',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    _stepSubtitle,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 입력 폼
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      children: [
                        _buildForm(),
                        const SizedBox(height: 24),

                        // 에러 메시지
                        if (_errorMessage != null)
                          _buildError(_errorMessage!),

                        // 메인 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _onMainAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D9A5),
                              foregroundColor: const Color(0xFF0D1B2A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0D1B2A),
                                    ),
                                  )
                                : Text(
                                    _buttonLabel,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 뒤로가기
                        if (_step != _LoginStep.email)
                          TextButton(
                            onPressed: () => setState(() {
                              _step = _LoginStep.email;
                              _errorMessage = null;
                              _otpController.clear();
                            }),
                            child: Text(
                              '← Back to email',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // About 섹션
                  _buildAboutSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 단계별 자막
  String get _stepSubtitle => switch (_step) {
        _LoginStep.email => 'Sign in with your email',
        _LoginStep.otp => 'Enter the code sent to your email',
        _LoginStep.register => 'Welcome! Choose a nickname',
      };

  /// 단계별 버튼 라벨
  String get _buttonLabel => switch (_step) {
        _LoginStep.email => 'Get Verification Code',
        _LoginStep.otp => 'Sign In',
        _LoginStep.register => 'Sign Up & Get Code',
      };

  /// 단계별 메인 액션
  VoidCallback get _onMainAction => switch (_step) {
        _LoginStep.email => _handleSendOtp,
        _LoginStep.otp => _handleVerifyOtp,
        _LoginStep.register => _handleRegister,
      };

  /// 단계별 입력 폼
  Widget _buildForm() {
    return switch (_step) {
      _LoginStep.email => _buildTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'example@gmail.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          onSubmit: _handleSendOtp,
        ),
      _LoginStep.otp => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00D9A5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF00D9A5).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read_outlined,
                      color: Color(0xFF00D9A5), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Code sent to ${_emailController.text}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _otpController,
              label: 'Verification Code',
              hint: '000000',
              icon: Icons.lock_outline,
              keyboardType: TextInputType.number,
              onSubmit: _handleVerifyOtp,
              maxLength: 6,
            ),
          ],
        ),
      _LoginStep.register => Column(
          children: [
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'example@gmail.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              enabled: false,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _usernameController,
              label: 'Nickname',
              hint: 'At least 2 characters',
              icon: Icons.person_outline,
              onSubmit: _handleRegister,
            ),
          ],
        ),
    };
  }

  /// 공통 텍스트필드
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onSubmit,
    bool enabled = true,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      enabled: enabled,
      maxLength: maxLength,
      buildCounter: maxLength != null
          ? (_, {required currentLength, required isFocused, maxLength}) => null
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: Icon(icon, color: const Color(0xFF00D9A5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF00D9A5), width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(enabled ? 0.1 : 0.05),
      ),
      onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
    );
  }

  /// 에러 박스
  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 플랫폼 소개 섹션
  Widget _buildAboutSection() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 구분선
          _buildDivider('About habit.bit-habit'),
          const SizedBox(height: 24),

          // 플랫폼 소개
          Text(
            'A habit-building platform where small groups stay accountable together.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a study session, let the webcam capture your focus, '
            'and share an auto-generated GIF with your team — '
            'all in real-time.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // How it works
          _buildDivider('How It Works'),
          const SizedBox(height: 16),
          _buildStepCards(),
          const SizedBox(height: 28),

          // 기술 스택 + 왜 이 기술인지
          _buildDivider('Tech Stack & Why'),
          const SizedBox(height: 16),
          _buildTechWithReason(),
          const SizedBox(height: 28),

          // 아키텍처 요약
          _buildDivider('Architecture'),
          const SizedBox(height: 16),
          _buildArchSection(),
          const SizedBox(height: 28),

          // 인증 설명
          _buildDivider('Authentication'),
          const SizedBox(height: 16),
          _buildAuthSection(),
          const SizedBox(height: 24),

          // 푸터
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline,
                        size: 14, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(width: 6),
                    Text('Active study group · v1.0.0',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('github.com/bookseal/bithabit',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.25),
                        fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(String label) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
      ],
    );
  }

  /// 4-step flow
  Widget _buildStepCards() {
    final steps = [
      ('1', '📧', 'Sign in with email', 'No password. A 6-digit code is sent to your inbox, verified with JWT.'),
      ('2', '📸', 'Start a session', 'Your webcam captures frames every few seconds while the timer runs.'),
      ('3', '🎞', 'Auto-generate GIF', 'When you stop, gif.js compiles the frames into an animated GIF — all client-side.'),
      ('4', '💬', 'Share with your team', 'Post your GIF to the live chat. WebSocket delivers it to everyone instantly.'),
    ];

    return Column(
      children: steps.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.$2, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Step ${s.$1}  ${s.$3}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(s.$4,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 기술 스택 + 선택 이유
  Widget _buildTechWithReason() {
    final techs = [
      ('Flutter Web', const Color(0xFF54C5F8), 'Single codebase for web & mobile. Dart compiles to JS with canvas rendering.'),
      ('FastAPI', const Color(0xFF009688), 'Python async framework. Auto-generates OpenAPI docs, native WebSocket support.'),
      ('JWT', const Color(0xFFFFD54F), 'Stateless auth — server validates tokens without DB lookup. 7-day access + 30-day refresh.'),
      ('WebSocket', const Color(0xFFCE93D8), 'Full-duplex real-time: server broadcasts new messages to all connected clients instantly.'),
      ('gif.js', const Color(0xFFFF8A65), 'Client-side GIF encoding in a Web Worker. Zero server compute for media processing.'),
      ('SQLite', const Color(0xFF80CBC4), 'Lightweight file-based DB. No separate server needed — perfect for small-scale apps.'),
      ('Gmail SMTP', const Color(0xFFEF9A9A), 'Passwordless OTP via Gmail App Password. Free, ~500 emails/day, no external service.'),
      ('Kubernetes', const Color(0xFF90CAF9), 'k3s cluster with Traefik Ingress. Auto TLS, rolling deploys, zero-downtime updates.'),
    ];

    return Column(
      children: techs.map((t) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.$2.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: t.$2.withOpacity(0.3)),
                ),
                child: Text(t.$1,
                    style: TextStyle(
                        color: t.$2,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t.$3,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                        height: 1.4)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 아키텍처
  Widget _buildArchSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('habit.bit-habit.com',
              style: TextStyle(
                  color: const Color(0xFF00D9A5).withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace')),
          const SizedBox(height: 8),
          _buildArchRow('Traefik Ingress', 'TLS termination, path-based routing'),
          _buildArchRow('/api/*  →  FastAPI Pod', 'REST + WebSocket + JWT auth'),
          _buildArchRow('/*  →  nginx Pod', 'Serves Flutter build/web as static files'),
          _buildArchRow('SQLite (hostPath)', 'Users, messages, OTP codes'),
          _buildArchRow('Uploads (hostPath)', 'User-generated GIF files'),
          const SizedBox(height: 8),
          Text(
            'flutter build web deploys instantly — nginx serves directly from the build directory via Kubernetes hostPath volume.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 10,
                fontStyle: FontStyle.italic,
                height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildArchRow(String label, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('▸ ', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
          Text('$label  ',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(desc,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 10)),
          ),
        ],
      ),
    );
  }

  /// 인증
  Widget _buildAuthSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Passwordless — Email OTP + JWT',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _buildAuthRow('No passwords stored', 'Users verify via 6-digit email code (5 min expiry)'),
          _buildAuthRow('JWT access token', '7-day expiry — auto-login for weekly users'),
          _buildAuthRow('JWT refresh token', '30-day expiry — silent renewal, no re-login'),
          _buildAuthRow('Stateless validation', 'HS256 signature check only, no DB query per request'),
          _buildAuthRow('Auto-login flow', 'access → refresh fallback → re-auth if both expired'),
        ],
      ),
    );
  }

  Widget _buildAuthRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 13, color: Color(0xFF00D9A5)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    height: 1.3),
                children: [
                  TextSpan(
                      text: '$title — ',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
