# tve_kit — framework Flutter pour l'API TVE v3

Le framework aCAN pour construire une app TV/Radio sur l'API
[`https://tveapi.acan.group/v3`](https://tveapi.acan.group/v3/docs).

**Une nouvelle app = des variables (`TveConfig`) + un design (`TveDesign`).**
Le reste (client API, modèles, écrans, lecteurs, pagination, erreurs) est fourni.

```dart
import 'package:flutter/material.dart';
import 'package:tve_kit/tve_kit.dart';

void main() => runTveApp(
  config: const TveConfig(group: 'leraltv'),          // ← variables
  design: const TveDesign(                            // ← design
    primary: Color(0xFFE30613),
    googleFont: 'Poppins',
    logoAsset: 'assets/images/logo.png',
  ),
);
```

---

## 1. Créer une nouvelle app (1 commande)

```bash
git clone https://github.com/mameAmy466/framework.git
./framework/tool/new_tve_app.sh dtv_senegal dtv com.acangroup "#0057B8"
```

Arguments : `<dossier> <code_groupe> [org] [couleur]`. Le script :

- lance `flutter create` (android, ios, web) ;
- ajoute la dépendance git `tve_kit` (version : `TVE_KIT_REF=<tag ou commit>`, défaut `main`) et le dossier `assets/images/` ;
- écrit un `lib/main.dart` avec un bloc **VARIABLES** et un bloc **DESIGN** à compléter ;
- configure Android (INTERNET, flux HTTP) et iOS (flux HTTP, audio en arrière-plan).

Ensuite : déposez le logo dans `assets/images/`, ajustez `lib/main.dart`, puis lancez `flutter run`.
`example/` a été généré avec ce script pour `leraltv`.

### Ajouter le framework à une app existante

```yaml
dependencies:
  tve_kit:
    git:
      url: https://github.com/mameAmy466/framework.git
      ref: main   # en production, figez une version : un tag (ex. v0.1.0) ou un commit
```

## 2. Les variables — `TveConfig`

Seul `group` est obligatoire. Tout le reste est lu depuis `GET /groups/{group}` (nom,
logo, couleur, réseaux sociaux, IDs des stores, section par défaut, collections
disponibles…). Chaque valeur donnée ici **remplace** celle de l'API.

| Variable | Rôle | Par défaut |
|---|---|---|
| `group` | Code du groupe TVE (`leraltv`, `dtv`…) | **obligatoire** |
| `baseUrl` | URL de l'API | `https://tveapi.acan.group/v3` |
| `appName` | Nom affiché | `branding.app_name` puis `name` |
| `sections` | Onglets, dans l'ordre | automatique, selon les collections de l'API |
| `hiddenSections` | Onglets à masquer | aucun |
| `initialSection` | Onglet ouvert au démarrage | `mobile.default_section` |
| `customTabs` | Onglets 100 % maison | aucun |
| `defaultChannel` | Chaîne TV jouée en premier (slug) | la première |
| `channels` | Limiter l'app à certaines chaînes (slugs) | toutes |
| `playStoreUrl` / `appStoreUrl` | Liens utilisés dans le partage | construits depuis `mobile.*_app_id` |
| `shareTemplate` | Texte de partage (`{title}`, `{app}`, `{playstore}`, `{appstore}`) | texte FR |
| `pageSize` | Taille des pages des listes | 20 |
| `strings` | Tous les textes de l'UI (`TveStrings`) | français |
| `headers` | En-têtes HTTP en plus | aucun |
| `youtubeOrigin` | Site déclaré à YouTube pour le lecteur intégré (évite les erreurs 152/153) | `branding.website` |

Sections disponibles : `live`, `radio`, `replay`, `shorts`, `news`, `schedule`, `podcasts`, `about`.
En mode automatique, une section n'apparaît que si l'API déclare la collection
correspondante pour le groupe. Pour `leraltv` aujourd'hui : Direct, Radio, Replay
(YouTube) et À propos.

**Plusieurs apps, un seul code :** `TveConfig.fromEnvironment()` lit les valeurs passées au build.

```bash
flutter build apk --dart-define=TVE_GROUP=dtv --dart-define=TVE_APP_NAME="DTV Sénégal"
```

## 3. Le design — `TveDesign`

| Propriété | Rôle |
|---|---|
| `primary` / `secondary` | Couleurs. Sans `primary`, l'app prend `branding.primary_color` de l'API |
| `backgroundLight` / `backgroundDark` | Couleurs de fond |
| `themeMode` | `system`, `light` ou `dark` |
| `googleFont` / `fontFamily` | Police Google Fonts, ou police embarquée |
| `logoAsset` | Logo local. Sans lui, l'app prend le logo de l'API |
| `splashBackground` / `splashImageAsset` / `splashMinDuration` | Écran de démarrage |
| `splashBuilder` | Écran de démarrage 100 % personnalisé `(context, error, onRetry)` |
| `preload` | Préchargement pendant le splash `(api, group)`, ex. contenus de l'accueil |
| `radius` | Arrondi des cartes |
| `icons` | Icônes des onglets |
| `screens` | **Remplacer l'écran d'une section** par le vôtre |
| `homeBuilder` | Remplacer la coquille (AppBar + onglets), ex. navigation par menu latéral |
| `themeBuilder` | Retouche libre du `ThemeData` généré |

```dart
TveDesign(
  primary: const Color(0xFF0057B8),
  themeMode: ThemeMode.dark,
  screens: {TveSection.live: (_) => const MonEcranDirect()},
)
```

Dans vos propres écrans, `TveScope.of(context)` donne accès à `api`, `group`, `config`, `design` et `strings`.

## 4. Le client API seul — `TveClient`

Toutes les routes de l'API sont couvertes (31 au total), avec des modèles typés.

```dart
final api = TveClient(group: 'leraltv');

final group    = await api.getGroup();
final channels = await api.listChannels(kind: ['tv']);
final live     = await api.getChannelLive('leral-tv');          // URL HLS signée
final yt       = await api.listExternalVideos(feed: ['live-streams'], limit: 10);
final next     = await api.listExternalVideos(cursor: yt.nextCursor);
final results  = await api.search('magal');                     // sealed TveSearchResult

await for (final v in api.paginate((c) => api.listVideos(cursor: c))) { /* toutes les pages */ }
```

| Domaine | Méthodes |
|---|---|
| Groupe | `getGroup` |
| Chaînes | `listChannels`, `getChannel`, `getChannelLive` |
| Émissions | `listShows`, `getShow` |
| Vidéos | `listVideos`, `getVideo`, `getVideoPlayback` |
| Audios | `listAudios`, `getAudio` |
| Catégories | `listCategories`, `getCategory` |
| Présentateurs | `listPresenters`, `getPresenter` |
| Grille | `listSchedule(date:)`, `listScheduleNow` |
| Actus | `listNews`, `getNews`, `listNewsCategories`, `getNewsCategory` |
| Pubs | `listAds`, `getAd` |
| YouTube | `listExternalVideos`, `getExternalVideo`, `listExternalPlaylists`, `getExternalPlaylist` |
| Shorts | `listShorts`, `getShort`, `getShortPlayback` |
| Recherche | `search` |
| Divers | `paginate`, `getUrl` (pour suivre un lien `links.*`), `clearCache` |

Ce que le client gère tout seul :

- **Cache ETag** en mémoire (`If-None-Match` → 304), sauf pour les URL de lecture, qui ne sont jamais mises en cache ;
- **429** : une nouvelle tentative après `Retry-After` (limite de l'API : 120 requêtes par minute) ;
- **Erreurs** : toutes deviennent une `TveException` (`code`, `status`, `detail`, `isNotFound`, `isNetwork`, `isPlaybackUnavailable`…) ;
- **Filtres en liste** envoyés séparés par des virgules (= OU), conformément à la spec.

## 5. Briques réutilisables

`TvePlaybackPlayer` (HLS, audio, YouTube ; redemande une URL fraîche si la signature a expiré),
`TveYoutubePlayer` (lecture dans l'app : lecteur officiel YouTube en WebView avec Referer valide sur Android/iOS, écran de chargement animé, plein écran), `TveAudioController` (lecteur audio global : la radio continue quand on
change d'onglet), `TvePagedView` (liste ou grille infinie), `TveMediaCard`, `TveImage`, `TveHtml`,
`TveFuture`, `TveErrorView`, `TveEmptyView`.

## 6. Tests

```bash
flutter test                               # 17 tests hors ligne (réponses réelles enregistrées)
TVE_LIVE=1 flutter test test/live_api_test.dart   # contre la vraie API
```

## Points connus

- **Web : l'API renvoie `Access-Control-Allow-Origin: *, *`** (en-tête en double). Les navigateurs
  refusent alors toutes les requêtes. Android et iOS ne sont pas concernés. À corriger côté serveur
  (nginx + application ajoutent chacun l'en-tête).
- **Web : le direct HLS** nécessite hls.js (Chrome ne lit pas le HLS nativement). Mobile : OK.
- `just_audio` sur Android : `minSdkVersion` ≥ 21 (valeur par défaut de `flutter create`).
