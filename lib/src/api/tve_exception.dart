import '../models/json.dart';

/// Erreur de l'API (RFC 9457 « problem details ») ou erreur réseau.
///
/// [code] reprend les codes de la spec : `group_not_found`, `group_suspended`,
/// `feature_not_included`, `not_found`, `unknown_filter`, `unknown_sort`,
/// `unknown_include`, `invalid_parameter`, `invalid_cursor`,
/// `playback_unavailable`, `rate_limited`, `server_error`,
/// et `network_error` côté client.
class TveException implements Exception {
  final int status;
  final String code;
  final String title;
  final String? detail;
  final String? feature;
  final Map<String, String> fieldErrors;
  final Duration? retryAfter;

  const TveException({
    required this.status,
    required this.code,
    required this.title,
    this.detail,
    this.feature,
    this.fieldErrors = const {},
    this.retryAfter,
  });

  bool get isNotFound => code == 'not_found' || code == 'group_not_found';
  bool get isRateLimited => status == 429;
  bool get isPlaybackUnavailable => code == 'playback_unavailable';
  bool get isNetwork => code == 'network_error';

  factory TveException.fromProblem(int status, Json j, {Duration? retryAfter}) => TveException(
        status: toInt(j['status']) ?? status,
        code: str(j['code']) ?? (status == 429 ? 'rate_limited' : 'server_error'),
        title: str(j['title']) ?? 'HTTP $status',
        detail: str(j['detail']),
        feature: str(j['feature']),
        fieldErrors: {
          for (final e in (j['errors'] is List ? j['errors'] as List : const []))
            if (e is Map) '${e['param']}': '${e['message']}'
        },
        retryAfter: retryAfter,
      );

  factory TveException.network(Object error) =>
      TveException(status: 0, code: 'network_error', title: 'Connexion impossible', detail: '$error');

  @override
  String toString() => 'TveException($status $code: ${detail ?? title})';
}
