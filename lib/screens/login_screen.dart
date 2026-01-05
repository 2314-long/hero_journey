import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../main.dart'; // 为了跳转到 MainScreen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);

    final email = _emailController.text;
    final password = _passwordController.text;

    // 调用 API 登录
    final success = await ApiService().login(email, password);

    setState(() => _isLoading = false);

    if (success && mounted) {
      // 登录成功，跳转到主页 (并且把登录页从历史记录里移除，防止按返回键退回来)
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('登录失败，请检查账号密码'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 临时注册逻辑 (为了省事，先用对话框注册)
  void _showRegisterDialog() {
    final emailCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("注册英雄档案"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(labelText: "昵称"),
            ),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: "邮箱"),
            ),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: "密码"),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final success = await ApiService().register(
                userCtrl.text,
                emailCtrl.text,
                passCtrl.text,
              );
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("注册成功！请登录")));
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("注册失败"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("提交注册"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.shield_moon_rounded,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 20),
              const Text(
                "Hero Journey",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "邮箱",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "密码",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _login,
                        child: const Text("登录 / 开始冒险"),
                      ),
                    ),
              TextButton(
                onPressed: _showRegisterDialog,
                child: const Text("没有账号？注册一个"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
