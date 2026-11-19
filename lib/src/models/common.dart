import 'json.dart';

/// Référence compacte vers une autre ressource (`Ref` dans la spec).
/// Si la ressource a été « expandée » via `include=`, [raw] contient l'objet complet.
class TveRef {
  final String slug;
  final String? name;
  final String? title;
  final String url;
  final Json raw;

  const TveRef({required this.slug, this.name, this.title, required this.url, this.raw = const {}});

  /// Libellé à afficher : `name` ou `title`.
  String get label => name ?? title ?? slug;

  static TveRef? fromJsonOrNull(Object? v) => v is Map ? TveRef.fromJson(v.cast()) : null;

  factory TveRef.fromJson(Json j) => TveRef(
        slug: str(j['slug']) ?? '',
        name: str(j['name']),
        title: str(j['title']),
        url: str(j['url']) ?? '',
        raw: j,
      );
}

/// Une page d'une collection paginée par curseur.
class TvePage<T> {
  final List<T> items;
  final int? limit;
  final String? nextCursor;
  final String? prevCursor;

  /// Méta brutes (ex: `at` / `timezone` pour `/schedule/now`).
  final Json meta;

  const TvePage({required this.items, this.limit, this.nextCursor, this.prevCursor, this.meta = const {}});

  bool get hasMore => nextCursor != null;

  factory TvePage.fromJson(Json j, T Function(Json) f) {
    final meta = asJson(j['meta']);
    return TvePage(
      items: listOf(j['data'], f),
      limit: toInt(meta['limit']),
      nextCursor: str(meta['next_cursor']),
      prevCursor: str(meta['prev_cursor']),
      meta: meta,
    );
  }
}
