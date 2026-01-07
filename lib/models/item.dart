class Item {
  final int id;
  final String name;
  final String description;
  final int price;
  final String type; // EQUIPMENT, CONSUMABLE
  final String effectType;
  final double effectValue;
  final String iconPath;

  Item({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.type,
    required this.effectType,
    required this.effectValue,
    required this.iconPath,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: json['price'],
      type: json['type'],
      effectType: json['effect_type'],
      effectValue: (json['effect_value'] as num).toDouble(),
      iconPath: json['icon_path'],
    );
  }
}

class InventoryItem {
  final int id; // 这是 inventory 表的主键 ID
  final Item item;
  final bool isEquipped;
  final int quantity;
  final DateTime? expiresAt;

  InventoryItem({
    required this.id,
    required this.item,
    this.isEquipped = false,
    required this.quantity,
    this.expiresAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'],
      item: Item.fromJson(json['item']),
      isEquipped: json['is_equipped'] ?? false,
      quantity: json['quantity'],
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
    );
  }
}
