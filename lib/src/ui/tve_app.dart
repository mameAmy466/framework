import 'dart:async';

import 'package:flutter/material.dart';

import '../api/tve_client.dart';

import '../config/tve_config.dart';
import '../config/tve_design.dart';
import '../models/group.dart';
import 'tve_home.dart';
import 'tve_scope.dart';
import 'widgets/states.dart';
import 'widgets/tve_image.dart';

/// Point d'entrée en une ligne :
/// ```dart
/// void main() => runTveApp(config: TveConfig(group: 'leraltv'), design: TveDesign(...));
/// ```
void runTveApp({required TveConfig config, TveDesign design = const TveDesign()}) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TveApp(config: config, design: design));
}

/// App complète : splash (chargement du groupe) → navigation par onglets.
class TveApp extends StatefulWidget {
  final TveConfig config;
  final TveDesign design;

  /// Client injectable (tests). Par défaut construit depuis [config].
  final TveClient? client;

  const TveApp({super.key, required this.config, this.design = const TveDesign(), this.client});

  @override
  State<TveApp> createState() => _TveAppState();
}

class _TveAppState extends State<TveApp> {
  late final TveClient _api = widget.client ??
      TveClient(group: widget.config.group, baseUrl: widget.config.baseUrl, headers: widget.config.headers);
  TveGroup? _group;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.client == null) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final minDelay = Future<void>.delayed(widget.design.splashMinDuration);
    try {
      final g = await _api.getGroup();
      await minDelay;
      if (mounted) setState(() => _group = g);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.design;
    final g = _group;
    final api = g?.branding.primaryColor;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: widget.config.appName ?? g?.branding.appName ?? g?.name ?? '',
      themeMode: d.themeMode,
      theme: d.theme(Brightness.light, apiPrimaryColor: api),
      darkTheme: d.theme(Brightness.dark, apiPrimaryColor: api),
      home: g == null
          ? _Splash(design: d, error: _error, onRetry: _load)
          : TveScope(
              api: _api,
              config: widget.config,
              design: d,
              group: g,
              sections: resolveSections(widget.config, g),
              child: Builder(builder: d.homeBuilder ?? (_) => const TveHome()),
            ),
    );
  }
}

class _Splash extends StatelessWidget {
  final TveDesign design;
  final Object? error;
  final VoidCallback onRetry;

  const _Splash({required this.design, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final custom = design.splashBuilder;
    if (custom != null) return custom(context, error, onRetry);
    final bg = design.splashBackground ?? Theme.of(context).colorScheme.surface;
    final img = design.splashImageAsset ?? design.logoAsset;
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (img != null) ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Image.asset(img)),
            const SizedBox(height: 32),
            if (error == null)
              const CircularProgressIndicator()
            else
              TveErrorView(
                error: error!,
                onRetry: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

/// Logo de l'app : asset local si fourni, sinon logo de l'API.
class TveLogo extends StatelessWidget {
  final double height;
  const TveLogo({super.key, this.height = 32});

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    if (tve.design.logoAsset != null) return Image.asset(tve.design.logoAsset!, height: height);
    final url = tve.group.branding.logo;
    if (url == null) return Text(tve.appName);
    return TveImage(url, height: height, fit: BoxFit.contain, radius: 0);
  }
}
