import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // 引入相册插件
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  // 接收从主页传来的当前头像 URL
  final String? currentAvatarUrl;
  const ProfileScreen({super.key, this.currentAvatarUrl});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _avatarUrl; // 当前显示的头像URL

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.currentAvatarUrl;
  }

  // 📸 打开相册并上传
  Future<void> _pickAndUploadImage() async {
    // 1. 打开相册
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      File file = File(image.path);

      // 显示 loading
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("正在上传...")));

      // 2. 上传给后端
      String? newUrl = await ApiService().uploadAvatar(file);

      if (newUrl != null && mounted) {
        setState(() {
          _avatarUrl = newUrl; // 更新本地显示
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("头像更新成功！")));
      } else {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("上传失败")));
      }
    }
  }

  // 🖼️ 构建头像组件
  Widget _buildAvatar() {
    ImageProvider imageProvider;

    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      // 拼接完整的 URL (注意 Android 模拟器要用 10.0.2.2)
      // 如果你的 baseUrl 已经是 http://10.0.2.2:8080/api/v1
      // 这里要把 /api/v1 去掉，或者后端直接返回完整 URL
      // 假设后端返回 "/uploads/xxx.jpg"，我们需要拼上前缀
      String fullUrl = "http://10.0.2.2:8080$_avatarUrl";
      imageProvider = NetworkImage(fullUrl);
    } else {
      // 默认头像
      imageProvider = const AssetImage('assets/images/default_avatar.png');
    }

    return GestureDetector(
      onTap: _pickAndUploadImage, // 点击换头像
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("个人中心")),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            _buildAvatar(),
            const SizedBox(height: 20),
            const Text("点击头像可修改", style: TextStyle(color: Colors.grey)),
            // ... 其他个人信息
          ],
        ),
      ),
    );
  }
}
