import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tve_kit/tve_kit.dart';

void main() {
  testWidgets('splash → onglets générés depuis l\'API, design appliqué', (tester) async {
    final api = TveClient(
      group: 'leraltv',
      httpClient: MockClient((r) async {
        final body = r.url.path.endsWith('/leraltv')
            ? File('test/fixtures/group.json').readAsStringSync()
            : '{"data":[],"meta":{}}';
        return http.Response.bytes(utf8.encode(body), 200, headers: {'content-type': 'application/json'});
      }),
    );

    await tester.pumpWidget(TveApp(
      client: api,
      config: const TveConfig(
        group: 'leraltv',
        initialSection: TveSection.about,
        strings: TveStrings(live: 'TV Live'),
      ),
      design: const TveDesign(
        primary: Color(0xFF0057B8),
        splashMinDuration: Duration.zero,
        themeMode: ThemeMode.light,
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('TV Live'), findsOneWidget);
    expect(find.text('Radio'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('À propos'), findsWidgets);
    expect(find.text('Actualités'), findsNothing); // pas de collection "news" pour ce groupe
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);

    final ctx = tester.element(find.byType(TveHome));
    expect(Theme.of(ctx).colorScheme.primary, const Color(0xFF0057B8));
    expect(TveScope.of(ctx).appName, 'MY APP');
  });

  testWidgets('splashBuilder remplace le splash par défaut', (tester) async {
    final api = TveClient(
      group: 'leraltv',
      httpClient: MockClient((r) async => http.Response('{}', 500)),
    );
    await tester.pumpWidget(TveApp(
      client: api,
      config: const TveConfig(group: 'leraltv'),
      design: TveDesign(
        splashMinDuration: Duration.zero,
        splashBuilder: (context, error, onRetry) =>
            Text(error == null ? 'MON SPLASH' : 'ERREUR', textDirection: TextDirection.ltr),
      ),
    ));
    expect(find.text('MON SPLASH'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.text('ERREUR'), findsOneWidget);
  });

  testWidgets('homeBuilder remplace la coquille, sous TveScope', (tester) async {
    final api = TveClient(
      group: 'leraltv',
      httpClient: MockClient((r) async => http.Response.bytes(
          utf8.encode(File('test/fixtures/group.json').readAsStringSync()), 200,
          headers: {'content-type': 'application/json'})),
    );
    await tester.pumpWidget(TveApp(
      client: api,
      config: const TveConfig(group: 'leraltv'),
      design: TveDesign(
        splashMinDuration: Duration.zero,
        homeBuilder: (context) => Scaffold(body: Text('HOME ${TveScope.of(context).group.code}')),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.text('HOME leraltv'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
