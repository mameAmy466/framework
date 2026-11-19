import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/catalog.dart';
import '../../models/media.dart';
import '../tve_scope.dart';
import '../widgets/cards.dart';
import '../widgets/states.dart';
import '../widgets/tve_image.dart';
import '../widgets/tve_video_player.dart';

/// Direct TV : lecteur en haut, liste des chaînes TV dessous, « en ce moment / à suivre ».
class TveLiveScreen extends StatefulWidget {
  const TveLiveScreen({super.key});

  @override
  State<TveLiveScreen> createState() => _TveLiveScreenState();
}

class _TveLiveScreenState extends State<TveLiveScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    return TveFuture<List<TveChannel>>(
      load: () async {
        final p = await tve.api.listChannels(kind: const ['tv', 'webtv', 'cinema', 'acas'], limit: 100);
        final f = tve.channelFilter;
        return f == null ? p.items : p.items.where((c) => f.contains(c.slug)).toList();
      },
      builder: (context, channels, reload) {
        if (channels.isEmpty) return const TveEmptyView(icon: Icons.live_tv_rounded);
        final current = channels.firstWhere(
          (c) => c.slug == (_selected ?? tve.config.defaultChannel),
          orElse: () => channels.first,
        );
        return ListView(children: [
          TvePlaybackPlayer(
            key: ValueKey(current.slug),
            isLive: true,
            load: () => tve.api.getChannelLive(current.slug),
          ),
          ListTile(
            leading: TveImage(current.logo, width: 48, height: 48, fit: BoxFit.contain, radius: 8),
            title: Text(current.name, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Row(children: [const TveLiveBadge(), const SizedBox(width: 8), Text(tve.strings.live)]),
            trailing: IconButton(
              tooltip: tve.strings.share,
              icon: const Icon(Icons.share_rounded),
              onPressed: () => SharePlus.instance.share(ShareParams(text: tve.shareText(current.name))),
            ),
          ),
          if (current.description != null)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(current.description!)),
          if (tve.group.has('shows')) _NowNext(channel: current.slug),
          if (channels.length > 1) ...[
            const Divider(height: 32),
            for (final c in channels)
              ListTile(
                selected: c.slug == current.slug,
                leading: TveImage(c.logo, width: 56, height: 40, fit: BoxFit.contain, radius: 6),
                title: Text(c.name),
                trailing: c.slug == current.slug ? const Icon(Icons.equalizer_rounded) : null,
                onTap: () => setState(() => _selected = c.slug),
              ),
          ],
        ]);
      },
    );
  }
}

class _NowNext extends StatelessWidget {
  final String channel;
  const _NowNext({required this.channel});

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    return FutureBuilder<List<TveChannelNow>>(
      future: tve.api.listScheduleNow(channel: [channel]),
      builder: (context, snap) {
        final n = snap.data?.firstOrNull;
        if (n == null || (n.current == null && n.next == null)) return const SizedBox.shrink();
        Widget slot(String label, TveScheduleSlot s) => ListTile(
              dense: true,
              leading: TveImage(s.showLogo ?? s.showPoster, width: 48, height: 48, radius: 8),
              title: Text(s.showTitle),
              subtitle: Text('$label · ${formatTime(s.startsAt)} – ${formatTime(s.endsAt)}'),
            );
        return Column(children: [
          if (n.current != null) slot(tve.strings.onAir, n.current!),
          if (n.next != null) slot(tve.strings.upNext, n.next!),
        ]);
      },
    );
  }
}
