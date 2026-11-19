import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/catalog.dart';
import '../models/common.dart';
import '../models/group.dart';
import '../models/json.dart';
import '../models/media.dart';
import 'tve_exception.dart';

/// Client typé de l'API TVE v3 (https://tveapi.acan.group/v3/docs).
///
/// ```dart
/// final api = TveClient(group: 'leraltv');
/// final group = await api.getGroup();
/// final live = await api.getChannelLive('leral-tv');
/// ```
///
/// - Toutes les routes `GET /groups/{group}/...` de la spec.
/// - Cache ETag mémoire (`If-None-Match` → 304) sauf pour les descripteurs de lecture.
/// - Une nouvelle tentative automatique sur 429 (respecte `Retry-After`, max [maxRetryWait]).
/// - Les filtres « liste » sont envoyés séparés par des virgules (= OU).
class TveClient {
  static const defaultBaseUrl = 'https://tveapi.acan.group/v3';

  /// Code du groupe (= l'app), ex: `leraltv`.
  final String group;
  final String baseUrl;
  final Duration timeout;
  final Duration maxRetryWait;
  final bool etagCache;
  final Map<String, String> headers;
  final http.Client _http;
  final bool _ownsHttp;
  final Map<String, _CacheEntry> _cache = {};

  TveClient({
    required this.group,
    this.baseUrl = defaultBaseUrl,
    this.timeout = const Duration(seconds: 20),
    this.maxRetryWait = const Duration(seconds: 5),
    this.etagCache = true,
    this.headers = const {},
    http.Client? httpClient,
  })  : _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null;

  String get _root => '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/groups/${Uri.encodeComponent(group)}';

  void close() {
    if (_ownsHttp) _http.close();
  }

  void clearCache() => _cache.clear();

  // ---------------------------------------------------------------- groupe

  /// Branding, config mobile, fonctionnalités et collections disponibles.
  Future<TveGroup> getGroup() async => TveGroup.fromJson(asJson((await _get(''))['data']));

  // ---------------------------------------------------------------- chaînes

  /// `kind` : tv, radio, webtv, cinema, acas. `include` : now, app. `sort` : order, -order, name, -name.
  Future<TvePage<TveChannel>> listChannels({
    List<String>? kind,
    String? q,
    List<String>? include,
    String? sort,
    int? limit,
    String? cursor,
  }) =>
      _page('/channels', TveChannel.fromJson, {
        'kind': kind,
        'q': q,
        'include': include,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      });

  Future<TveChannel> getChannel(String slug, {List<String>? include}) =>
      _item('/channels/${_seg(slug)}', TveChannel.fromJson, {'include': include});

  /// URL de lecture live signée (HLS ou audio). Jamais mise en cache.
  Future<TvePlayback> getChannelLive(String slug) =>
      _item('/channels/${_seg(slug)}/live', TvePlayback.fromJson, const {}, cache: false);

  // ---------------------------------------------------------------- émissions

  /// `include` : channel, categories, presenters, videos, audios. `airing` : ['now'].
  Future<TvePage<TveShow>> listShows({
    List<String>? channel,
    List<String>? kind,
    List<String>? category,
    List<String>? presenter,
    bool? featured,
    List<String>? airing,
    String? q,
    List<String>? include,
    String? sort,
    int? limit,
    String? cursor,
  }) =>
      _page('/shows', TveShow.fromJson, {
        'channel': channel,
        'kind': kind,
        'category': category,
        'presenter': presenter,
        'featured': featured,
        'airing': airing,
        'q': q,
        'include': include,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      });

  Future<TveShow> getShow(String slug, {List<String>? include}) =>
      _item('/shows/${_seg(slug)}', TveShow.fromJson, {'include': include});

  // ---------------------------------------------------------------- vidéos

  /// `source` : vod, youtube, dailymotion. `relatedTo` : slug d'une vidéo (autres vidéos de la même émission).
  Future<TvePage<TveVideo>> listVideos({
    List<String>? show,
    List<String>? channel,
    List<String>? category,
    List<String>? presenter,
    bool? featured,
    List<String>? source,
    String? relatedTo,
    String? q,
    List<String>? include,
    String? sort,
    int? limit,
    String? cursor,
  }) =>
      _page('/videos', TveVideo.fromJson, {
        'show': show,
        'channel': channel,
        'category': category,
        'presenter': presenter,
        'featured': featured,
        'source': source,
        'related_to': relatedTo,
        'q': q,
        'include': include,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      });

  Future<TveVideo> getVideo(String slug, {List<String>? include}) =>
      _item('/videos/${_seg(slug)}', TveVideo.fromJson, {'include': include});

  Future<TvePlayback> getVideoPlayback(String slug) =>
      _item('/videos/${_seg(slug)}/playback', TvePlayback.fromJson, const {}, cache: false);

  // ---------------------------------------------------------------- audios

  /// `origin` : record, upload, external.
  Future<TvePage<TveAudio>> listAudios({
    List<String>? show,
    List<String>? channel,
    List<String>? origin,
    String? q,
    List<String>? include,
    String? sort,
    int? limit,
    String? cursor,
  }) =>
      _page('/audios', TveAudio.fromJson, {
        'show': show,
        'channel': channel,
        'origin': origin,
        'q': q,
        'include': include,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      });

  Future<TveAudio> getAudio(String slug, {List<String>? include}) =>
      _item('/audios/${_seg(slug)}', TveAudio.fromJson, {'include': include});

  // ---------------------------------------------------------------- catégories

  /// `has` : shows, videos, audios. `include` : children, shows, videos.
  Future<TvePage<TveCategory>> listCategories({
    List<String>? parent,
    List<String>? has,
    String? q,
    List<String>? include,
    String? sort,
    int? limit,
    String? cursor,
  }) =>
      _page('/categories', TveCategory.fromJson, {
        'parent': parent,
        'has': has,
        'q': q,
        'include': include,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      });

  Future<TveCategory> getCategory(String slug, {List<String>? include}) =>
      _item('/categories/${_seg(slug)}', TveCategory.fromJson, {'include': include});

  // ---------------------------------------------------------------- présentateurs

  Future<TvePage<TvePresenter>> listPresenters({
    List<String>? show,
    List<String>? channel,
    String? q,
    List<String>? include,
    String? sort,
    int? limit,
    String? cursor,
  }) =>
      _page('/presenters', TvePresenter.fromJson, {
        'show': show,
        'channel': channel,
        'q': q,
        'include': include,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      });

  Future<TvePresenter> getPresenter(String slug, {List<String>? include}) =>
      _item('/presenters/${_seg(slug)}', TvePresenter.fromJson, {'include': include});

  // ---------------------------------------------------------------- grille

  /// Grille d'un jour (heure locale du groupe), d'hier à J+7. Défaut : aujourd'hui.
  Future<List<TveScheduleSlot>> listSchedule({DateTime? date, List<String>? channel, List<String>? kind}) async {
    final d = date == null
        ? null
        : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final j = await _get('/schedule', query: {'date': d, 'channel': channel, 'kind': kind});
    return listOf(j['data'], TveScheduleSlot.fromJson);
  }

  /// En cours / à suivre, un élément par chaîne.
  Future<List<TveChannelNow>> listScheduleNow({List<String>? channel, List<String>? kind}) async {
    final j = await _get('/schedule/now', query: {'channel': channel, 'kind': kind});
    return listOf(j['data'], TveChannelNow.fromJson);
  }

  // ---------------------------------------------------------------- actualités

  Future<TvePage<TveNews>> listNews({
    List<String>? category,
    String? q,
    List<String>? include,
    String? sort,
    int? limit,
    String? cursor,
  }) =>
      _page('/news', TveNews.fromJson, {
        'category': category,
        'q': q,
        'include': include,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      });

  /// Article complet (avec `contentHtml`).
  Future<TveNews> getNews(String slug, {List<String>? include}) =>
      _item('/news/${_seg(slug)}', TveNews.fromJson, {'include': include});

  Future<TvePage<TveNewsCategory>> listNewsCategories({
    List<String>? parent,
    List<String>? include,
    String? sort,
    int? limit,
    String? cursor,
  }) =>
      _page('/news-categories', TveNewsCategory.fromJson, {
        'parent': parent,
        'include': include,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      });

  Future<TveNewsCategory> getNewsCategory(String slug, {List<String>? include}) =>
      _item('/news-categories/${_seg(slug)}', TveNewsCategory.fromJson, {'include': include});

  // ---------------------------------------------------------------- pubs

  /// `placement` : web, live, replays, shorts.
  Future<TvePage<TveAd>> listAds({
    List<String>? placement,
    List<String>? channel,
    String? sort,
    int? limit,
    String? cursor,
  }) =>
      _page('/ads', TveAd.fromJson, {
        'placement': placement,
        'channel': channel,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      });

  Future<TveAd> getAd(String slug) => _item('/ads/${_seg(slug)}', TveAd.fromJson, const {});

  // ---------------------------------------------------------------- YouTube (externe)

  /// `feed` : videos, shorts, live-streams, popular-videos, popular-shorts, popular-live-streams.
  /// `playlist` : id d'une playlist externe, ex `youtube:PLxxxx`.
  Future<TvePage<TveExternalVideo>> listExternalVideos({
    List<String>? provider,
    List<String>? channel,
    List<String>? feed,
    String? playlist,
    String? q,
    String? sort,
    int? limit,
    String? cursor,
  }) =>
      _page('/external-videos', TveExternalVideo.fromJson, {
        'provider': provider,
        'channel': channel,
        'feed': feed,
        'playlist': playlist,
        'q': q,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      });

  /// [key] = `{provider}:{id}`, ex `youtube:dQw4w9WgXcQ`.
  Future<TveExternalVideo> getExternalVideo(String key) =>
      _item('/external-videos/${_seg(key)}', TveExternalVideo.fromJson, const {});

  Future<TvePage<TveExternalPlaylist>> listExternalPlaylists({
    List<String>? provider,
    List<String>? channel,
    String? q,
    String? sort,
    int? limit,
    String? cursor,
  }) =>
      _page('/external-playlists', TveExternalPlaylist.fromJson, {
        'provider': provider,
        'channel': channel,
        'q': q,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      });

  Future<TveExternalPlaylist> getExternalPlaylist(String key) =>
      _item('/external-playlists/${_seg(key)}', TveExternalPlaylist.fromJson, const {});

  // ---------------------------------------------------------------- shorts

  Future<TvePage<TveShort>> listShorts({
    List<String>? channel,
    List<String>? show,
    List<String>? video,
    String? before,
    String? q,
    List<String>? include,
    String? sort,
    int? limit,
    String? cursor,
  }) =>
      _page('/shorts', TveShort.fromJson, {
        'channel': channel,
        'show': show,
        'video': video,
        'before': before,
        'q': q,
        'include': include,
        'sort': sort,
        'limit': limit,
        'cursor': cursor,
      });

  Future<TveShort> getShort(String slug, {List<String>? include}) =>
      _item('/shorts/${_seg(slug)}', TveShort.fromJson, {'include': include});

  Future<TvePlayback> getShortPlayback(String slug) =>
      _item('/shorts/${_seg(slug)}/playback', TvePlayback.fromJson, const {}, cache: false);

  // ---------------------------------------------------------------- recherche

  /// Recherche globale (q ≥ 2 caractères, max 5 résultats par type).
  /// `types` : shows, videos, audios, news.
  Future<List<TveSearchResult>> search(String q, {List<String>? types}) async {
    final j = await _get('/search', query: {'q': q, 'types': types});
    final data = j['data'] is List ? j['data'] as List : const [];
    return data.whereType<Map>().map((e) => TveSearchResult.fromJson(e.cast())).whereType<TveSearchResult>().toList();
  }

  // ---------------------------------------------------------------- utilitaires

  /// Parcourt toutes les pages d'une collection.
  /// ```dart
  /// await for (final v in api.paginate((c) => api.listExternalVideos(cursor: c))) { ... }
  /// ```
  Stream<T> paginate<T>(Future<TvePage<T>> Function(String? cursor) fetch, {int maxPages = 50}) async* {
    String? cursor;
    for (var i = 0; i < maxPages; i++) {
      final page = await fetch(cursor);
      yield* Stream.fromIterable(page.items);
      if (!page.hasMore) return;
      cursor = page.nextCursor;
    }
  }

  /// GET brut sur une URL absolue renvoyée par l'API (champ `links` / `url`).
  Future<Json> getUrl(String absoluteUrl) => _send(Uri.parse(absoluteUrl), cache: etagCache);

  // ---------------------------------------------------------------- interne

  static String _seg(String s) => Uri.encodeComponent(s);

  Future<TvePage<T>> _page<T>(String path, T Function(Json) f, Map<String, Object?> q) async =>
      TvePage.fromJson(await _get(path, query: q), f);

  Future<T> _item<T>(String path, T Function(Json) f, Map<String, Object?> q, {bool cache = true}) async =>
      f(asJson((await _get(path, query: q, cache: cache))['data']));

  Future<Json> _get(String path, {Map<String, Object?> query = const {}, bool cache = true}) {
    final qp = <String, String>{};
    query.forEach((k, v) {
      if (v == null) return;
      if (v is List) {
        if (v.isEmpty) return;
        qp[k] = v.join(',');
      } else {
        qp[k] = '$v';
      }
    });
    final uri = Uri.parse('$_root$path').replace(queryParameters: qp.isEmpty ? null : qp);
    return _send(uri, cache: cache && etagCache);
  }

  Future<Json> _send(Uri uri, {required bool cache, int attempt = 0}) async {
    final key = uri.toString();
    final cached = cache ? _cache[key] : null;
    final h = {
      'Accept': 'application/json',
      ...headers,
      if (cached != null) 'If-None-Match': cached.etag,
    };

    final http.Response res;
    try {
      res = await _http.get(uri, headers: h).timeout(timeout);
    } catch (e) {
      throw TveException.network(e);
    }

    if (res.statusCode == 304 && cached != null) return cached.body;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = asJson(jsonDecode(utf8.decode(res.bodyBytes)));
      final etag = res.headers['etag'];
      if (cache && etag != null) _cache[key] = _CacheEntry(etag, body);
      return body;
    }

    final retryAfter = _retryAfter(res.headers['retry-after']);
    if (res.statusCode == 429 && attempt == 0) {
      final wait = retryAfter ?? const Duration(seconds: 1);
      if (wait <= maxRetryWait) {
        await Future<void>.delayed(wait);
        return _send(uri, cache: cache, attempt: 1);
      }
    }

    Json problem = const {};
    try {
      problem = asJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } catch (_) {}
    throw TveException.fromProblem(res.statusCode, problem, retryAfter: retryAfter);
  }

  static Duration? _retryAfter(String? v) {
    final s = int.tryParse(v ?? '');
    return s == null ? null : Duration(seconds: s);
  }
}

class _CacheEntry {
  final String etag;
  final Json body;
  _CacheEntry(this.etag, this.body);
}
