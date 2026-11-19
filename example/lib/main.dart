import 'package:flutter/material.dart';
import 'package:tve_kit/tve_kit.dart';

/// ─── VARIABLES ────────────────────────────────────────────────────────────
/// Seul `group` est obligatoire : le reste vient de l'API
/// (https://tveapi.acan.group/v3/groups/leraltv) et peut être surchargé ici.
const config = TveConfig(
  group: 'leraltv',
  // appName: 'Mon App',
  // sections: [TveSection.live, TveSection.radio, TveSection.replay, TveSection.about],
  // hiddenSections: {TveSection.schedule},
  // defaultChannel: 'slug-de-la-chaine',
  // playStoreUrl: 'https://play.google.com/store/apps/details?id=com.acangroup.example',
  // appStoreUrl: 'https://apps.apple.com/app/id000000000',
  // strings: TveStrings(live: 'En direct'),
);

/// ─── DESIGN ───────────────────────────────────────────────────────────────
const design = TveDesign(
  primary: Color(0xFFE30613),
  // googleFont: 'Poppins',
  logoAsset: 'assets/images/logo.png',
  // splashBackground: Colors.black,
  // themeMode: ThemeMode.dark,
  // radius: 16,
);

void main() => runTveApp(config: config, design: design);
