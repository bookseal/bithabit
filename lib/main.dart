import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/attendance_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BitHabitApp());
}

/// BitHabit 앱의 메인 위젯
class BitHabitApp extends StatelessWidget {
  const BitHabitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AttendanceService>(create: (_) => AttendanceService()),
      ],
      child: MaterialApp(
        title: 'BitHabit',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const AuthWrapper(),
      ),
    );
  }

  ThemeData _buildTheme() {
    const primaryColor = Color(0xFF0D1B2A);
    const accentColor = Color(0xFF00D9A5);
    const backgroundColor = Color(0xFF1B263B);
    const surfaceColor = Color(0xFF253449);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: Color(0xFFFF6B6B),
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// 인증 상태에 따른 화면 분기
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // JWT 토큰으로 자동 로그인 시도
    final user = await ApiService.tryAutoLogin();

    setState(() {
      _isLoggedIn = user != null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9A5)),
        ),
      );
    }

    // 로그인 안됨 → 로그인 화면, 로그인 됨 → 채팅방 (기본)
    return _isLoggedIn ? const MainChatScreen() : const LoginScreen();
  }
}

/// 메인 채팅 화면 (하단 네비게이션 포함)
class MainChatScreen extends StatefulWidget {
  const MainChatScreen({super.key});

  @override
  State<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen> {
  @override
  Widget build(BuildContext context) {
    return const ChatScreen();
  }
}
