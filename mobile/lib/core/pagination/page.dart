final class Page<T> {
  const Page({required this.items, required this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  factory Page.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, Object?> item) itemParser,
  ) {
    final rawItems = json['items'];
    final rawCursor = json['next_cursor'];
    if (rawItems is! List || (rawCursor != null && rawCursor is! String)) {
      throw const FormatException('Formato de página inválido.');
    }
    final items = rawItems
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Item da página deve ser um objeto.');
          }
          final mappedItem = <String, Object?>{};
          for (final entry in item.entries) {
            if (entry.key is! String) {
              throw const FormatException(
                'As chaves do item da página devem ser strings.',
              );
            }
            mappedItem[entry.key as String] = entry.value;
          }
          return itemParser(mappedItem);
        })
        .toList(growable: false);

    return Page<T>(items: items, nextCursor: rawCursor as String?);
  }
}
