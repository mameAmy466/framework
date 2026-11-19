import 'package:flutter/material.dart';

import '../../models/media.dart';
import '../tve_scope.dart';
import '../widgets/cards.dart';
import '../widgets/paged_list.dart';
import '../widgets/tve_audio.dart';
import '../widgets/tve_image.dart';

/// Podcasts / audios : lecture via le lecteur audio global.
class TvePodcastsScreen extends StatelessWidget {
  const TvePodcastsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    final audio = TveAudioController.instance;
    return TvePagedView<TveAudio>(
      fetch: (c) => tve.api
          .listAudios(channel: tve.channelFilter, include: const ['show'], limit: tve.config.pageSize, cursor: c),
      itemBuilder: (context, a) => ListenableBuilder(
        listenable: audio,
        builder: (context, _) {
          final playing = audio.isCurrent(a.slug) && audio.playing;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: TveImage(a.thumbnail, width: 64, height: 64, radius: 8),
            title: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text([a.show?.label, formatDate(a.publishedAt)].whereType<String>().join(' · ')),
            trailing: IconButton.filledTonal(
              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              onPressed: a.mediaUrl == null
                  ? null
                  : () => audio.toggle(
                        TveNowPlaying(id: a.slug, title: a.title, subtitle: a.show?.label, artwork: a.thumbnail),
                        () async => a.mediaUrl!,
                      ),
            ),
          );
        },
      ),
    );
  }
}
