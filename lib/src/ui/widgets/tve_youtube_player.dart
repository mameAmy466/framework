import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../config/tve_strings.dart';
import '../tve_scope.dart';

/// Extrait l'id d'une URL YouTube (watch, embed, shorts, youtu.be) ou renvoie null.
String? youtubeIdFromUrl(String url) {
  final m = RegExp(r'(?:v=|/embed/|/shorts/|youtu\.be/|/live/)([A-Za-z0-9_-]{11})').firstMatch(url);
  if (m != null) return m.group(1);
  return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(url) ? url : null;
}

/// Lecteur YouTube intégré : la vidéo est lue DANS l'app, jamais sur le site
/// ou l'app YouTube.
///
/// - Android / iOS : lecteur officiel YouTube (`/embed`) chargé dans une
///   WebView avec un en-tête Referer valide ([origin]). Sans lui, YouTube
///   refuse la lecture (erreurs 152 / 153). La navigation hors du lecteur est
///   bloquée ; plein écran natif (iOS) ou plein écran Flutter (Android).
/// - Web : iframe YouTube.
///
/// [origin] : défaut `TveConfig.youtubeOrigin`, sinon le site du groupe
/// (`branding.website`).
///
/// Pendant le chargement, un écran soigné (miniature, anneau animé) s'affiche ;
/// en cas d'erreur, un bouton « Réessayer ».
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

  /// URL du lecteur officiel pour [videoId].
  static Uri embedUri(String videoId, {required String origin, bool autoPlay = true}) => Uri.https(
        'www.youtube.com',
        '/embed/$videoId',
        {
          'autoplay': autoPlay ? '1' : '0',
          'playsinline': '1',
          'rel': '0',
          'fs': '1',
          'iv_load_policy': '3',
          'enablejsapi': '1',
          'origin': origin,
          'widget_referrer': origin,
        },
      );

  @override
  State<TveYoutubePlayer> createState() => _TveYoutubePlayerState();
}

class _TveYoutubePlayerState extends State<TveYoutubePlayer> {
  String _origin(BuildContext context) {
    final tve = TveScope.maybeOf(context);
    return TveYoutubePlayer.normalizeOrigin(
          widget.origin ?? tve?.config.youtubeOrigin ?? tve?.group.branding.website,
        ) ??
        'https://www.youtube.com';
  }

  @override
  Widget build(BuildContext context) {
    final origin = _origin(context);
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ColoredBox(
        color: Colors.black,
        child: kIsWeb
            ? _IframePlayer(
                key: ValueKey(widget.videoId), videoId: widget.videoId, autoPlay: widget.autoPlay, origin: origin)
            : _WebViewPlayer(
                key: ValueKey(widget.videoId), videoId: widget.videoId, autoPlay: widget.autoPlay, origin: origin),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── mobile

/// Script injecté dans le lecteur : remonte l'état de la vidéo à Flutter.
const _bridgeJs = '''
(function () {
  if (window.__tveBridge) return; window.__tveBridge = true;
  function send(s) { try { TveYT.postMessage(s); } catch (e) {} }
  function hook() {
    var v = document.querySelector('video');
    if (document.querySelector('.ytp-error')) { send('error'); }
    if (!v) { setTimeout(hook, 300); return; }
    if (v.__tve) return; v.__tve = true;
    v.addEventListener('playing', function () { send('playing'); });
    v.addEventListener('waiting', function () { send('waiting'); });
    v.addEventListener('pause', function () { send('paused'); });
    if (!v.paused && v.readyState > 2) send('playing');
    else if (v.readyState >= 2) send('ready');
    setInterval(function () { if (document.querySelector('.ytp-error')) send('error'); }, 1500);
  }
  hook();
})();
''';

enum _State { loading, ready, playing, error }

class _WebViewPlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final String origin;
  const _WebViewPlayer({super.key, required this.videoId, required this.autoPlay, required this.origin});

  @override
  State<_WebViewPlayer> createState() => _WebViewPlayerState();
}

class _WebViewPlayerState extends State<_WebViewPlayer> {
  late final WebViewController _web = _create();
  _State _state = _State.loading;
  Timer? _readyFallback;

  WebViewController _create() {
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    final c = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('TveYT', onMessageReceived: (m) => _onMessage(m.message))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) {
            // Le lecteur reste dans l'app : on n'autorise que les pages /embed
            // dans la vue principale (les sous-cadres YouTube restent libres).
            if (!r.isMainFrame) return NavigationDecision.navigate;
            final u = Uri.tryParse(r.url);
            final ok = u != null && u.host.endsWith('youtube.com') && u.path.startsWith('/embed/');
            return ok ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            _web.runJavaScript(_bridgeJs).catchError((Object _) {});
            // Si le script n'a rien remonté (autoplay bloqué…), on retire
            // l'écran de chargement : les contrôles YouTube prennent le relais.
            _readyFallback?.cancel();
            _readyFallback = Timer(const Duration(seconds: 4), () {
              if (mounted && _state == _State.loading) setState(() => _state = _State.ready);
            });
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame == true) _set(_State.error);
          },
        ),
      );

    final platform = c.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
      platform.setCustomWidgetCallbacks(onShowCustomWidget: _showFullscreen, onHideCustomWidget: _hideFullscreen);
    }
    _load(c);
    return c;
  }

  void _load(WebViewController c) {
    c.loadRequest(
      TveYoutubePlayer.embedUri(widget.videoId, origin: widget.origin, autoPlay: widget.autoPlay),
      headers: {'Referer': '${widget.origin}/'},
    );
  }

  void _onMessage(String m) {
    switch (m) {
      case 'playing':
        _set(_State.playing);
      case 'ready':
      case 'paused':
        if (_state == _State.loading) _set(_State.ready);
      case 'error':
        _set(_State.error);
    }
  }

  void _set(_State s) {
    if (!mounted || s == _state) return;
    setState(() => _state = s);
  }

  void _retry() {
    setState(() => _state = _State.loading);
    _load(_web);
  }

  // Plein écran Android : la vue plein écran fournie par la WebView est
  // affichée dans une page Flutter en paysage.
  bool _fullscreen = false;

  Future<void> _showFullscreen(Widget widget, void Function() onHidden) async {
    if (_fullscreen) return;
    _fullscreen = true;
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, __, ___) => PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) onHidden();
          },
          child: ColoredBox(color: Colors.black, child: widget),
        ),
      ),
    );
    _fullscreen = false;
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _hideFullscreen() {
    if (_fullscreen && mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _readyFallback?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _web),
        if (_state == _State.loading) _YoutubeLoading(videoId: widget.videoId),
        if (_state == _State.error) _YoutubeError(videoId: widget.videoId, onRetry: _retry),
      ],
    );
  }
}

/// Écran de chargement : miniature assombrie, anneau animé autour d'un bouton
/// lecture, texte « Chargement… ». Sans widget Opacity (compatible Impeller).
class _YoutubeLoading extends StatefulWidget {
  final String videoId;
  const _YoutubeLoading({required this.videoId});

  @override
  State<_YoutubeLoading> createState() => _YoutubeLoadingState();
}

class _YoutubeLoadingState extends State<_YoutubeLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final s = TveScope.maybeOf(context)?.strings ?? const TveStrings();
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          'https://i.ytimg.com/vi/${widget.videoId}/hqdefault.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0xCC000000)],
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _spin,
                      builder: (context, _) => CustomPaint(
                        size: const Size.square(72),
                        painter: _RingPainter(progress: _spin.value, color: accent),
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                s.loading,
                style:
                    const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: .3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Arc dégradé qui tourne (couleur principale → blanc).
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const stroke = 4.0;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
        r,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = const Color(0x26FFFFFF));
    final start = progress * math.pi * 2;
    canvas.drawArc(
      r,
      start,
      math.pi * 1.25,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 1.25,
          colors: [color.withValues(alpha: 0), color, Colors.white],
          stops: const [0, .7, 1],
          transform: GradientRotation(start),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}

class _YoutubeError extends StatelessWidget {
  final String videoId;
  final VoidCallback onRetry;
  const _YoutubeError({required this.videoId, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = TveScope.maybeOf(context)?.strings ?? const TveStrings();
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 34),
              const SizedBox(height: 8),
              Text(s.youtubeError, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: Text(s.retry),
                onPressed: onRetry,
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.youtube.com/watch?v=$videoId'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(s.watchOnYoutube, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── web

class _IframePlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final String origin;
  const _IframePlayer({super.key, required this.videoId, required this.autoPlay, required this.origin});

  @override
  State<_IframePlayer> createState() => _IframePlayerState();
}

class _IframePlayerState extends State<_IframePlayer> {
  late final YoutubePlayerController _c = YoutubePlayerController.fromVideoId(
    videoId: widget.videoId,
    autoPlay: widget.autoPlay,
    params: YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true, origin: widget.origin),
  );

  @override
  void dispose() {
    _c.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => YoutubePlayer(controller: _c);
}
