import 'package:flutter/widgets.dart';

import '../api/tve_client.dart';
import '../config/tve_config.dart';
import '../config/tve_design.dart';
import '../config/tve_strings.dart';
import '../models/group.dart';

/// Accès partout dans l'arbre au client, à la config, au design et au groupe chargé.
/// `final tve = TveScope.of(context); tve.api.listNews();`
class TveScope extends InheritedWidget {
  final TveClient api;
  final TveConfig config;
  final TveDesign design;
  final TveGroup group;
  final List<TveSection> sections;

  const TveScope({
    super.key,
    required this.api,
    required this.config,
    required this.design,
    required this.group,
    required this.sections,
    required super.child,
  });

  static TveScope of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<TveScope>();
    assert(s != null, 'TveScope introuvable : utilisez runTveApp() ou TveApp.');
    return s!;
  }

  /// Comme [of], mais renvoie null hors d'une app TVE.
  static TveScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TveScope>();

  TveStrings get strings => config.strings;

  String get appName => config.appName ?? group.branding.appName ?? group.name;

  String? get playStoreUrl =>
      config.playStoreUrl ??
      (group.mobile.androidAppId == null
          ? null
          : 'https://play.google.com/store/apps/details?id=${group.mobile.androidAppId}');

  String? get appStoreUrl =>
      config.appStoreUrl ??
      (group.mobile.iosAppId == null ? null : 'https://apps.apple.com/app/id${group.mobile.iosAppId}');

  String shareText(String title) => config.shareTemplate
      .replaceAll('{title}', title)
      .replaceAll('{app}', appName)
      .replaceAll('{playstore}', playStoreUrl ?? '')
      .replaceAll('{appstore}', appStoreUrl ?? '');

  /// Filtre de chaînes de la config (null = toutes).
  List<String>? get channelFilter => config.channelFilter;

  @override
  bool updateShouldNotify(TveScope old) =>
      old.group != group || old.config != config || old.design != design || old.sections != sections;
}

/// Calcule les sections à afficher à partir des collections déclarées par l'API.
List<TveSection> resolveSections(TveConfig config, TveGroup group) {
  if (config.sections != null) {
    return config.sections!.where((s) => !config.hiddenSections.contains(s)).toList();
  }
  final auto = <TveSection>[
    if (group.has('channels')) ...[TveSection.live, TveSection.radio],
    if (group.has('videos') || group.has('external-videos')) TveSection.replay,
    if (group.has('shorts')) TveSection.shorts,
    if (group.has('news')) TveSection.news,
    if (group.has('shows')) TveSection.schedule,
    if (group.has('audios')) TveSection.podcasts,
    TveSection.about,
  ];
  return auto.where((s) => !config.hiddenSections.contains(s)).toList();
}

/// `mobile.default_section` de l'API → section.
TveSection? sectionFromApi(String? v) => switch (v) {
      'live' || 'tv' || 'direct' => TveSection.live,
      'radio' => TveSection.radio,
      'replay' || 'videos' || 'youtube' => TveSection.replay,
      'shorts' => TveSection.shorts,
      'news' => TveSection.news,
      'schedule' => TveSection.schedule,
      'podcasts' || 'audios' => TveSection.podcasts,
      _ => null,
    };
