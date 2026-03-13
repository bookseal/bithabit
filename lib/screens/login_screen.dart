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

  /// 프로젝트 소개 섹션
  Widget _buildAboutSection() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Divider(color: Colors.white.withOpacity(0.15))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'About BitHabit',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Expanded(
                  child: Divider(color: Colors.white.withOpacity(0.15))),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'A habit-tracking & sharing web app for small study groups',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          _buildFeatureGrid(),
          const SizedBox(height: 24),
          _buildTechStack(),
          const SizedBox(height: 24),
          _buildFlowSection(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline,
                  size: 14, color: Colors.white.withOpacity(0.35)),
              const SizedBox(width: 6),
              Text(
                'Used by a 5-member study group · v1.0.0',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid() {
    final features = [
      ('📸', 'Study Timer', 'Auto-capture via webcam while studying'),
      ('🎞', 'GIF Export', 'Turn captured frames into animated GIF'),
      ('💬', 'Live Chat', 'WebSocket-based team chat & GIF sharing'),
      ('🔔', '20-min Alert', 'Beep sound + blink after 20 minutes'),
      ('📊', 'Attendance', 'Auto-log to Google Sheets on stop'),
      ('✉️', 'Email Auth', 'Passwordless OTP login, no password'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 3.2,
      children: features
          .map((f) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Text(f.$1, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(f.$2,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text(f.$3,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildTechStack() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🛠  Tech Stack',
            style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip('Flutter Web', const Color(0xFF54C5F8)),
            _buildChip('Dart', const Color(0xFF00B4AB)),
            _buildChip('FastAPI', const Color(0xFF009688)),
            _buildChip('Python', const Color(0xFFFFD54F)),
            _buildChip('SQLite', const Color(0xFF80CBC4)),
            _buildChip('WebSocket', const Color(0xFFCE93D8)),
            _buildChip('Gmail SMTP', const Color(0xFFEF9A9A)),
            _buildChip('gif.js', const Color(0xFFFF8A65)),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildFlowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🔄  Data Flow',
            style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFlowRow('Login', 'Email → OTP sent → Enter code → JWT issued'),
              const SizedBox(height: 6),
              _buildFlowRow('Start', 'Webcam ON → Capture every 5s → Timer running'),
              const SizedBox(height: 6),
              _buildFlowRow('Stop', 'Google Sheets log → GIF generation'),
              const SizedBox(height: 6),
              _buildFlowRow('Share', 'POST /api/messages → WebSocket broadcast'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlowRow(String step, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF00D9A5).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(step,
              style: const TextStyle(
                  color: Color(0xFF00D9A5),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(desc,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 11)),
        ),
      ],
    );
  }
}
