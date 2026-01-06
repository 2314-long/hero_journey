import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

class ShopPage extends StatefulWidget {
  final int gold;
  final VoidCallback onRefreshData;

  const ShopPage({super.key, required this.gold, required this.onRefreshData});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Item>> _shopFuture;
  late Future<List<InventoryItem>> _inventoryFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _shopFuture = ApiService().fetchShopItems();
      _inventoryFuture = ApiService().fetchInventory();
    });
  }

  // ✨ 保留你原来的图标逻辑
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
    if (widget.gold < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("💰 金币不足！"), backgroundColor: Colors.red),
      );
      return;
    }

    final errorMsg = await ApiService().buyItem(item.id);
    if (!mounted) return;

    if (errorMsg == null) {
      AudioService().playBuy();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("已购买 ${item.name}!"),
          backgroundColor: Colors.green,
        ),
      );
      widget.onRefreshData(); // 刷新金币
      _refreshData(); // 刷新背包和列表
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("购买失败: $errorMsg"), backgroundColor: Colors.red),
      );
    }
  }

  void _handleUse(InventoryItem invItem) async {
    if (invItem.item.type != "CONSUMABLE") {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("装备请在角色面板穿戴")));
      return;
    }

    final message = await ApiService().useItem(invItem.id);
    if (!mounted) return;

    if (message != null) {
      AudioService().playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✨ $message"),
          backgroundColor: Colors.blueAccent,
        ),
      );
      widget.onRefreshData(); // 刷新血量
      _refreshData(); // 刷新背包
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 使用失败"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. 顶部金币卡片 (保留你的原版设计)
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
          child: Column(
            children: [
              Row(
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
              const SizedBox(height: 16),
              // ✨ 新增：嵌入式 Tab 切换 (样式融合)
              Container(
                height: 44, // 稍微增高一点，手感更好
                padding: const EdgeInsets.all(4), // 关键：内边距，让滑块悬浮
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15), // 背景槽稍微深一点，增加对比度
                  borderRadius: BorderRadius.circular(22), // 更加圆润
                ),
                child: TabBar(
                  controller: _tabController,
                  // 关键设置：让滑块填满整个 tab 区域，而不是只包住文字
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent, // 去掉底部的横线
                  // ✨ 滑块样式：白色圆角 + 阴影
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18), // 稍微比外层容器小一点
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),

                  // ✨ 文字样式
                  labelColor: const Color(0xFF6C63FF), // 选中状态：紫色字 (因为底是白的)
                  unselectedLabelColor: Colors.white.withValues(
                    alpha: 0.9,
                  ), // 未选中：白色字
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15, // 字体稍微大一点，撑满空间
                  ),

                  tabs: const [
                    Tab(text: "补给商店"),
                    Tab(text: "我的背包"),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. 内容区域 (商店/背包)
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // --- 商店列表 (你的原版 UI) ---
              FutureBuilder<List<Item>>(
                future: _shopFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(child: Text("无法连接: ${snapshot.error}"));
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

              // --- 背包列表 (沿用商店 UI 风格) ---
              FutureBuilder<List<InventoryItem>>(
                future: _inventoryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  final items = snapshot.data ?? [];

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.backpack_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "背包空空如也\n去商店买点东西吧",
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final invItem = items[index];
                      final item = invItem.item;

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
                                color: Colors.orange.withOpacity(
                                  0.1,
                                ), // 背包用不同底色
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    _getIcon(item.iconPath),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.orange,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          "${invItem.quantity}",
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                            // 使用按钮
                            InkWell(
                              onTap: () => _handleUse(invItem),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                child: Text(
                                  "使用",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                  ),
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
            ],
          ),
        ),
      ],
    );
  }
}
