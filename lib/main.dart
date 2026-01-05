import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 引入页面和服务
import 'screens/main_screen.dart'; // 👈 现在这里可以正常引用了
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await StorageService().init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 初始化 API 并检查 Token
  final bool isLoggedIn = await ApiService().init();

  runApp(HeroApp(isLoggedIn: isLoggedIn));
}

class HeroApp extends StatelessWidget {
  final bool isLoggedIn;

  const HeroApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final seedColor = const Color(0xFF6C63FF);

    return MaterialApp(
      title: 'Hero Journey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          surface: const Color(0xFFF4F6FC),
          primary: seedColor,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FC),
        appBarTheme: AppBarTheme(
          backgroundColor: seedColor,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: seedColor,
          unselectedItemColor: Colors.grey.shade400,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        dividerTheme: const DividerThemeData(color: Colors.transparent),
        expansionTileTheme: const ExpansionTileThemeData(
          shape: Border(),
          collapsedShape: Border(),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
      // 路由逻辑
      home: isLoggedIn ? const MainScreen() : const LoginScreen(),
    );
  }
}
