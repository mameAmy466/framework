import 'common.dart';
import 'json.dart';

enum TveChannelKind { tv, radio, webtv, cinema, acas, unknown }

TveChannelKind _kind(Object? v) =>
    TveChannelKind.values.firstWhere((e) => e.name == v, orElse: () => TveChannelKind.unknown);

/// Une chaîne TV ou radio.
class TveChannel {
  final String slug;
  final String name;
  final TveChannelKind kind;
  final String? description;
  final String? logo;
  final int order;
  final String? frequency;
  final String appConfig;
  final String url;
  final Map<String, String?> links;
  final Json raw;

  const TveChannel({
    required this.slug,
    required this.name,
    required this.kind,
    this.description,
    this.logo,
    this.order = 0,
    this.frequency,
    this.appConfig = 'group',
    required this.url,
    this.links = const {},
    this.raw = const {},
  });

  bool get isRadio => kind == TveChannelKind.radio;

  /// TV au sens large (tv, webtv, cinema, acas).
  bool get isVideo => !isRadio;

  factory TveChannel.fromJson(Json j) => TveChannel(
        slug: str(j['slug']) ?? '',
        name: str(j['name']) ?? '',
        kind: _kind(j['kind']),
        description: str(j['description']),
        logo: str(asJson(j['images'])['logo']),
        order: toInt(j['order']) ?? 0,
        frequency: str(j['frequency']),
        appConfig: str(j['app_config']) ?? 'group',
        url: str(j['url']) ?? '',
        links: linkMap(j['links']),
        raw: j,
      );
}

enum TvePlaybackProtocol { hls, audio, youtube, dailymotion, unknown }

/// Descripteur de lecture (live ou VOD). Jamais mis en cache : les URLs sont signées
/// et expirent à [expiresAt].
class TvePlayback {
  final TvePlaybackProtocol protocol;
  final String url;
  final String? androidUrl;
  final String? webUrl;
  final DateTime? expiresAt;
  final TveRef? channel;
  final TveRef? video;

  const TvePlayback({
    required this.protocol,
    required this.url,
    this.androidUrl,
    this.webUrl,
    this.expiresAt,
    this.channel,
    this.video,
  });

  bool get isExpired => expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt!);

  factory TvePlayback.fromJson(Json j) {
    final u = asJson(j['urls']);
    return TvePlayback(
      protocol: TvePlaybackProtocol.values
          .firstWhere((e) => e.name == j['protocol'], orElse: () => TvePlaybackProtocol.unknown),
      url: str(u['default']) ?? '',
      androidUrl: str(u['android']),
      webUrl: str(u['web']),
      expiresAt: date(j['expires_at']),
      channel: TveRef.fromJsonOrNull(j['channel']),
      video: TveRef.fromJsonOrNull(j['video']),
    );
  }
}

class TveShowSchedule {
  final List<String> days;
  final String? starts, ends;
  final String recurrence;
  final List<int>? weeksOfMonth;
  final bool primary;

  const TveShowSchedule({
    this.days = const [],
    this.starts,
    this.ends,
    this.recurrence = 'daily',
    this.weeksOfMonth,
    this.primary = false,
  });

  factory TveShowSchedule.fromJson(Json j) => TveShowSchedule(
        days: strings(j['days']),
        starts: str(j['starts']),
        ends: str(j['ends']),
        recurrence: str(j['recurrence']) ?? 'daily',
        weeksOfMonth:
            j['weeks_of_month'] is List ? (j['weeks_of_month'] as List).map(toInt).whereType<int>().toList() : null,
        primary: toBool(j['primary']),
      );
}

/// Une émission.
class TveShow {
  final String slug, title, kind, url;
  final String? description, logo, poster, portrait, landscape, timezone;
  final bool featured, airingNow;
  final int? order;
  final TveRef? channel;
  final List<TveRef> categories, presenters;
  final List<TveShowSchedule> schedules;
  final List<TveVideo> videos;
  final List<TveAudio> audios;
  final Map<String, String?> links;
  final Json raw;

  const TveShow({
    required this.slug,
    required this.title,
    required this.kind,
    required this.url,
    this.description,
    this.logo,
    this.poster,
    this.portrait,
    this.landscape,
    this.timezone,
    this.featured = false,
    this.airingNow = false,
    this.order,
    this.channel,
    this.categories = const [],
    this.presenters = const [],
    this.schedules = const [],
    this.videos = const [],
    this.audios = const [],
    this.links = const {},
    this.raw = const {},
  });

  /// Meilleure image disponible pour une vignette paysage.
  String? get image => landscape ?? poster ?? logo ?? portrait;

  factory TveShow.fromJson(Json j) {
    final img = asJson(j['images']);
    return TveShow(
      slug: str(j['slug']) ?? '',
      title: str(j['title']) ?? '',
      kind: str(j['kind']) ?? 'tv',
      url: str(j['url']) ?? '',
      description: str(j['description']),
      logo: str(img['logo']),
      poster: str(img['poster']),
      portrait: str(img['portrait']),
      landscape: str(img['landscape']),
      timezone: str(j['timezone']),
      featured: toBool(j['featured']),
      airingNow: toBool(j['airing_now']),
      order: toInt(j['order']),
      channel: TveRef.fromJsonOrNull(j['channel']),
      categories: listOf(j['categories'], TveRef.fromJson),
      presenters: listOf(j['presenters'], TveRef.fromJson),
      schedules: listOf(j['schedules'], TveShowSchedule.fromJson),
      videos: listOf(asJson(j['videos'])['data'], TveVideo.fromJson),
      audios: listOf(asJson(j['audios'])['data'], TveAudio.fromJson),
      links: linkMap(j['links']),
      raw: j,
    );
  }
}

/// Une vidéo (replay). `source` = vod | youtube | dailymotion.
class TveVideo {
  final String slug, title, source, url;
  final String? description, externalId, thumbnail;
  final int? duration;
  final DateTime? publishedAt;
  final TveRef? show, channel;
  final Map<String, String?> links;
  final Json raw;

  const TveVideo({
    required this.slug,
    required this.title,
    required this.source,
    required this.url,
    this.description,
    this.externalId,
    this.thumbnail,
    this.duration,
    this.publishedAt,
    this.show,
    this.channel,
    this.links = const {},
    this.raw = const {},
  });

  bool get isYoutube => source == 'youtube';

  factory TveVideo.fromJson(Json j) => TveVideo(
        slug: str(j['slug']) ?? '',
        title: str(j['title']) ?? '',
        source: str(j['source']) ?? 'vod',
        url: str(j['url']) ?? '',
        description: str(j['description']),
        externalId: str(j['external_id']),
        thumbnail: str(asJson(j['images'])['thumbnail']),
        duration: toInt(j['duration']),
        publishedAt: date(j['published_at']),
        show: TveRef.fromJsonOrNull(j['show']),
        channel: TveRef.fromJsonOrNull(j['channel']),
        links: linkMap(j['links']),
        raw: j,
      );
}

/// Un audio / podcast.
class TveAudio {
  final String slug, title, origin, url;
  final String? description, provider, mediaUrl, thumbnail;
  final DateTime? publishedAt;
  final TveRef? show, channel;
  final Json raw;

  const TveAudio({
    required this.slug,
    required this.title,
    required this.origin,
    required this.url,
    this.description,
    this.provider,
    this.mediaUrl,
    this.thumbnail,
    this.publishedAt,
    this.show,
    this.channel,
    this.raw = const {},
  });

  factory TveAudio.fromJson(Json j) => TveAudio(
        slug: str(j['slug']) ?? '',
        title: str(j['title']) ?? '',
        origin: str(j['origin']) ?? 'record',
        url: str(j['url']) ?? '',
        description: str(j['description']),
        provider: str(j['provider']),
        mediaUrl: str(j['media_url']),
        thumbnail: str(asJson(j['images'])['thumbnail']),
        publishedAt: date(j['published_at']),
        show: TveRef.fromJsonOrNull(j['show']),
        channel: TveRef.fromJsonOrNull(j['channel']),
        raw: j,
      );
}

/// Un short (vidéo verticale courte).
class TveShort {
  final String slug, title, url;
  final String? description, externalId, thumbnail;
  final int? duration;
  final DateTime? publishedAt;
  final TveRef? show, channel, video;
  final Map<String, String?> links;
  final Json raw;

  const TveShort({
    required this.slug,
    required this.title,
    required this.url,
    this.description,
    this.externalId,
    this.thumbnail,
    this.duration,
    this.publishedAt,
    this.show,
    this.channel,
    this.video,
    this.links = const {},
    this.raw = const {},
  });

  factory TveShort.fromJson(Json j) => TveShort(
        slug: str(j['slug']) ?? '',
        title: str(j['title']) ?? '',
        url: str(j['url']) ?? '',
        description: str(j['description']),
        externalId: str(j['external_id']),
        thumbnail: str(asJson(j['images'])['thumbnail']),
        duration: toInt(j['duration']),
        publishedAt: date(j['published_at']),
        show: TveRef.fromJsonOrNull(j['show']),
        channel: TveRef.fromJsonOrNull(j['channel']),
        video: TveRef.fromJsonOrNull(j['video']),
        links: linkMap(j['links']),
        raw: j,
      );
}

/// Vidéo externe (YouTube) synchronisée par l'API.
class TveExternalVideo {
  final String id, provider, externalId, title, embedUrl, watchUrl, url;
  final String? description, feed, thumbnail;
  final int? duration;
  final DateTime? publishedAt;
  final TveRef? channel;
  final Json raw;

  const TveExternalVideo({
    required this.id,
    required this.provider,
    required this.externalId,
    required this.title,
    required this.embedUrl,
    required this.watchUrl,
    required this.url,
    this.description,
    this.feed,
    this.thumbnail,
    this.duration,
    this.publishedAt,
    this.channel,
    this.raw = const {},
  });

  bool get isShort => feed == 'shorts' || feed == 'popular-shorts';

  factory TveExternalVideo.fromJson(Json j) => TveExternalVideo(
        id: str(j['id']) ?? '',
        provider: str(j['provider']) ?? 'youtube',
        externalId: str(j['external_id']) ?? '',
        title: str(j['title']) ?? '',
        embedUrl: str(j['embed_url']) ?? '',
        watchUrl: str(j['watch_url']) ?? '',
        url: str(j['url']) ?? '',
        description: str(j['description']),
        feed: str(j['feed']),
        thumbnail: str(asJson(j['images'])['thumbnail']),
        duration: toInt(j['duration']),
        publishedAt: date(j['published_at']),
        channel: TveRef.fromJsonOrNull(j['channel']),
        raw: j,
      );
}

/// Playlist externe (YouTube).
class TveExternalPlaylist {
  final String id, provider, externalId, title, url;
  final String? description, thumbnail;
  final int? itemCount;
  final DateTime? publishedAt;
  final TveRef? channel;
  final Json raw;

  const TveExternalPlaylist({
    required this.id,
    required this.provider,
    required this.externalId,
    required this.title,
    required this.url,
    this.description,
    this.thumbnail,
    this.itemCount,
    this.publishedAt,
    this.channel,
    this.raw = const {},
  });

  factory TveExternalPlaylist.fromJson(Json j) => TveExternalPlaylist(
        id: str(j['id']) ?? '',
        provider: str(j['provider']) ?? 'youtube',
        externalId: str(j['external_id']) ?? '',
        title: str(j['title']) ?? '',
        url: str(j['url']) ?? '',
        description: str(j['description']),
        thumbnail: str(asJson(j['images'])['thumbnail']),
        itemCount: toInt(j['item_count']),
        publishedAt: date(j['published_at']),
        channel: TveRef.fromJsonOrNull(j['channel']),
        raw: j,
      );
}
