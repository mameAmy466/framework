import 'package:flutter/widgets.dart';

import '../api/tve_client.dart';
import 'tve_strings.dart';

/// Sections (onglets) que le framework sait afficher.
enum TveSection {
  /// Chaînes TV en direct (HLS).
  live,

  /// Radios en direct.
  radio,

  /// Replays : vidéos VOD de l'API et/ou vidéos YouTube synchronisées.
  replay,

  /// Shorts (vidéos courtes verticales).
  shorts,

  /// Actualités.
  news,

  /// Grille des programmes.
  schedule,

  /// Podcasts / audios.
  podcasts,

  /// À propos, contacts, réseaux sociaux, politique de confidentialité.
  about,
}

/// Onglet 100 % personnalisé ajouté par une app.
class TveCustomTab {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;

  const TveCustomTab({required this.label, required this.icon, required this.builder});
}

/// LES VARIABLES D'UNE APP.
///
/// Seul [group] est obligatoire : tout le reste (nom, logo, réseaux sociaux,
/// sections disponibles…) est lu depuis l'API (`GET /groups/{group}`).
/// Chaque champ renseigné ici écrase la valeur de l'API.
class TveConfig {
  /// Code du groupe dans le back-office TVE, ex: `leraltv`.
  final String group;

  /// URL de base de l'API.
  final String baseUrl;

  /// Nom de l'app. Défaut : `branding.app_name` puis `name` du groupe.
  final String? appName;

  /// Sections à afficher, dans l'ordre. `null` = automatique selon les
  /// collections que l'API déclare disponibles pour le groupe.
  final List<TveSection>? sections;

  /// Sections à masquer même si l'API les rend disponibles.
  final Set<TveSection> hiddenSections;

  /// Section ouverte au démarrage. Défaut : `mobile.default_section` de l'API, sinon la première.
  final TveSection? initialSection;

  /// Onglets supplémentaires propres à l'app (ajoutés après les sections).
  final List<TveCustomTab> customTabs;

  /// Chaîne TV mise en avant (slug). Défaut : la première par `order`.
  final String? defaultChannel;

  /// Limiter l'app à certaines chaînes (slugs). Vide = toutes.
  final List<String> channels;

  /// Liens magasins pour le partage. Défaut : construits depuis
  /// `mobile.android_app_id` / `mobile.ios_app_id`.
  final String? playStoreUrl;
  final String? appStoreUrl;

  /// Texte de partage. `{title}`, `{app}`, `{playstore}`, `{appstore}` sont remplacés.
  final String shareTemplate;

  /// Nombre d'éléments par page dans les listes.
  final int pageSize;

  /// Textes de l'interface (français par défaut).
  final TveStrings strings;

  /// En-têtes HTTP ajoutés à chaque requête API.
  final Map<String, String> headers;

  /// Site déclaré à YouTube comme intégrant le lecteur (Referer), ex.
  /// `https://www.ouest.tv`. Défaut : `branding.website` du groupe.
  final String? youtubeOrigin;

  const TveConfig({
    required this.group,
    this.baseUrl = TveClient.defaultBaseUrl,
    this.appName,
    this.sections,
    this.hiddenSections = const {},
    this.initialSection,
    this.customTabs = const [],
    this.defaultChannel,
    this.channels = const [],
    this.playStoreUrl,
    this.appStoreUrl,
    this.shareTemplate = '{title}\n\nTéléchargez {app} :\nAndroid : {playstore}\niOS : {appstore}',
    this.pageSize = 20,
    this.strings = const TveStrings(),
    this.headers = const {},
    this.youtubeOrigin,
  });

  /// Lit les variables passées au build :
  /// `flutter run --dart-define=TVE_GROUP=leraltv --dart-define=TVE_BASE_URL=...`
  /// Pratique pour compiler plusieurs apps depuis un même code.
  factory TveConfig.fromEnvironment({
    String? fallbackGroup,
    List<TveSection>? sections,
    TveStrings strings = const TveStrings(),
  }) {
    const g = String.fromEnvironment('TVE_GROUP');
    const base = String.fromEnvironment('TVE_BASE_URL', defaultValue: TveClient.defaultBaseUrl);
    const name = String.fromEnvironment('TVE_APP_NAME');
    const channel = String.fromEnvironment('TVE_DEFAULT_CHANNEL');
    final group = g.isNotEmpty ? g : fallbackGroup;
    if (group == null || group.isEmpty) {
      throw StateError('TVE_GROUP manquant : --dart-define=TVE_GROUP=<code du groupe>');
    }
    return TveConfig(
      group: group,
      baseUrl: base,
      appName: name.isEmpty ? null : name,
      defaultChannel: channel.isEmpty ? null : channel,
      sections: sections,
      strings: strings,
    );
  }
}
