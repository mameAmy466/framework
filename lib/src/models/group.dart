import 'json.dart';

/// Racine d'un groupe (= une app) : branding, config mobile, collections disponibles.
class TveGroup {
  final String code;
  final String name;
  final String? language;
  final String? timezone;
  final TveBranding branding;
  final String? aboutHtml;
  final String? privacyPolicyHtml;
  final TveSocial social;
  final TveMobileConfig mobile;
  final TveFeatures features;
  final List<TveCollectionInfo> collections;
  final String url;
  final Json raw;

  const TveGroup({
    required this.code,
    required this.name,
    this.language,
    this.timezone,
    required this.branding,
    this.aboutHtml,
    this.privacyPolicyHtml,
    required this.social,
    required this.mobile,
    required this.features,
    required this.collections,
    required this.url,
    this.raw = const {},
  });

  /// Vrai si la collection (ex: `"news"`, `"external-videos"`) est disponible
  /// pour ce groupe (droits + au moins un élément visible).
  bool has(String collection) => collections.any((c) => c.name == collection);

  /// Groupe partagé (ex. aCAS) + configuration d'app propre à une chaîne
  /// (`GET /channels/{slug}?include=app` → `app`) : ses `branding`, `about`,
  /// `privacy_policy`, `social` et `mobile` remplacent ceux du groupe.
  TveGroup withChannelApp(Json app) {
    if (app.isEmpty) return this;
    final merged = Map<String, Object?>.of(raw);
    for (final k in const ['branding', 'about', 'privacy_policy', 'social', 'mobile']) {
      if (app.containsKey(k) && app[k] != null) merged[k] = app[k];
    }
    return TveGroup.fromJson(merged);
  }

  factory TveGroup.fromJson(Json j) => TveGroup(
        code: str(j['code']) ?? '',
        name: str(j['name']) ?? '',
        language: str(j['language']),
        timezone: str(j['timezone']),
        branding: TveBranding.fromJson(asJson(j['branding'])),
        aboutHtml: str(j['about']),
        privacyPolicyHtml: str(j['privacy_policy']),
        social: TveSocial.fromJson(asJson(j['social'])),
        mobile: TveMobileConfig.fromJson(asJson(j['mobile'])),
        features: TveFeatures.fromJson(asJson(j['features'])),
        collections: listOf(j['collections'], TveCollectionInfo.fromJson),
        url: str(j['url']) ?? '',
        raw: j,
      );
}

class TveBranding {
  final String? appName, logo, primaryColor, website, email, phone, author, developedBy, version;

  const TveBranding({
    this.appName,
    this.logo,
    this.primaryColor,
    this.website,
    this.email,
    this.phone,
    this.author,
    this.developedBy,
    this.version,
  });

  factory TveBranding.fromJson(Json j) => TveBranding(
        appName: str(j['app_name']),
        logo: str(j['logo']),
        primaryColor: str(j['primary_color']),
        website: str(j['website']),
        email: str(j['email']),
        phone: str(j['phone']),
        author: str(j['author']),
        developedBy: str(j['developed_by']),
        version: str(j['version']),
      );
}

class TveSocial {
  final String? facebook, twitter, instagram, youtube, youtubeChannelId;

  const TveSocial({this.facebook, this.twitter, this.instagram, this.youtube, this.youtubeChannelId});

  factory TveSocial.fromJson(Json j) => TveSocial(
        facebook: str(j['facebook']),
        twitter: str(j['twitter']),
        instagram: str(j['instagram']),
        youtube: str(j['youtube']),
        youtubeChannelId: str(j['youtube_channel_id']),
      );

  /// Paires (réseau, url) non nulles.
  Map<String, String> get all => {
        if (facebook != null) 'facebook': facebook!,
        if (twitter != null) 'twitter': twitter!,
        if (instagram != null) 'instagram': instagram!,
        if (youtube != null) 'youtube': youtube!,
      };
}

class TveMobileConfig {
  final String? androidAppId, iosAppId, defaultSection;
  final TveAdsConfig ads;

  const TveMobileConfig({this.androidAppId, this.iosAppId, this.defaultSection, required this.ads});

  factory TveMobileConfig.fromJson(Json j) => TveMobileConfig(
        androidAppId: str(j['android_app_id']),
        iosAppId: str(j['ios_app_id']),
        defaultSection: str(j['default_section']),
        ads: TveAdsConfig.fromJson(asJson(j['ads'])),
      );
}

class TveAdsConfig {
  final String? publisherId;
  final bool interstitialEnabled, bannerEnabled;
  final String? interstitialAndroidUnitId, interstitialIosUnitId, bannerAndroidUnitId, bannerIosUnitId;
  final int? interstitialClickFrequency;

  const TveAdsConfig({
    this.publisherId,
    this.interstitialEnabled = false,
    this.bannerEnabled = false,
    this.interstitialAndroidUnitId,
    this.interstitialIosUnitId,
    this.bannerAndroidUnitId,
    this.bannerIosUnitId,
    this.interstitialClickFrequency,
  });

  factory TveAdsConfig.fromJson(Json j) {
    final i = asJson(j['interstitial']), b = asJson(j['banner']);
    return TveAdsConfig(
      publisherId: str(j['publisher_id']),
      interstitialEnabled: toBool(i['enabled']),
      interstitialAndroidUnitId: str(i['android_unit_id']),
      interstitialIosUnitId: str(i['ios_unit_id']),
      interstitialClickFrequency: toInt(i['click_frequency']),
      bannerEnabled: toBool(b['enabled']),
      bannerAndroidUnitId: str(b['android_unit_id']),
      bannerIosUnitId: str(b['ios_unit_id']),
    );
  }
}

class TveFeatures {
  final bool news, podcasts, ads, geoblocking;

  const TveFeatures({this.news = false, this.podcasts = false, this.ads = false, this.geoblocking = false});

  factory TveFeatures.fromJson(Json j) => TveFeatures(
        news: toBool(j['news']),
        podcasts: toBool(j['podcasts']),
        ads: toBool(j['ads']),
        geoblocking: toBool(j['geoblocking']),
      );
}

class TveCollectionInfo {
  final String name;
  final String url;
  final List<String> filters;

  const TveCollectionInfo({required this.name, required this.url, this.filters = const []});

  factory TveCollectionInfo.fromJson(Json j) =>
      TveCollectionInfo(name: str(j['name']) ?? '', url: str(j['url']) ?? '', filters: strings(j['filters']));
}
