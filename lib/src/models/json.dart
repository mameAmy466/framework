/// Petits utilitaires de lecture JSON tolérants (null-safe).
library;

typedef Json = Map<String, dynamic>;

Json asJson(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

String? str(Object? v) => v == null ? null : (v is String ? v : '$v');

int? toInt(Object? v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));

bool toBool(Object? v) => v == true || v == 1 || v == 'true';

DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;

List<T> listOf<T>(Object? v, T Function(Json) f) =>
    v is List ? v.whereType<Map>().map((e) => f(e.cast<String, dynamic>())).toList() : <T>[];

List<String> strings(Object? v) => v is List ? v.map((e) => '$e').toList() : const [];

/// Lit un objet `links` : nom -> URL absolue (ou null).
Map<String, String?> linkMap(Object? v) => asJson(v).map((k, val) => MapEntry(k, str(val)));
