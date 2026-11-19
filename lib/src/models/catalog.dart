import 'common.dart';
import 'json.dart';
import 'media.dart';

/// Catégorie d'émissions/vidéos.
class TveCategory {
  final String slug, name, url;
  final String? description, logo;
  final int? order;
  final TveRef? parent;
  final List<TveCategory> children;
  final Map<String, String?> links;
  final Json raw;

  const TveCategory({
    required this.slug,
    required this.name,
    required this.url,
    this.description,
    this.logo,
    this.order,
    this.parent,
    this.children = const [],
    this.links = const {},
    this.raw = const {},
  });

  factory TveCategory.fromJson(Json j) => TveCategory(
        slug: str(j['slug']) ?? '',
        name: str(j['name']) ?? '',
        url: str(j['url']) ?? '',
        description: str(j['description']),
        logo: str(asJson(j['images'])['logo']),
        order: toInt(j['order']),
        parent: TveRef.fromJsonOrNull(j['parent']),
        children: listOf(j['children'], TveCategory.fromJson),
        links: linkMap(j['links']),
        raw: j,
      );
}

/// Animateur / présentateur.
class TvePresenter {
  final String slug, name, firstName, lastName, url;
  final String? bio, photo, poster, facebook, twitter, instagram;
  final int order;
  final Json raw;

  const TvePresenter({
    required this.slug,
    required this.name,
    this.firstName = '',
    this.lastName = '',
    required this.url,
    this.bio,
    this.photo,
    this.poster,
    this.facebook,
    this.twitter,
    this.instagram,
    this.order = 0,
    this.raw = const {},
  });

  factory TvePresenter.fromJson(Json j) {
    final img = asJson(j['images']), s = asJson(j['social']);
    return TvePresenter(
      slug: str(j['slug']) ?? '',
      name: str(j['name']) ?? '',
      firstName: str(j['first_name']) ?? '',
      lastName: str(j['last_name']) ?? '',
      url: str(j['url']) ?? '',
      bio: str(j['bio']),
      photo: str(img['photo']),
      poster: str(img['poster']),
      facebook: str(s['facebook']),
      twitter: str(s['twitter']),
      instagram: str(s['instagram']),
      order: toInt(j['order']) ?? 0,
      raw: j,
    );
  }
}

/// Créneau de grille des programmes.
class TveScheduleSlot {
  final DateTime startsAt, endsAt;
  final bool airing;
  final String showSlug, showTitle;
  final String? showLogo, showPoster;
  final TveRef? channel;
  final Json raw;

  const TveScheduleSlot({
    required this.startsAt,
    required this.endsAt,
    required this.airing,
    required this.showSlug,
    required this.showTitle,
    this.showLogo,
    this.showPoster,
    this.channel,
    this.raw = const {},
  });

  factory TveScheduleSlot.fromJson(Json j) {
    final show = asJson(j['show']), img = asJson(show['images']);
    return TveScheduleSlot(
      startsAt: date(j['starts_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endsAt: date(j['ends_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      airing: toBool(j['airing']),
      showSlug: str(show['slug']) ?? '',
      showTitle: str(show['title']) ?? '',
      showLogo: str(img['logo']),
      showPoster: str(img['poster']),
      channel: TveRef.fromJsonOrNull(j['channel']),
      raw: j,
    );
  }
}

/// « En cours / à suivre » pour une chaîne.
class TveChannelNow {
  final TveRef channel;
  final TveScheduleSlot? current, next;

  const TveChannelNow({required this.channel, this.current, this.next});

  factory TveChannelNow.fromJson(Json j) => TveChannelNow(
        channel: TveRef.fromJson(asJson(j['channel'])),
        current: j['current'] is Map ? TveScheduleSlot.fromJson(asJson(j['current'])) : null,
        next: j['next'] is Map ? TveScheduleSlot.fromJson(asJson(j['next'])) : null,
      );
}

/// Article d'actualité. [contentHtml] n'est rempli que sur `getNews`.
class TveNews {
  final String slug, title, url;
  final String? excerpt, contentHtml, image;
  final DateTime? publishedAt;
  final List<TveRef> categories;
  final Json raw;

  const TveNews({
    required this.slug,
    required this.title,
    required this.url,
    this.excerpt,
    this.contentHtml,
    this.image,
    this.publishedAt,
    this.categories = const [],
    this.raw = const {},
  });

  factory TveNews.fromJson(Json j) => TveNews(
        slug: str(j['slug']) ?? '',
        title: str(j['title']) ?? '',
        url: str(j['url']) ?? '',
        excerpt: str(j['excerpt']),
        contentHtml: str(j['content']),
        image: str(asJson(j['images'])['featured']),
        publishedAt: date(j['published_at']),
        categories: listOf(j['categories'], TveRef.fromJson),
        raw: j,
      );
}

class TveNewsCategory {
  final String slug, name, url;
  final int? order;
  final int postsCount;
  final TveRef? parent;
  final List<TveNewsCategory> children;
  final Json raw;

  const TveNewsCategory({
    required this.slug,
    required this.name,
    required this.url,
    this.order,
    this.postsCount = 0,
    this.parent,
    this.children = const [],
    this.raw = const {},
  });

  factory TveNewsCategory.fromJson(Json j) => TveNewsCategory(
        slug: str(j['slug']) ?? '',
        name: str(j['name']) ?? '',
        url: str(j['url']) ?? '',
        order: toInt(j['order']),
        postsCount: toInt(j['posts_count']) ?? 0,
        parent: TveRef.fromJsonOrNull(j['parent']),
        children: listOf(j['children'], TveNewsCategory.fromJson),
        raw: j,
      );
}

/// Publicité. `placement` = web | live | replays | shorts ; `format` = image | video | audio | html.
class TveAd {
  final String slug, name, placement, format, url;
  final List<String> assets;
  final String? html, clickUrl;
  final List<Object> positions;
  final DateTime? startsOn, endsOn;
  final TveRef? channel;
  final Json raw;

  const TveAd({
    required this.slug,
    required this.name,
    required this.placement,
    required this.format,
    required this.url,
    this.assets = const [],
    this.html,
    this.clickUrl,
    this.positions = const [],
    this.startsOn,
    this.endsOn,
    this.channel,
    this.raw = const {},
  });

  factory TveAd.fromJson(Json j) => TveAd(
        slug: str(j['slug']) ?? '',
        name: str(j['name']) ?? '',
        placement: str(j['placement']) ?? '',
        format: str(j['format']) ?? 'image',
        url: str(j['url']) ?? '',
        assets: strings(j['assets']),
        html: str(j['html']),
        clickUrl: str(j['click_url']),
        positions: j['positions'] is List ? (j['positions'] as List).whereType<Object>().toList() : const [],
        startsOn: date(j['starts_on']),
        endsOn: date(j['ends_on']),
        channel: TveRef.fromJsonOrNull(j['channel']),
        raw: j,
      );
}

/// Résultat de recherche : une émission, une vidéo, un audio ou une actu.
sealed class TveSearchResult {
  const TveSearchResult();

  static TveSearchResult? fromJson(Json j) => switch (j['type']) {
        'show' => TveSearchShow(TveShow.fromJson(j)),
        'video' => TveSearchVideo(TveVideo.fromJson(j)),
        'audio' => TveSearchAudio(TveAudio.fromJson(j)),
        'news' => TveSearchNews(TveNews.fromJson(j)),
        _ => null,
      };

  String get title;
  String? get image;
}

class TveSearchShow extends TveSearchResult {
  final TveShow show;
  const TveSearchShow(this.show);
  @override
  String get title => show.title;
  @override
  String? get image => show.image;
}

class TveSearchVideo extends TveSearchResult {
  final TveVideo video;
  const TveSearchVideo(this.video);
  @override
  String get title => video.title;
  @override
  String? get image => video.thumbnail;
}

class TveSearchAudio extends TveSearchResult {
  final TveAudio audio;
  const TveSearchAudio(this.audio);
  @override
  String get title => audio.title;
  @override
  String? get image => audio.thumbnail;
}

class TveSearchNews extends TveSearchResult {
  final TveNews news;
  const TveSearchNews(this.news);
  @override
  String get title => news.title;
  @override
  String? get image => news.image;
}
