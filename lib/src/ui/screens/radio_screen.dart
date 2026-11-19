import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/media.dart';
import '../tve_scope.dart';
import '../widgets/states.dart';
import '../widgets/tve_audio.dart';
import '../widgets/tve_image.dart';

/// Radios en direct. La lecture continue quand on change d'onglet.
class TveRadioScreen extends StatefulWidget {
  const TveRadioScreen({super.key});

  @override
  State<TveRadioScreen> createState() => _TveRadioScreenState();
}

class _TveRadioScreenState extends State<TveRadioScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    final audio = TveAudioController.instance;
    return TveFuture<List<TveChannel>>(
      load: () async {
        final p = await tve.api.listChannels(kind: const ['radio'], limit: 100);
        final f = tve.channelFilter;
        return f == null ? p.items : p.items.where((c) => f.contains(c.slug)).toList();
      },
      builder: (context, radios, _) {
        if (radios.isEmpty) return const TveEmptyView(icon: Icons.radio_rounded);
        final r = radios.firstWhere((c) => c.slug == (_selected ?? audio.current?.id), orElse: () => radios.first);
        final item = TveNowPlaying(id: r.slug, title: r.name, subtitle: r.frequency, artwork: r.logo, isLive: true);
        return ListenableBuilder(
          listenable: audio,
          builder: (context, _) {
            final isMe = audio.isCurrent(r.slug);
            final playing = isMe && audio.playing;
            final scheme = Theme.of(context).colorScheme;
            return ListView(padding: const EdgeInsets.all(24), children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: TveImage(r.logo, aspectRatio: 1, fit: BoxFit.contain, radius: tve.design.radius * 2),
                ),
              ),
              const SizedBox(height: 20),
              Text(r.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              if (r.frequency != null)
                Text('${r.frequency} FM', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () => SharePlus.instance.share(ShareParams(text: tve.shareText(r.name))),
                ),
                const SizedBox(width: 16),
                SizedBox.square(
                  dimension: 84,
                  child: isMe && audio.loading
                      ? const CircularProgressIndicator()
                      : IconButton.filled(
                          iconSize: 48,
                          style: IconButton.styleFrom(backgroundColor: scheme.primary),
                          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          onPressed: () => audio.toggle(item, () async => (await tve.api.getChannelLive(r.slug)).url),
                        ),
                ),
                const SizedBox(width: 16),
                IconButton(icon: const Icon(Icons.stop_rounded), onPressed: isMe ? audio.stop : null),
              ]),
              if (isMe && audio.error != null) TveErrorView(error: audio.error!),
              if (r.description != null) ...[
                const SizedBox(height: 24),
                Text(r.description!, textAlign: TextAlign.center),
              ],
              if (radios.length > 1) ...[
                const Divider(height: 40),
                for (final c in radios)
                  ListTile(
                    selected: c.slug == r.slug,
                    leading: TveImage(c.logo, width: 48, height: 48, radius: 8),
                    title: Text(c.name),
                    subtitle: c.frequency == null ? null : Text('${c.frequency} FM'),
                    onTap: () => setState(() => _selected = c.slug),
                  ),
              ],
            ]);
          },
        );
      },
    );
  }
}
