import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tve_kit/tve_kit.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

http.Response json(String body, {int status = 200, Map<String, String> headers = const {}}) =>
    http.Response.bytes(utf8.encode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8', ...headers});

void main() {
  group('modèles (réponses réelles de l\'API)', () {
    final routes = <String, String>{
      '/v3/groups/leraltv': 'group.json',
      '/v3/groups/leraltv/channels': 'channels.json',
      '/v3/groups/leraltv/channels/leral-tv/live': 'live_hls.json',
      '/v3/groups/leraltv/external-videos': 'external_videos.json',
      '/v3/groups/leraltv/external-playlists': 'external_playlists.json',
      '/v3/groups/leraltv/schedule/now': 'schedule_now.json',
    };
    final api = TveClient(
      group: 'leraltv',
      httpClient: MockClient((req) async {
        final f = routes[req.url.path];
        return f == null ? json(fixture('problem.json'), status: 404) : json(fixture(f));
      }),
    );

    test('groupe', () async {
      final g = await api.getGroup();
      expect(g.code, 'leraltv');
      expect(g.name, 'LERAL TV');
      expect(g.branding.logo, startsWith('https://'));
      expect(g.social.youtubeChannelId, isNotNull);
      expect(g.features.news, isTrue);
      expect(g.has('channels'), isTrue);
      expect(g.has('external-videos'), isTrue);
      expect(g.aboutHtml, contains('Leral'));
    });

    test('chaînes TV + radio', () async {
      final p = await api.listChannels();
      expect(p.items.length, 2);
      final tv = p.items.firstWhere((c) => c.slug == 'leral-tv');
      expect(tv.kind, TveChannelKind.tv);
      expect(tv.links['live'], endsWith('/live'));
      final radio = p.items.firstWhere((c) => c.isRadio);
      expect(radio.frequency, '96.1');
      expect(p.hasMore, isFalse);
    });

    test('lecture live HLS', () async {
      final pb = await api.getChannelLive('leral-tv');
      expect(pb.protocol, TvePlaybackProtocol.hls);
      expect(pb.url, contains('.m3u8'));
      expect(pb.expiresAt, isNotNull);
      expect(pb.channel?.slug, 'leral-tv');
    });

    test('vidéos YouTube + pagination', () async {
      final p = await api.listExternalVideos(limit: 3);
      expect(p.items, isNotEmpty);
      expect(p.items.first.provider, 'youtube');
      expect(p.items.first.externalId, isNotEmpty);
      expect(p.hasMore, isTrue);
      final pl = await api.listExternalPlaylists(limit: 2);
      expect(pl.items.first.id, startsWith('youtube:'));
    });

    test('schedule/now (méta)', () async {
      final n = await api.listScheduleNow();
      expect(n, isEmpty);
    });

    test('erreur 404 → TveException', () async {
      await expectLater(
        api.getVideo('inconnue'),
        throwsA(isA<TveException>().having((e) => e.code, 'code', 'not_found').having((e) => e.isNotFound, 'nf', true)),
      );
    });
  });

  group('client HTTP', () {
    test('filtres liste séparés par des virgules, nulls ignorés', () async {
      late Uri seen;
      final api = TveClient(
        group: 'demo',
        httpClient: MockClient((r) async {
          seen = r.url;
          return json('{"data":[],"meta":{"limit":5,"next_cursor":null}}');
        }),
      );
      await api.listVideos(
          channel: ['a', 'b'], source: ['vod'], featured: true, limit: 5, include: ['show', 'channel']);
      expect(seen.path, '/v3/groups/demo/videos');
      expect(seen.queryParameters, {
        'channel': 'a,b',
        'source': 'vod',
        'featured': 'true',
        'include': 'show,channel',
        'limit': '5',
      });
    });

    test('date de grille au format YYYY-MM-DD', () async {
      late Uri seen;
      final api = TveClient(
        group: 'demo',
        httpClient: MockClient((r) async {
          seen = r.url;
          return json('{"data":[]}');
        }),
      );
      await api.listSchedule(date: DateTime(2026, 3, 7));
      expect(seen.queryParameters['date'], '2026-03-07');
    });

    test('cache ETag : If-None-Match puis 304', () async {
      var calls = 0;
      final api = TveClient(
        group: 'demo',
        httpClient: MockClient((r) async {
          calls++;
          if (r.headers['If-None-Match'] == '"v1"') return http.Response('', 304);
          return json(fixture('channels.json'), headers: {'etag': '"v1"'});
        }),
      );
      final a = await api.listChannels();
      final b = await api.listChannels();
      expect(calls, 2);
      expect(b.items.length, a.items.length);
    });

    test('pas de cache sur les descripteurs de lecture', () async {
      final sent = <String?>[];
      final api = TveClient(
        group: 'demo',
        httpClient: MockClient((r) async {
          sent.add(r.headers['If-None-Match']);
          return json(fixture('live_hls.json'), headers: {'etag': '"x"'});
        }),
      );
      await api.getChannelLive('leral-tv');
      await api.getChannelLive('leral-tv');
      expect(sent, [null, null]);
    });

    test('429 : une nouvelle tentative après Retry-After', () async {
      var calls = 0;
      final api = TveClient(
        group: 'demo',
        httpClient: MockClient((r) async {
          calls++;
          if (calls == 1) return http.Response('', 429, headers: {'retry-after': '0'});
          return json(fixture('group.json'));
        }),
      );
      final g = await api.getGroup();
      expect(g.code, 'leraltv');
      expect(calls, 2);
    });

    test('erreur réseau → network_error', () async {
      final api = TveClient(group: 'demo', httpClient: MockClient((r) async => throw const SocketException('off')));
      await expectLater(api.getGroup(), throwsA(isA<TveException>().having((e) => e.isNetwork, 'net', true)));
    });

    test('paginate suit next_cursor', () async {
      final api = TveClient(
        group: 'demo',
        httpClient: MockClient((r) async {
          final c = r.url.queryParameters['cursor'];
          return c == null
              ? json('{"data":[{"slug":"a","title":"A"}],"meta":{"next_cursor":"p2"}}')
              : json('{"data":[{"slug":"b","title":"B"}],"meta":{"next_cursor":null}}');
        }),
      );
      final all = await api.paginate((c) => api.listNews(cursor: c)).map((n) => n.slug).toList();
      expect(all, ['a', 'b']);
    });
  });

  group('config', () {
    test('sections automatiques depuis les collections', () {
      final g = TveGroup.fromJson((jsonDecode(fixture('group.json')) as Map)['data'].cast<String, dynamic>());
      final s = resolveSections(const TveConfig(group: 'leraltv'), g);
      expect(s, [TveSection.live, TveSection.radio, TveSection.replay, TveSection.about]);
      final hidden = resolveSections(const TveConfig(group: 'x', hiddenSections: {TveSection.radio}), g);
      expect(hidden, isNot(contains(TveSection.radio)));
      final forced = resolveSections(const TveConfig(group: 'x', sections: [TveSection.news, TveSection.about]), g);
      expect(forced, [TveSection.news, TveSection.about]);
    });

    test('couleurs hex', () {
      expect(parseHexColor('#E30613')?.toARGB32(), 0xFFE30613);
      expect(parseHexColor('fff')?.toARGB32(), 0xFFFFFFFF);
      expect(parseHexColor('nope'), isNull);
      expect(parseHexColor(null), isNull);
    });

    test('youtubeIdFromUrl', () {
      expect(youtubeIdFromUrl('https://www.youtube.com/shorts/HWZtqCbTuFY'), 'HWZtqCbTuFY');
      expect(youtubeIdFromUrl('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(youtubeIdFromUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=3'), 'dQw4w9WgXcQ');
    });
  });
}
