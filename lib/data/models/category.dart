class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    this.premium = false,
  });

  final String id;
  final String name;

  /// Material icon name; resolved to an IconData in the UI layer.
  final String icon;

  /// Premium categories are locked until bought with coins (or Pro Pass later).
  final bool premium;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        premium: json['premium'] as bool? ?? false,
      );
}
