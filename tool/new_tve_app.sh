#!/usr/bin/env bash
# Crée une nouvelle app TVE prête à lancer.
#
#   ./tool/new_tve_app.sh <dossier_app> <code_groupe> [org] [couleur_hex]
#
# Exemple :
#   ./tool/new_tve_app.sh ../dtv_senegal dtv com.acangroup "#0057B8"
#
# Variables d'environnement optionnelles :
#   TVE_KIT_REF=v0.1.0     version du framework (tag/branche/commit, défaut main)
#   TVE_KIT_PATH=../framework  utiliser une copie locale du framework
#
# Ensuite : modifiez lib/main.dart (TveConfig = variables, TveDesign = design),
# placez votre logo dans assets/images/logo.png, puis `flutter run`.
set -euo pipefail

APP_DIR="${1:?Usage: new_tve_app.sh <dossier_app> <code_groupe> [org] [couleur_hex]}"
GROUP="${2:?Code du groupe TVE manquant (ex: leraltv)}"
ORG="${3:-com.acangroup}"
COLOR="${4:-#E30613}"
NAME="$(basename "$APP_DIR" | tr '[:upper:]-' '[:lower:]_')"

flutter create --org "$ORG" --project-name "$NAME" --platforms android,ios,web "$APP_DIR"
cd "$APP_DIR"

# Dépendance vers le framework :
#   - par défaut : dépôt git https://github.com/mameAmy466/framework (ref TVE_KIT_REF, défaut main)
#   - TVE_KIT_PATH=/chemin/vers/framework : dépendance locale (pour développer le framework)
python3 - "${TVE_KIT_PATH:-}" "${TVE_KIT_REF:-main}" "$PWD" <<'PY'
import os, re, sys
kit_path, ref, app = sys.argv[1], sys.argv[2], sys.argv[3]
if kit_path:
    dep = "  tve_kit:\n    path: %s\n" % os.path.relpath(kit_path, app)
else:
    dep = ("  tve_kit:\n    git:\n      url: https://github.com/mameAmy466/framework.git\n"
           "      ref: %s\n" % ref)
p = 'pubspec.yaml'; s = open(p).read()
s = s.replace("dependencies:\n  flutter:\n    sdk: flutter\n", "dependencies:\n  flutter:\n    sdk: flutter\n" + dep, 1)
s = re.sub(r"^flutter:\n", "flutter:\n  assets:\n    - assets/images/\n", s, count=1, flags=re.M)
open(p, 'w').write(s)
PY
mkdir -p assets/images && touch assets/images/.gitkeep
python3 - <<'PY'
p = 'analysis_options.yaml'; s = open(p).read()
block = "  errors:\n    deprecated_member_use: ignore\n"
s = s.replace("analyzer:\n", "analyzer:\n" + block, 1) if "analyzer:\n" in s else s + "\nanalyzer:\n" + block
open(p, 'w').write(s)
PY

HEX="${COLOR#\#}"
cat > lib/main.dart <<DART
import 'package:flutter/material.dart';
import 'package:tve_kit/tve_kit.dart';

/// ─── VARIABLES ────────────────────────────────────────────────────────────
/// Seul \`group\` est obligatoire : le reste vient de l'API
/// (https://tveapi.acan.group/v3/groups/$GROUP) et peut être surchargé ici.
const config = TveConfig(
  group: '$GROUP',
  // appName: 'Mon App',
  // sections: [TveSection.live, TveSection.radio, TveSection.replay, TveSection.about],
  // hiddenSections: {TveSection.schedule},
  // defaultChannel: 'slug-de-la-chaine',
  // playStoreUrl: 'https://play.google.com/store/apps/details?id=$ORG.$NAME',
  // appStoreUrl: 'https://apps.apple.com/app/id000000000',
  // strings: TveStrings(live: 'En direct'),
);

/// ─── DESIGN ───────────────────────────────────────────────────────────────
const design = TveDesign(
  primary: Color(0xFF$HEX),
  // googleFont: 'Poppins',
  // logoAsset: 'assets/images/logo.png',
  // splashBackground: Colors.black,
  // themeMode: ThemeMode.dark,
  // radius: 16,
);

void main() => runTveApp(config: config, design: design);
DART

# Test de base (remplace le test « compteur » de flutter create).
cat > test/widget_test.dart <<DART
import 'package:flutter_test/flutter_test.dart';

import 'package:$NAME/main.dart';

void main() {
  test('config', () => expect(config.group, '$GROUP'));
}
DART

# Android : accès internet (release) + trafic HTTP clair pour certains flux radio.
MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ] && ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i.bak 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application android:usesCleartextTraffic="true"#' "$MANIFEST" && rm -f "$MANIFEST.bak"
fi

# iOS : autoriser les flux HTTP non chiffrés + lecture audio en arrière-plan.
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! grep -q NSAppTransportSecurity "$PLIST"; then
  python3 - "$PLIST" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
extra = """	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<true/>
	</dict>
	<key>UIBackgroundModes</key>
	<array>
		<string>audio</string>
	</array>
"""
i = s.rfind("</dict>")
open(p, 'w').write(s[:i] + extra + s[i:])
PY
fi

flutter pub get
echo
echo "✅ App créée dans $APP_DIR (groupe: $GROUP)"
echo "   1. Modifiez lib/main.dart (variables + design)"
echo "   2. Ajoutez votre logo dans assets/images/"
echo "   3. flutter run"
