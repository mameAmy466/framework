import 'dart:async';
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

    // Une page poussée par le Navigator a aussi accès à TveScope.
    final nav = Navigator.of(tester.element(find.text('HOME leraltv')));
    nav.push(MaterialPageRoute<void>(builder: (c) => Text('PAGE ${TveScope.of(c).group.code}')));
    await tester.pumpAndSettle();
    expect(find.text('PAGE leraltv'), findsOneWidget);
  });

  test('origine YouTube normalisée', () {
    expect(TveYoutubePlayer.normalizeOrigin('www.acan.group'), 'https://www.acan.group');
    expect(TveYoutubePlayer.normalizeOrigin('https://www.ouest.tv/fr/'), 'https://www.ouest.tv');
    expect(TveYoutubePlayer.normalizeOrigin(''), isNull);
    expect(TveYoutubePlayer.normalizeOrigin(null), isNull);
  });

  testWidgets('preload est attendu pendant le splash', (tester) async {
    final api = TveClient(
      group: 'leraltv',
      httpClient: MockClient(
        (r) async => http.Response.bytes(
          utf8.encode(File('test/fixtures/group.json').readAsStringSync()),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final done = Completer<void>();
    String? seen;
    await tester.pumpWidget(
      TveApp(
        client: api,
        config: const TveConfig(group: 'leraltv'),
        design: TveDesign(
          splashMinDuration: Duration.zero,
          preload: (api, group) {
            seen = group.code;
            return done.future;
          },
          homeBuilder: (_) => const Text('HOME', textDirection: TextDirection.ltr),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(seen, 'leraltv');
    expect(find.text('HOME'), findsNothing); // toujours sur le splash
    done.complete();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('appChannel (aCAS) : config d\'app de la chaîne + filtre', (tester) async {
    Uri? channelUrl;
    final api = TveClient(
      group: 'acasgroup',
      httpClient: MockClient((r) async {
        final String body;
        if (r.url.path.endsWith('/channels/ouest-tv')) {
          channelUrl = r.url;
          body = jsonEncode({
            'data': {
              'type': 'channel',
              'slug': 'ouest-tv',
              'name': 'Ouest TV',
              'kind': 'acas',
              'url': 'x',
              'app': {
                'branding': {'app_name': 'Ouest TV', 'website': 'https://www.ouest.tv'},
                'social': {'youtube': 'https://www.youtube.com/@chaineouesttv'},
                'about': '<p>Ouest</p>',
              },
            },
          });
        } else {
          body = File('test/fixtures/group.json').readAsStringSync();
        }
        return http.Response.bytes(utf8.encode(body), 200, headers: {'content-type': 'application/json'});
      }),
    );
    await tester.pumpWidget(
      TveApp(
        client: api,
        config: const TveConfig(group: 'acasgroup', appChannel: 'ouest-tv'),
        design: TveDesign(
          splashMinDuration: Duration.zero,
          homeBuilder: (context) {
            final tve = TveScope.of(context);
            return Text(
              '${tve.appName}|${tve.group.social.youtube}|${tve.group.aboutHtml}|${tve.channelFilter}|${tve.config.preferredChannel}',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(channelUrl?.queryParameters['include'], 'app');
    expect(
      find.text('Ouest TV|https://www.youtube.com/@chaineouesttv|<p>Ouest</p>|[ouest-tv]|ouest-tv'),
      findsOneWidget,
    );
  });
}
