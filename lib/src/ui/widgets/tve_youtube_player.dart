import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../config/tve_strings.dart';
import '../tve_scope.dart';

/// Extrait l'id d'une URL YouTube (watch, embed, shorts, youtu.be) ou renvoie null.
String? youtubeIdFromUrl(String url) {
  final m = RegExp(r'(?:v=|/embed/|/shorts/|youtu\.be/|/live/)([A-Za-z0-9_-]{11})').firstMatch(url);
  if (m != null) return m.group(1);
  return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(url) ? url : null;
}

/// Lecteur YouTube intégré.
///
/// - [origin] : site déclaré à YouTube comme intégrant le lecteur (en-tête
///   Referer). YouTube refuse de plus en plus les lecteurs sans origine valide
///   (erreurs 152 / 153). Défaut : `TveConfig.youtubeOrigin`, sinon le site du
///   groupe (`branding.website`).
/// - Si la vidéo refuse la lecture intégrée (ou toute autre erreur YouTube),
///   un bouton propose de l'ouvrir dans l'app YouTube.
class TveYoutubePlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final double aspectRatio;
  final String? origin;

  const TveYoutubePlayer({
    super.key,
    required this.videoId,
    this.autoPlay = true,
    this.aspectRatio = 16 / 9,
    this.origin,
  });

  /// `www.site.com` / `https://site.com/page` → `https://site.com`.
  static String? normalizeOrigin(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final u = Uri.tryParse(url.trim().contains('://') ? url.trim() : 'https://${url.trim()}');
    if (u == null || u.host.isEmpty) return null;
    return '${u.scheme == 'http' ? 'http' : 'https'}://${u.host}';
  }

  @override
  State<TveYoutubePlayer> createState() => _TveYoutubePlayerState();
}

class _TveYoutubePlayerState extends State<TveYoutubePlayer> {
  YoutubePlayerController? _c;
  StreamSubscription<YoutubePlayerValue>? _sub;
  YoutubeError _error = YoutubeError.none;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c ??= _create();
  }

  YoutubePlayerController _create() {
    final tve = TveScope.maybeOf(context);
    final origin = TveYoutubePlayer.normalizeOrigin(
      widget.origin ?? tve?.config.youtubeOrigin ?? tve?.group.branding.website,
    );
    final c = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: widget.autoPlay,
      params: YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
        origin: origin ?? 'https://www.youtube.com',
      ),
    );
    _sub = c.stream.listen((v) {
      if (mounted && v.error != _error) setState(() => _error = v.error);
    });
    return c;
  }

  @override
  void didUpdateWidget(covariant TveYoutubePlayer old) {
    super.didUpdateWidget(old);
    if (old.videoId != widget.videoId) {
      setState(() => _error = YoutubeError.none);
      _c?.loadVideoById(videoId: widget.videoId);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _c?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = YoutubePlayer(controller: _c!, aspectRatio: widget.aspectRatio);
    if (_error == YoutubeError.none) return player;
    final s = TveScope.maybeOf(context)?.strings ?? const TveStrings();
    final blocked = _error == YoutubeError.notEmbeddable || _error == YoutubeError.sameAsNotEmbeddable;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                blocked ? s.youtubeNotEmbeddable : s.youtubeError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(s.watchOnYoutube),
                onPressed: () => launchUrl(
                  Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
