import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../api/tve_exception.dart';
import '../../models/media.dart';
import 'states.dart';
import 'tve_fullscreen.dart';
import 'tve_youtube_player.dart';

/// Lecteur universel basé sur un descripteur de lecture de l'API :
/// - `hls` / `audio` → video_player (ExoPlayer / AVPlayer)
/// - `youtube` → lecteur YouTube intégré
/// - `dailymotion` → ouverture externe
///
/// [load] est rappelé si la lecture échoue (URL signée expirée).
/// ```dart
/// TvePlaybackPlayer(load: () => api.getChannelLive('leral-tv'))
/// ```
class TvePlaybackPlayer extends StatefulWidget {
  final Future<TvePlayback> Function() load;
  final bool autoPlay;
  final bool isLive;
  final double aspectRatio;

  const TvePlaybackPlayer({
    super.key,
    required this.load,
    this.autoPlay = true,
    this.isLive = false,
    this.aspectRatio = 16 / 9,
  });

  @override
  State<TvePlaybackPlayer> createState() => _TvePlaybackPlayerState();
}

class _TvePlaybackPlayerState extends State<TvePlaybackPlayer> {
  TvePlayback? _playback;
  VideoPlayerController? _ctrl;
  Object? _error;
  int _retries = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant TvePlaybackPlayer old) {
    super.didUpdateWidget(old);
    if (old.key != widget.key) _init();
  }

  @override
  void dispose() {
    _disposeCtrl();
    super.dispose();
  }

  void _disposeCtrl() {
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    _ctrl = null;
  }

  Future<void> _init() async {
    _disposeCtrl();
    setState(() {
      _error = null;
      _playback = null;
    });
    try {
      final p = await widget.load();
      if (!mounted) return;
      _playback = p;
      if (p.protocol == TvePlaybackProtocol.hls || p.protocol == TvePlaybackProtocol.audio) {
        final c = VideoPlayerController.networkUrl(
          Uri.parse(p.url),
          formatHint: p.protocol == TvePlaybackProtocol.hls ? VideoFormat.hls : null,
        );
        _ctrl = c;
        await c.initialize();
        c.addListener(_onTick);
        if (widget.autoPlay) await c.play();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _onTick() {
    final c = _ctrl;
    if (c == null) return;
    if (c.value.hasError && _retries < 2) {
      _retries++;
      _init(); // URL signée expirée → on redemande un descripteur frais.
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ColoredBox(color: Colors.black, child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    if (_error != null) {
      return Theme(
        data: ThemeData.dark(useMaterial3: true),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white70),
          child: TveErrorView(
            error: _error is TveException
                ? _error!
                : const TveException(status: 0, code: 'playback_unavailable', title: 'Lecture impossible'),
            onRetry: () {
              _retries = 0;
              _init();
            },
          ),
        ),
      );
    }
    final p = _playback;
    if (p == null) return const TveLoading();

    switch (p.protocol) {
      case TvePlaybackProtocol.youtube:
        final id = youtubeIdFromUrl(p.url) ?? p.url;
        return TveYoutubePlayer(videoId: id, autoPlay: widget.autoPlay);
      case TvePlaybackProtocol.dailymotion:
      case TvePlaybackProtocol.unknown:
        return Center(
          child: IconButton.filled(
            iconSize: 48,
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => launchUrl(Uri.parse(p.url), mode: LaunchMode.externalApplication),
          ),
        );
      case TvePlaybackProtocol.hls:
      case TvePlaybackProtocol.audio:
        final c = _ctrl;
        if (c == null || !c.value.isInitialized) return const TveLoading();
        return _VideoSurface(controller: c, isLive: widget.isLive, aspectRatio: widget.aspectRatio);
    }
  }
}

class _VideoSurface extends StatefulWidget {
  final VideoPlayerController controller;
  final bool isLive;
  final double aspectRatio;
  final bool fullscreen;
  const _VideoSurface(
      {required this.controller, required this.isLive, required this.aspectRatio, this.fullscreen = false});

  @override
  State<_VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<_VideoSurface> {
  bool _controls = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controls = false);
    });
  }

  bool _inFullscreen = false;

  Future<void> _toggleFullscreen() async {
    if (widget.fullscreen) {
      Navigator.of(context).pop();
      return;
    }
    if (_inFullscreen) return;
    _inFullscreen = true;
    await TveFullscreenPage.push(
      context,
      Center(
        child: _VideoSurface(
          controller: widget.controller,
          isLive: widget.isLive,
          aspectRatio: widget.aspectRatio,
          fullscreen: true,
        ),
      ),
    );
    _inFullscreen = false;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final v = c.value;
    final ratio = v.aspectRatio > 0 ? v.aspectRatio : widget.aspectRatio;
    // Téléphone tourné à l'horizontale pendant la lecture → plein écran.
    return TveRotationWatcher(
      enabled: !widget.fullscreen,
      onLandscape: () {
        if (widget.controller.value.isPlaying) _toggleFullscreen();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _controls = !_controls);
          if (_controls) _scheduleHide();
        },
        child: Stack(fit: StackFit.passthrough, alignment: Alignment.center, children: [
          Center(child: AspectRatio(aspectRatio: ratio, child: VideoPlayer(c))),
          if (v.isBuffering) const CircularProgressIndicator(color: Colors.white),
          AnimatedOpacity(
            opacity: _controls ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_controls,
              child: Container(
                color: Colors.black38,
                child: Stack(children: [
                  Center(
                    child: IconButton(
                      iconSize: 56,
                      color: Colors.white,
                      icon: Icon(v.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                      onPressed: () {
                        v.isPlaying ? c.pause() : c.play();
                        _scheduleHide();
                      },
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 0,
                    bottom: 0,
                    child: Row(children: [
                      if (widget.isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                          child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                      else
                        Expanded(
                          child: VideoProgressIndicator(c, allowScrubbing: true, padding: const EdgeInsets.all(8)),
                        ),
                      if (widget.isLive) const Spacer(),
                      IconButton(
                        color: Colors.white,
                        icon: Icon(widget.fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
                        onPressed: _toggleFullscreen,
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
