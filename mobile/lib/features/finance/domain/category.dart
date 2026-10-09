final class Category {
  const Category({
    required this.id,
    required this.name,
    required this.archived,
  });

  final String id;
  final String name;
  final bool archived;

  factory Category.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final archived = json['archived'];
    if (id is! String || name is! String || archived is! bool) {
      throw const FormatException('Formato de categoria inválido.');
    }
    return Category(id: id, name: name, archived: archived);
  }
}
