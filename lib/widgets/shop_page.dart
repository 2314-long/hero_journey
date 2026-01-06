import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/api_service.dart';

class ShopPage extends StatefulWidget {
  final int gold;
  final VoidCallback onRefreshData;

  const ShopPage({super.key, required this.gold, required this.onRefreshData});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  late Future<List<Item>> _shopFuture;

  @override
  void initState() {
    super.initState();
    _shopFuture = ApiService().fetchShopItems();
  }

  Widget _getIcon(String path) {
    if (path.contains("potion"))
      return const Icon(Icons.local_drink, color: Colors.redAccent, size: 32);
    if (path.contains("sword"))
      return const Icon(Icons.colorize, color: Colors.blueAccent, size: 32);
    if (path.contains("shield"))
      return const Icon(Icons.security, color: Colors.brown, size: 32);
    if (path.contains("coffee"))
      return const Icon(Icons.coffee, color: Colors.brown, size: 32);
    if (path.contains("cross"))
      return const Icon(
        Icons.health_and_safety,
        color: Colors.purpleAccent,
        size: 32,
      );
    return const Icon(Icons.help_outline, color: Colors.grey, size: 32);
  }

  void _handleBuy(Item item) async {
    // 1. 本地预检查
    if (widget.gold < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("💰 金币不足！"), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. 调用 API (接收错误信息)
    final errorMsg = await ApiService().buyItem(item.id);

    if (!mounted) return;

    if (errorMsg == null) {
      // ✅ 成功
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("已购买 ${item.name}!"),
          backgroundColor: Colors.green,
        ),
      );
      widget.onRefreshData(); // 刷新金币
    } else {
      // ❌ 失败 (显示后端传回来的具体原因，比如"金币不足")
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("购买失败: $errorMsg"), backgroundColor: Colors.red),
      );

      // 💡 自动修复数据：如果后端说没钱，说明前端数据是旧的，强制刷新一下
      if (errorMsg.contains("不足")) {
        widget.onRefreshData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ... (顶部金币卡片代码保持不变，为了节省篇幅省略，请保留原来的代码) ...
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF8B85FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "当前持有",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Gold Coins",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${widget.gold}",
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 商品列表
        Expanded(
          child: FutureBuilder<List<Item>>(
            future: _shopFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(child: Text("无法连接到商店: ${snapshot.error}"));
              final items = snapshot.data ?? [];

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: items.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  // ✨ 核心修改：判断是否买得起
                  final bool canAfford = widget.gold >= item.price;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: _getIcon(item.iconPath)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _handleBuy(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              // ✨ 动态颜色：买得起是绿色，买不起是灰色
                              color: canAfford
                                  ? const Color(0xFFE0F7FA)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: canAfford
                                  ? Border.all(color: Colors.cyan.shade200)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.attach_money,
                                  size: 16,
                                  color: canAfford
                                      ? Colors.cyan.shade700
                                      : Colors.grey,
                                ),
                                Text(
                                  "${item.price}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    // ✨ 动态字体颜色
                                    color: canAfford
                                        ? Colors.cyan.shade900
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
