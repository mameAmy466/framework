import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Extrait l'id d'une URL YouTube (watch, embed, shorts, youtu.be) ou renvoie null.
String? youtubeIdFromUrl(String url) {
  final m = RegExp(r'(?:v=|/embed/|/shorts/|youtu\.be/|/live/)([A-Za-z0-9_-]{11})').firstMatch(url);
  if (m != null) return m.group(1);
  return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(url) ? url : null;
}

/// Lecteur YouTube intégré.
class TveYoutubePlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final double aspectRatio;

  const TveYoutubePlayer({super.key, required this.videoId, this.autoPlay = true, this.aspectRatio = 16 / 9});

  @override
  State<TveYoutubePlayer> createState() => _TveYoutubePlayerState();
}

class _TveYoutubePlayerState extends State<TveYoutubePlayer> {
  late final YoutubePlayerController _c = YoutubePlayerController.fromVideoId(
    videoId: widget.videoId,
    autoPlay: widget.autoPlay,
    params: const YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true),
  );

  @override
  void didUpdateWidget(covariant TveYoutubePlayer old) {
    super.didUpdateWidget(old);
    if (old.videoId != widget.videoId) _c.loadVideoById(videoId: widget.videoId);
  }

  @override
  void dispose() {
    _c.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => YoutubePlayer(controller: _c, aspectRatio: widget.aspectRatio);
}
