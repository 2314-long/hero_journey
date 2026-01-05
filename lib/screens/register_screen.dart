import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/game_logo.dart'; // 引入刚才写的 Logo

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    setState(() => _isLoading = true);

    final username = _usernameController.text;
    final email = _emailController.text;
    final password = _passwordController.text;

    if (username.isEmpty || email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请填写完整信息，密码至少6位'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    // 调用 API 注册
    final success = await ApiService().register(username, email, password);

    setState(() => _isLoading = false);

    if (success && mounted) {
      // 注册成功，提示并返回登录页
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 注册成功！请登录'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // 返回上一页 (登录页)
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('注册失败，邮箱可能已被占用'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 给一个浅紫色的背景，显得更有层次
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.deepPurple,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 使用我们新的 Logo
              const GameLogo(size: 100),
              const SizedBox(height: 20),
              const Text(
                "加入冒险",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "创建你的英雄档案",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),

              // 昵称输入框
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: "英雄昵称",
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // 邮箱输入框
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "邮箱地址",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // 密码输入框
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "设置密码 (至少6位)",
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 32),

              // 注册按钮
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 56, // 按钮高一点更好看
                      child: FilledButton(
                        onPressed: _register,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "立即注册",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
