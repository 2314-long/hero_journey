import 'package:flutter/material.dart';

class ShopPage extends StatelessWidget {
  final int gold;
  final int currentHp;
  final int maxHp;
  final bool hasResurrectionCross;
  final VoidCallback onBuyHealth;
  final VoidCallback onBuyCross;
  final VoidCallback onBuyCoffee;

  const ShopPage({
    super.key,
    required this.gold,
    required this.currentHp,
    required this.maxHp,
    required this.hasResurrectionCross,
    required this.onBuyHealth,
    required this.onBuyCross,
    required this.onBuyCoffee,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 顶部金币展示卡片
        _buildBalanceCard(context),
        const SizedBox(height: 24),

        const Text(
          "  恢复类",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _ShopItemCard(
          title: "小型血瓶",
          description: "恢复 20 点生命值",
          price: 50,
          icon: Icons.local_drink_rounded,
          iconColor: Colors.redAccent,
          userGold: gold,
          // 如果满血，禁用购买
          isDisabled: currentHp >= maxHp,
          disabledText: "HP 已满",
          onBuy: onBuyHealth,
        ),
        _ShopItemCard(
          title: "提神咖啡",
          description: "仅仅是一杯好喝的咖啡",
          price: 10,
          icon: Icons.coffee_rounded,
          iconColor: Colors.brown,
          userGold: gold,
          onBuy: onBuyCoffee,
        ),

        const SizedBox(height: 24),
        const Text(
          "  特殊道具",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _ShopItemCard(
          title: "复活十字架",
          description: "抵挡一次致命伤害并回血",
          price: 100,
          icon: Icons.auto_awesome_rounded,
          iconColor: Colors.purpleAccent,
          userGold: gold,
          // 如果已拥有，禁用购买
          isDisabled: hasResurrectionCross,
          disabledText: "已拥有",
          onBuy: onBuyCross,
        ),
      ],
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // 使用蓝紫色渐变背景
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "当前持有",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  "$gold",
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 私有的商品卡片组件
class _ShopItemCard extends StatelessWidget {
  final String title;
  final String description;
  final int price;
  final IconData icon;
  final Color iconColor;
  final int userGold;
  final VoidCallback onBuy;
  final bool isDisabled;
  final String? disabledText;

  const _ShopItemCard({
    required this.title,
    required this.description,
    required this.price,
    required this.icon,
    required this.iconColor,
    required this.userGold,
    required this.onBuy,
    this.isDisabled = false,
    this.disabledText,
  });

  @override
  Widget build(BuildContext context) {
    final bool canAfford = userGold >= price;
    // 真正的不可买状态：要么逻辑禁用（满血/已拥有），要么买不起
    final bool isReallyDisabled = isDisabled || !canAfford;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 图标容器
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(width: 16),
            // 文字信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            // 购买按钮
            FilledButton(
              onPressed: isReallyDisabled ? null : onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: isReallyDisabled
                    ? Colors.grey.shade100
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: isReallyDisabled ? Colors.grey : Colors.white,
                elevation: isReallyDisabled ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: isDisabled
                  ? Text(disabledText ?? "不可用") // 显示“满血”或“已拥有”
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          canAfford
                              ? Icons.monetization_on_rounded
                              : Icons.money_off_rounded,
                          size: 16,
                          color: canAfford ? Colors.amberAccent : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text("$price"),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
