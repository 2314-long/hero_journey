import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  // 🔥 接收从主页传来的"初始数据" (解决闪烁问题的关键)
  final String? initialAvatarUrl;
  final String initialUsername;
  final int initialGold;
  final int initialCompletedTasks;
  final int initialActiveDays;
  final Function(String? newName)? onProfileUpdate;

  const ProfileScreen({
    super.key,
    this.initialAvatarUrl,
    required this.initialUsername,
    required this.initialGold,
    required this.initialCompletedTasks,
    required this.initialActiveDays,
    this.onProfileUpdate,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  // 核心数据状态
  String? _avatarUrl;
  late String _username;
  late int _gold;
  late int _completedTasks;
  late int _activeDays;

  bool _isLoading = false;
  List<dynamic> _achievements = [];

  @override
  void initState() {
    super.initState();
    // 🔥 [核心优化] 直接使用父组件传来的数据初始化，界面零延迟显示！
    _avatarUrl = widget.initialAvatarUrl;
    _username = widget.initialUsername;
    _gold = widget.initialGold;
    _completedTasks = widget.initialCompletedTasks;
    _activeDays = widget.initialActiveDays;

    // 虽然已经有了数据，但还是可以在后台静默刷新一下最新数据
    _fetchRealData();
  }

  // 📡 静默拉取后端真实数据 (用于校准)
  Future<void> _fetchRealData() async {
    try {
      final results = await Future.wait([
        ApiService().fetchStats(),
        ApiService().fetchTasks(),
      ]);

      if (!mounted) return;

      final stats = results[0] as Map<String, dynamic>?;
      final tasks = results[1] as List<dynamic>?;

      setState(() {
        if (stats != null) {
          _gold = stats['gold'] ?? _gold;
          _username = stats['nickname'] ?? _username;
          _activeDays = stats['active_days'] ?? _activeDays;
          _achievements = stats['achievements'] ?? [];
        }
        if (tasks != null) {
          _completedTasks = tasks.where((t) => t.isDone == true).length;
        }
      });
    } catch (e) {
      debugPrint("后台同步个人数据失败: $e"); // 静默失败，不打扰用户
    }
  }

  // 📸 上传头像逻辑
  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);

    File file = File(image.path);
    String? newUrl = await ApiService().uploadAvatar(file);

    if (mounted) {
      setState(() => _isLoading = false);
      if (newUrl != null) {
        setState(() => _avatarUrl = newUrl);
        // 🔥 通知主页数据变了
        widget.onProfileUpdate?.call(newUrl);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ 头像更新成功！"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ 上传失败，请检查网络"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✏️ 修改昵称
  void _editNickname() {
    TextEditingController controller = TextEditingController(text: _username);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isSubmitting = false;
          return AlertDialog(
            title: const Text("修改昵称"),
            content: TextField(
              controller: controller,
              maxLength: 12,
              decoration: const InputDecoration(
                hintText: "请输入新的昵称",
                border: OutlineInputBorder(),
                counterText: "",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("取消"),
              ),
              FilledButton(
                onPressed: () async {
                  final newName = controller.text.trim();
                  if (newName.isEmpty || newName.length < 2) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text("昵称至少需要2个字符")));
                    return;
                  }

                  setStateDialog(() => isSubmitting = true);
                  bool success = await ApiService().updateNickname(newName);

                  if (!mounted) return;

                  if (success) {
                    setState(() => _username = newName);
                    // 🔥 通知主页数据变了
                    widget.onProfileUpdate?.call(newName);

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("✅ 昵称修改成功"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    setStateDialog(() => isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("❌ 修改失败，请重试"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("保存"),
              ),
            ],
          );
        },
      ),
    );
  }

  // ⏳ 通用加载弹窗

  // 🔒 修改密码 (优化版：增加Loading效果)
  void _changePassword() {
    TextEditingController oldCtrl = TextEditingController();
    TextEditingController newCtrl = TextEditingController();
    TextEditingController confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("修改密码"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "当前密码",
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "新密码 (至少6位)",
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "确认新密码",
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () async {
              // 1. 基础校验
              if (newCtrl.text.length < 6) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("新密码太短了")));
                return;
              }
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("两次输入的密码不一致")));
                return;
              }

              // 2. 🔥 弹出 Loading 圈 (阻断操作)
              _showLoadingDialog(context);

              // 3. 发送请求
              // 注意：这里不需要 setStateDialog 了，因为有全屏 Loading 挡着
              String? error = await ApiService().changePassword(
                oldCtrl.text,
                newCtrl.text,
              );

              // 4. 关闭 Loading 圈
              if (!mounted) return;
              Navigator.of(context).pop();

              // 5. 处理结果
              if (error == null) {
                // ✅ 成功：先关闭"修改密码"的弹窗
                Navigator.pop(ctx);

                // 🔥 弹出强制重登录提示
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: const Text("修改成功"),
                    content: const Text("您的密码已更新。请使用新密码重新登录。"),
                    actions: [
                      FilledButton(
                        onPressed: () async {
                          Navigator.pop(context); // 关闭提示框
                          await StorageService().clearAll(); // 清理数据

                          if (mounted) {
                            // 跳转回登录页
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (c) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        child: const Text("去登录"),
                      ),
                    ],
                  ),
                );
              } else {
                // ❌ 失败：报错提示
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("❌ $error"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("确认修改"),
          ),
        ],
      ),
    );
  }

  // 🚪 退出登录
  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("退出登录"),
        content: const Text("确定要离开吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageService().clearAll();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (c) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("退出", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildStatsBoard(),
          ),

          const SizedBox(height: 24),
          _buildAchievementsSection(),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSettingsMenu(), // 菜单
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 🔥 [新增] 成就勋章墙 Widget
  Widget _buildAchievementsSection() {
    // 如果后端没返回成就，或者列表为空，就不显示这个区域，保持页面整洁
    if (_achievements.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "成就勋章",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 横向滚动的列表
        SizedBox(
          height: 140, // 给足够的高度
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 5,
            ), // 加点垂直内边距防止阴影被切
            scrollDirection: Axis.horizontal,
            itemCount: _achievements.length,
            separatorBuilder: (c, i) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = _achievements[index];
              // 根据后端字段判断状态
              final bool isUnlocked = item['is_unlocked'] ?? false;
              final String icon = item['icon'] ?? "🔒";
              final String name = item['name'] ?? "未知成就";
              final String progress = item['progress'] ?? "";

              return Container(
                width: 110,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.white : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  // 未解锁显示灰色边框，解锁显示无边框但有阴影
                  border: isUnlocked
                      ? null
                      : Border.all(color: Colors.grey.shade300),
                  boxShadow: isUnlocked
                      ? [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 1. 图标圆圈
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        // 解锁是金色背景，未解锁是灰色
                        color: isUnlocked
                            ? Colors.orange.shade50
                            : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        icon,
                        style: TextStyle(
                          fontSize: 24,
                          // 未解锁时让图标变灰（可选，或者用锁图标）
                          color: isUnlocked ? null : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2. 名称
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? Colors.black87 : Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 3. 进度文字 / 完成对勾
                    if (isUnlocked)
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 12,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 2),
                          Text(
                            "已达成",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        progress,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    ImageProvider imageProvider;
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      String url = _avatarUrl!;
      if (!url.startsWith('http')) {
        url = "http://10.0.2.2:8080$url";
      }
      imageProvider = NetworkImage(url);
    } else {
      imageProvider = const AssetImage('assets/images/default_avatar.png');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    const BoxShadow(blurRadius: 10, color: Colors.black12),
                  ],
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _username,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8), // 稍微加点间距
              IconButton(
                // 视觉优化：把编辑图标稍微调小一点，颜色淡一点，更精致
                constraints: const BoxConstraints(), // 紧凑布局
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                onPressed: _editNickname,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBoard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade500, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("累计任务", "$_completedTasks"),
          Container(width: 1, height: 30, color: Colors.white24),
          _buildStatItem("金币资产", "$_gold"),
          Container(width: 1, height: 30, color: Colors.white24),
          _buildStatItem("活跃天数", "$_activeDays"),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildSettingsMenu() {
    return Column(
      children: [
        _buildMenuItem(
          Icons.lock_outline,
          "修改密码",
          Colors.orange,
          _changePassword,
        ),
        const SizedBox(height: 12),
        _buildMenuItem(Icons.help_outline, "帮助与反馈", Colors.blue, () {}),
        const SizedBox(height: 12),
        _buildMenuItem(
          Icons.logout,
          "退出登录",
          Colors.red,
          _logout,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive ? Colors.red : Colors.black87,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // 点击背景不关闭
      builder: (ctx) => Center(
        child: Container(
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "正在处理...",
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
