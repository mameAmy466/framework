import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../tve_scope.dart';
import '../widgets/states.dart';
import '../widgets/tve_audio.dart';
import '../widgets/tve_image.dart';
import 'news_screen.dart';
import 'replay_screen.dart';

/// Recherche globale (émissions, vidéos, audios, actus) + vidéos YouTube.
class TveSearchScreen extends StatefulWidget {
  const TveSearchScreen({super.key});

  @override
  State<TveSearchScreen> createState() => _TveSearchScreenState();
}

class _TveSearchScreenState extends State<TveSearchScreen> {
  Timer? _debounce;
  String _q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: tve.strings.searchHint, border: InputBorder.none),
          textInputAction: TextInputAction.search,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _q = v.trim()));
          },
          onSubmitted: (v) => setState(() => _q = v.trim()),
        ),
      ),
      body: _q.length < 2
          ? const TveEmptyView(icon: Icons.search_rounded, message: '')
          : TveFuture<List<Widget>>(
              key: ValueKey(_q),
              load: () => _search(context, tve),
              builder: (context, tiles, _) =>
                  tiles.isEmpty ? TveEmptyView(message: tve.strings.noResults) : ListView(children: tiles),
            ),
    );
  }

  Future<List<Widget>> _search(BuildContext context, TveScope tve) async {
    final nav = Navigator.of(context);
    final results = await tve.api.search(_q);
    final ext =
        tve.group.has('external-videos') ? (await tve.api.listExternalVideos(q: _q, limit: 10)).items : const [];
    Widget tile(String? img, String title, String type, VoidCallback? onTap) => ListTile(
          leading: TveImage(img, width: 72, height: 48, radius: 6),
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(type),
          onTap: onTap,
        );
    return [
      for (final r in results)
        switch (r) {
          TveSearchVideo(:final video) => tile(r.image, r.title, 'Vidéo',
              () => nav.push(MaterialPageRoute(builder: (_) => TveVideoScreen(video: video)))),
          TveSearchNews(:final news) => tile(r.image, r.title, 'Actualité',
              () => nav.push(MaterialPageRoute(builder: (_) => TveNewsDetailScreen(slug: news.slug)))),
          TveSearchAudio(:final audio) => tile(
              r.image,
              r.title,
              'Audio',
              audio.mediaUrl == null
                  ? null
                  : () => TveAudioController.instance.toggle(
                        TveNowPlaying(id: audio.slug, title: audio.title, artwork: audio.thumbnail),
                        () async => audio.mediaUrl!,
                      )),
          TveSearchShow(:final show) => tile(
              r.image,
              r.title,
              'Émission',
              () => nav.push(MaterialPageRoute(
                    builder: (_) =>
                        Scaffold(appBar: AppBar(title: Text(show.title)), body: TveVideoGrid(show: [show.slug])),
                  ))),
        },
      for (final v in ext)
        tile(v.thumbnail, v.title, 'YouTube',
            () => nav.push(MaterialPageRoute(builder: (_) => TveExternalVideoScreen(video: v)))),
    ];
  }
}
