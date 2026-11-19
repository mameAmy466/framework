// Test contre la vraie API. Lancer : TVE_LIVE=1 flutter test test/live_api_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tve_kit/tve_kit.dart';

void main() {
  final enabled = Platform.environment['TVE_LIVE'] == '1';
  final group = Platform.environment['TVE_GROUP'] ?? 'leraltv';

  test('API réelle : groupe, chaînes, live, YouTube, recherche', () async {
    final api = TveClient(group: group);
    final g = await api.getGroup();
    expect(g.code, group);

    final channels = await api.listChannels();
    expect(channels.items, isNotEmpty);
    final live = await api.getChannelLive(channels.items.first.slug);
    expect(live.url, startsWith('http'));

    if (g.has('external-videos')) {
      final page1 = await api.listExternalVideos(limit: 5);
      if (page1.hasMore) {
        final page2 = await api.listExternalVideos(limit: 5, cursor: page1.nextCursor);
        expect(page2.items.first.id, isNot(page1.items.first.id));
      }
    }
    if (g.has('search')) await api.search('senegal');
    api.close();
  }, skip: enabled ? false : 'TVE_LIVE=1 pour activer');
}
