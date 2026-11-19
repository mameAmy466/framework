import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/media.dart';
import '../tve_scope.dart';
import '../widgets/cards.dart';
import '../widgets/paged_list.dart';
import '../widgets/states.dart';
import '../widgets/tve_image.dart';
import '../widgets/tve_video_player.dart';
import '../widgets/tve_youtube_player.dart';

/// Libellés des flux YouTube synchronisés par l'API.
const tveFeedLabels = {
  'videos': 'Vidéos',
  'live-streams': 'Lives',
  'popular-videos': 'Populaires',
  'shorts': 'Shorts',
  'popular-live-streams': 'Lives populaires',
  'popular-shorts': 'Shorts populaires',
};

class _Tab {
  final String label;
  final WidgetBuilder builder;
  const _Tab(this.label, this.builder);
}

/// Replays : vidéos VOD de l'API + flux YouTube + playlists, avec puces de filtre.
/// Seuls les flux non vides sont affichés.
class TveReplayScreen extends StatefulWidget {
  const TveReplayScreen({super.key});

  @override
  State<TveReplayScreen> createState() => _TveReplayScreenState();
}

class _TveReplayScreenState extends State<TveReplayScreen> {
  int _i = 0;

  Future<List<_Tab>> _tabs(TveScope tve) async {
    final api = tve.api;
    final ch = tve.channelFilter;
    final tabs = <_Tab>[];
    if (tve.group.has('videos')) {
      tabs.add(_Tab(tve.strings.allVideos, (_) => TveVideoGrid(channel: ch)));
    }
    if (tve.group.has('external-videos')) {
      final feeds = tveFeedLabels.keys.toList();
      final counts = await Future.wait(feeds.map((f) =>
          api.listExternalVideos(feed: [f], channel: ch, limit: 1).then((p) => p.items.length, onError: (_) => 0)));
      for (var k = 0; k < feeds.length; k++) {
        if (counts[k] > 0) {
          tabs.add(_Tab(tveFeedLabels[feeds[k]]!, (_) => TveExternalVideoGrid(feed: feeds[k], channel: ch)));
        }
      }
    }
    if (tve.group.has('external-playlists')) {
      tabs.add(_Tab(tve.strings.playlists, (_) => TvePlaylistGrid(channel: ch)));
    }
    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    return TveFuture<List<_Tab>>(
      load: () => _tabs(tve),
      builder: (context, tabs, _) {
        if (tabs.isEmpty) return const TveEmptyView(icon: Icons.video_library_outlined);
        final i = _i.clamp(0, tabs.length - 1);
        return Column(children: [
          if (tabs.length > 1)
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, k) => ChoiceChip(
                  label: Text(tabs[k].label),
                  selected: k == i,
                  onSelected: (_) => setState(() => _i = k),
                ),
              ),
            ),
          Expanded(child: KeyedSubtree(key: ValueKey(i), child: Builder(builder: tabs[i].builder))),
        ]);
      },
    );
  }
}

/// Grille des vidéos VOD de l'API (filtrable).
class TveVideoGrid extends StatelessWidget {
  final List<String>? channel, show, category;
  const TveVideoGrid({super.key, this.channel, this.show, this.category});

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    return TvePagedView<TveVideo>(
      gridMaxExtent: 360,
      gridAspectRatio: 1.15,
      fetch: (c) => tve.api.listVideos(
        channel: channel,
        show: show,
        category: category,
        limit: tve.config.pageSize,
        cursor: c,
      ),
      itemBuilder: (context, v) => TveMediaCard(
        image: v.thumbnail,
        title: v.title,
        subtitle: [v.show?.label, formatDate(v.publishedAt)].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
        badge: formatDuration(v.duration),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TveVideoScreen(video: v))),
      ),
    );
  }
}

/// Grille des vidéos YouTube synchronisées.
class TveExternalVideoGrid extends StatelessWidget {
  final String? feed;
  final String? playlist;
  final List<String>? channel;
  const TveExternalVideoGrid({super.key, this.feed, this.playlist, this.channel});

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    final vertical = feed != null && feed!.contains('shorts');
    return TvePagedView<TveExternalVideo>(
      gridMaxExtent: vertical ? 200 : 360,
      gridAspectRatio: vertical ? 0.5 : 1.15,
      fetch: (c) => tve.api.listExternalVideos(
        feed: feed == null ? null : [feed!],
        playlist: playlist,
        channel: playlist == null ? channel : null,
        limit: tve.config.pageSize,
        cursor: c,
      ),
      itemBuilder: (context, v) => TveMediaCard(
        image: v.thumbnail,
        title: v.title,
        aspectRatio: vertical ? 9 / 16 : 16 / 9,
        titleLines: vertical ? 3 : 2,
        subtitle: formatDate(v.publishedAt),
        badge: formatDuration(v.duration),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TveExternalVideoScreen(video: v))),
      ),
    );
  }
}

/// Grille des playlists YouTube.
class TvePlaylistGrid extends StatelessWidget {
  final List<String>? channel;
  const TvePlaylistGrid({super.key, this.channel});

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    return TvePagedView<TveExternalPlaylist>(
      gridMaxExtent: 360,
      gridAspectRatio: 1.15,
      fetch: (c) => tve.api.listExternalPlaylists(channel: channel, limit: tve.config.pageSize, cursor: c),
      itemBuilder: (context, p) => TveMediaCard(
        image: p.thumbnail,
        title: p.title,
        badge: p.itemCount == null ? null : '${p.itemCount} vidéos',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(appBar: AppBar(title: Text(p.title)), body: TveExternalVideoGrid(playlist: p.id)),
        )),
      ),
    );
  }
}

/// Détail d'une vidéo VOD : lecteur + description + vidéos liées.
class TveVideoScreen extends StatelessWidget {
  final TveVideo video;
  const TveVideoScreen({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    final v = video;
    return Scaffold(
      appBar: AppBar(title: Text(v.show?.label ?? v.title)),
      body: Column(children: [
        v.isYoutube && v.externalId != null
            ? TveYoutubePlayer(videoId: v.externalId!)
            : TvePlaybackPlayer(load: () => tve.api.getVideoPlayback(v.slug)),
        Expanded(
          child: TvePagedView<TveVideo>(
            header: _Info(title: v.title, description: v.description, date: v.publishedAt),
            fetch: (c) => tve.api.listVideos(relatedTo: v.slug, limit: tve.config.pageSize, cursor: c),
            itemBuilder: (context, r) => _RelatedTile(
              image: r.thumbnail,
              title: r.title,
              subtitle: formatDate(r.publishedAt),
              onTap: () =>
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TveVideoScreen(video: r))),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Détail d'une vidéo YouTube : lecteur + description + vidéos du même flux.
class TveExternalVideoScreen extends StatelessWidget {
  final TveExternalVideo video;
  const TveExternalVideoScreen({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    final v = video;
    return Scaffold(
      appBar: AppBar(title: Text(v.channel?.label ?? tve.appName)),
      body: Column(children: [
        TveYoutubePlayer(videoId: v.externalId, aspectRatio: v.isShort ? 9 / 16 : 16 / 9),
        if (!v.isShort)
          Expanded(
            child: TvePagedView<TveExternalVideo>(
              header: _Info(title: v.title, description: v.description, date: v.publishedAt, shareUrl: v.watchUrl),
              fetch: (c) => tve.api.listExternalVideos(
                feed: v.feed == null ? null : [v.feed!],
                channel: v.channel == null ? null : [v.channel!.slug],
                limit: tve.config.pageSize,
                cursor: c,
              ),
              itemBuilder: (context, r) => r.id == v.id
                  ? const SizedBox.shrink()
                  : _RelatedTile(
                      image: r.thumbnail,
                      title: r.title,
                      subtitle: formatDate(r.publishedAt),
                      onTap: () => Navigator.of(context)
                          .pushReplacement(MaterialPageRoute(builder: (_) => TveExternalVideoScreen(video: r))),
                    ),
            ),
          ),
      ]),
    );
  }
}

class _Info extends StatelessWidget {
  final String title;
  final String? description, shareUrl;
  final DateTime? date;
  const _Info({required this.title, this.description, this.date, this.shareUrl});

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
            tooltip: tve.strings.share,
            icon: const Icon(Icons.share_rounded),
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: tve.shareText(shareUrl == null ? title : '$title\n$shareUrl')),
            ),
          ),
        ]),
        if (date != null) Text(formatDate(date), style: Theme.of(context).textTheme.bodySmall),
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(description!),
        ],
        const Divider(height: 24),
      ]),
    );
  }
}

class _RelatedTile extends StatelessWidget {
  final String? image;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _RelatedTile({required this.image, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 140, child: TveImage(image, radius: TveScope.of(context).design.radius)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ]),
      );
}
