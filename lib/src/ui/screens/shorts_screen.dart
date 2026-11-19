import 'package:flutter/material.dart';

import '../../models/media.dart';
import '../tve_scope.dart';
import '../widgets/cards.dart';
import '../widgets/paged_list.dart';
import '../widgets/tve_video_player.dart';
import '../widgets/tve_youtube_player.dart';

/// Shorts : grille verticale, lecture plein écran au clic.
class TveShortsScreen extends StatelessWidget {
  const TveShortsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    return TvePagedView<TveShort>(
      gridMaxExtent: 200,
      gridAspectRatio: 0.5,
      fetch: (c) => tve.api.listShorts(channel: tve.channelFilter, limit: tve.config.pageSize, cursor: c),
      itemBuilder: (context, s) => TveMediaCard(
        image: s.thumbnail,
        title: s.title,
        aspectRatio: 9 / 16,
        titleLines: 3,
        badge: formatDuration(s.duration),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TveShortPlayerScreen(short: s))),
      ),
    );
  }
}

class TveShortPlayerScreen extends StatelessWidget {
  final TveShort short;
  const TveShortPlayerScreen({super.key, required this.short});

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar:
          AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(short.title, maxLines: 1)),
      body: Center(
        child: short.externalId != null
            ? TveYoutubePlayer(videoId: short.externalId!, aspectRatio: 9 / 16)
            : TvePlaybackPlayer(aspectRatio: 9 / 16, load: () => tve.api.getShortPlayback(short.slug)),
      ),
    );
  }
}
