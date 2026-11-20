import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/tve_client.dart';
import '../models/group.dart';
import 'tve_config.dart';

/// Construit un écran de démarrage personnalisé (voir [TveDesign.splashBuilder]).
typedef TveSplashBuilder = Widget Function(BuildContext context, Object? error, VoidCallback onRetry);

/// LE DESIGN D'UNE APP.
///
/// Tout est optionnel : sans rien, l'app prend la couleur `branding.primary_color`
/// et le logo `branding.logo` renvoyés par l'API.
class TveDesign {
  /// Couleur principale. Défaut : `branding.primary_color` de l'API, sinon [fallbackPrimary].
  final Color? primary;
  final Color fallbackPrimary;

  /// Couleur secondaire (accents, badges « LIVE »…). Défaut : dérivée de [primary].
  final Color? secondary;

  /// Fonds en clair / sombre. Défaut : Material 3.
  final Color? backgroundLight;
  final Color? backgroundDark;

  /// Mode clair / sombre / système.
  final ThemeMode themeMode;

  /// Nom d'une police Google Fonts, ex: `'Poppins'`, `'Montserrat'`.
  final String? googleFont;

  /// Police embarquée dans l'app (prioritaire sur [googleFont]).
  final String? fontFamily;

  /// Logo local (`assets/images/logo.png`). Défaut : logo de l'API.
  final String? logoAsset;

  /// Splash : couleur de fond et image locale optionnelle.
  final Color? splashBackground;
  final String? splashImageAsset;

  /// Durée minimale du splash.
  final Duration splashMinDuration;

  /// Splash 100 % personnalisé (remplace le splash par défaut).
  ///
  /// `error` est non nul si le chargement du groupe a échoué : affichez alors
  /// par exemple `TveErrorView(error: error, onRetry: onRetry)`.
  final TveSplashBuilder? splashBuilder;

  /// Travail lancé pendant le splash, une fois le groupe chargé (ex. précharger
  /// les contenus de l'accueil). Le splash attend la fin de ce travail et de
  /// [splashMinDuration]. Les erreurs sont ignorées.
  final Future<void> Function(TveClient api, TveGroup group)? preload;

  /// Arrondi des cartes et vignettes.
  final double radius;

  /// Icônes des onglets (surcharge).
  final Map<TveSection, IconData> icons;

  /// Remplace la coquille de l'app (AppBar + barre d'onglets) par la vôtre,
  /// par exemple une navigation par menu latéral. Construit sous [TveScope] :
  /// `TveScope.of(context)` et `defaultSectionScreen(section)` sont utilisables.
  final WidgetBuilder? homeBuilder;

  /// Remplace complètement l'écran d'une section par le vôtre.
  final Map<TveSection, WidgetBuilder> screens;

  /// Pour aller plus loin : modifier le ThemeData généré.
  final ThemeData Function(ThemeData base)? themeBuilder;

  const TveDesign({
    this.primary,
    this.fallbackPrimary = const Color(0xFFE30613),
    this.secondary,
    this.backgroundLight,
    this.backgroundDark,
    this.themeMode = ThemeMode.system,
    this.googleFont,
    this.fontFamily,
    this.logoAsset,
    this.splashBackground,
    this.splashImageAsset,
    this.splashMinDuration = const Duration(milliseconds: 1200),
    this.splashBuilder,
    this.preload,
    this.radius = 12,
    this.icons = const {},
    this.screens = const {},
    this.homeBuilder,
    this.themeBuilder,
  });

  static const defaultIcons = <TveSection, IconData>{
    TveSection.live: Icons.live_tv_rounded,
    TveSection.radio: Icons.radio_rounded,
    TveSection.replay: Icons.video_library_rounded,
    TveSection.shorts: Icons.smart_display_rounded,
    TveSection.news: Icons.article_rounded,
    TveSection.schedule: Icons.calendar_month_rounded,
    TveSection.podcasts: Icons.podcasts_rounded,
    TveSection.about: Icons.info_outline_rounded,
  };

  IconData iconFor(TveSection s) => icons[s] ?? defaultIcons[s]!;

  /// Couleur effective, en tenant compte de la couleur renvoyée par l'API.
  Color resolvePrimary(String? apiColor) => primary ?? parseHexColor(apiColor) ?? fallbackPrimary;

  ThemeData theme(Brightness brightness, {String? apiPrimaryColor}) {
    final seed = resolvePrimary(apiPrimaryColor);
    var scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    scheme = scheme.copyWith(
      primary: brightness == Brightness.light ? seed : scheme.primary,
      secondary: secondary ?? scheme.secondary,
      surface: brightness == Brightness.light ? backgroundLight : backgroundDark,
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    var t = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      cardTheme: CardThemeData(shape: shape, clipBehavior: Clip.antiAlias, margin: EdgeInsets.zero),
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
    if (fontFamily == null && googleFont != null) {
      t = t.copyWith(textTheme: GoogleFonts.getTextTheme(googleFont!, t.textTheme));
    }
    return themeBuilder?.call(t) ?? t;
  }
}

/// `#RRGGBB`, `RRGGBB`, `#AARRGGBB` → Color.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return (h.length == 8 && v != null) ? Color(v) : null;
}
