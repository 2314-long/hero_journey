import 'dart:async';
import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

// ==========================================
// 🔥 核心优化 1: 独立的倒计时组件
// 只有这个小组件会每秒刷新，不会影响整个页面
// ==========================================
class CountdownTag extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onExpired;

  const CountdownTag({
    super.key,
    required this.expiresAt,
    required this.onExpired,
  });

  @override
  State<CountdownTag> createState() => _CountdownTagState();
}

class _CountdownTagState extends State<CountdownTag> {
  Timer? _timer;
  late Duration _diff;

  @override
  void initState() {
    super.initState();
    _calculateTime();
    // 启动局部定时器
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTime();
    });
  }

  void _calculateTime() {
    final now = DateTime.now();
    final diff = widget.expiresAt.difference(now);

    if (diff.isNegative) {
      // 时间到了，停止计时，并通知父组件刷新
      _timer?.cancel();
      // 使用 addPostFrameCallback 防止在构建过程中回调报错
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onExpired();
      });
    }

    if (mounted) {
      setState(() {
        _diff = diff;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_diff.isNegative) {
      return const SizedBox(); // 过期瞬间暂时隐藏，等待父组件刷新
    }

    final h = _diff.inHours;
    final m = _diff.inMinutes % 60;
    final s = _diff.inSeconds % 60;

    // 格式化时间文本
    String timeText = "剩余: ";
    if (h > 0) timeText += "$h小时 ";
    timeText += "$m分 $s秒";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: Colors.blue.shade700),
          const SizedBox(width: 4),
          Text(
            timeText,
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 主页面 ShopPage
// ==========================================
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

  // 这里的变量只用于存储数据，不再用于驱动每秒刷新
  List<InventoryItem> _currentInventory = [];
  bool _isLoadingInventory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 加载数据
  void _refreshData() {
    if (mounted) {
      setState(() {
        _shopFuture = ApiService().fetchShopItems();
        _isLoadingInventory = true;
      });
    }

    ApiService().fetchInventory().then((items) {
      if (mounted) {
        // 🔥 核心修复：前端双重保险 🔥
        // 拿到数据后，先自己检查一遍，把所有已过期的装备踢出去！
        // 这样即使后端慢了一秒，前端 UI 也会立刻把它变没。
        final now = DateTime.now();
        items.removeWhere(
          (item) =>
              item.isEquipped &&
              item.expiresAt != null &&
              now.isAfter(item.expiresAt!),
        );

        setState(() {
          _currentInventory = items;
          _isLoadingInventory = false;
        });
      }
    });
  }

  // 🔥 核心改动：当倒计时结束时，只调用这个方法，不重新全量 SetState
  void _handleItemExpired() {
    print("物品过期，触发刷新...");
    // 重新拉取数据，后端会自动清理过期物品
    _refreshData();
    widget.onRefreshData();
  }

  // 分组逻辑 (保持不变)
  List<Map<String, dynamic>> _groupInventoryItems(List<InventoryItem> rawList) {
    Map<int, Map<String, dynamic>> grouped = {};
    for (var inv in rawList) {
      final itemId = inv.item.id;
      if (!grouped.containsKey(itemId)) {
        grouped[itemId] = {
          'item': inv.item,
          'totalCount': 0,
          'activeInv': null,
          'stackInv': null,
        };
      }
      grouped[itemId]!['totalCount'] += inv.quantity;
      if (inv.isEquipped) {
        grouped[itemId]!['activeInv'] = inv;
      } else {
        grouped[itemId]!['stackInv'] = inv;
      }
    }
    return grouped.values.toList();
  }

  // 图标逻辑 (保持不变)
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

  // 购买逻辑
  void _handleBuy(Item item) async {
    if (widget.gold < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("💰 金币不足！"), backgroundColor: Colors.red),
      );
      return;
    }
    // 乐观 UI 更新：先扣钱 (UI体验更好)
    // 但这里为了安全，还是等待后端返回
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
      widget.onRefreshData();
      _refreshData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("购买失败: $errorMsg"), backgroundColor: Colors.red),
      );
    }
  }

  // 使用/装备逻辑
  void _handleUse(InventoryItem invItem) async {
    // 立即显示 Loading 或者给用户反馈 (防止重复点击)
    final message = await ApiService().useItem(invItem.id);
    if (!mounted) return;

    if (message != null) {
      if (invItem.item.type == "EQUIPMENT") {
        AudioService().playBuy();
      } else {
        AudioService().playSuccess();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            invItem.item.type == "EQUIPMENT" ? message : "✨ $message",
          ),
          backgroundColor: Colors.blueAccent,
        ),
      );
      widget.onRefreshData();
      _refreshData(); // 操作完刷新
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 操作失败"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- 1. 顶部金币卡片 (保持不变) ---
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
              Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: const Color(0xFF6C63FF),
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.9),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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

        // --- 2. 内容区域 ---
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ====== 商店列表 ======
              FutureBuilder<List<Item>>(
                future: _shopFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
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

              // ====== 背包列表 (重构版：无闪屏) ======
              Builder(
                builder: (context) {
                  if (_isLoadingInventory && _currentInventory.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_currentInventory.isEmpty) {
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
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final groupedItems = _groupInventoryItems(_currentInventory);

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: groupedItems.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final group = groupedItems[index];
                      final Item item = group['item'];
                      final int totalCount = group['totalCount'];
                      final InventoryItem? activeInv = group['activeInv'];
                      final InventoryItem? stackInv = group['stackInv'];

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
                                color: Colors.orange.withOpacity(0.1),
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
                                          "$totalCount",
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

                                  // 🔥 修复：使用独立的 CountdownTag 组件
                                  if (activeInv != null &&
                                      activeInv.expiresAt != null) ...[
                                    const SizedBox(height: 6),
                                    CountdownTag(
                                      expiresAt: activeInv.expiresAt!,
                                      onExpired:
                                          _handleItemExpired, // 倒计时结束时的回调
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                if (activeInv != null) {
                                  _handleUse(activeInv);
                                } else if (stackInv != null) {
                                  _handleUse(stackInv);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: (activeInv != null)
                                      ? Colors.grey.shade200
                                      : (item.type == "EQUIPMENT"
                                            ? const Color(0xFFE8F5E9)
                                            : const Color(0xFFFFF3E0)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (activeInv != null)
                                        ? Colors.grey
                                        : (item.type == "EQUIPMENT"
                                              ? Colors.green.shade800
                                              : Colors.orange.shade200),
                                  ),
                                ),
                                child: Text(
                                  (activeInv != null)
                                      ? "卸下"
                                      : (item.type == "EQUIPMENT"
                                            ? "装备"
                                            : "使用"),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: (activeInv != null)
                                        ? Colors.grey.shade700
                                        : (item.type == "EQUIPMENT"
                                              ? Colors.green.shade800
                                              : Colors.orange.shade800),
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
