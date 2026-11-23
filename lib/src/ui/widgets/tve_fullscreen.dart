import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Orientation physique du téléphone, lue sur l'accéléromètre : elle reste
/// connue même quand l'écran est verrouillé en portrait ou en paysage.
enum TvePhysicalOrientation { portrait, landscape }

/// Plein écran des lecteurs et suivi de la rotation du téléphone.
///
/// Comportement « comme YouTube » :
/// - plein écran : écran en paysage, barres système masquées ;
/// - en plein écran, remettre le téléphone à la verticale le quitte ;
/// - hors plein écran, tourner le téléphone à l'horizontale pendant la lecture
///   y entre (si le lecteur le gère).
abstract final class TveFullscreen {
  /// Orientations de l'app hors plein écran, restaurées en sortie de plein écran.
  /// Une app verrouillée en portrait met ici `[DeviceOrientation.portraitUp]`.
  static List<DeviceOrientation> appOrientations = DeviceOrientation.values;

  static Future<void> enter() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static Future<void> exit() async {
    await SystemChrome.setPreferredOrientations(appOrientations);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Orientation physique, stabilisée (une valeur n'est émise qu'après
  /// [settle] sans changement). Flux vide si l'appareil n'a pas d'accéléromètre.
  static Stream<TvePhysicalOrientation> physicalOrientation({
    Duration settle = const Duration(milliseconds: 350),
  }) {
    late StreamController<TvePhysicalOrientation> out;
    StreamSubscription<AccelerometerEvent>? sub;
    Timer? timer;
    TvePhysicalOrientation? candidate, emitted;

    void onEvent(AccelerometerEvent e) {
      final x = e.x.abs(), y = e.y.abs();
      // Téléphone presque à plat : orientation indéterminée, on garde l'état.
      if (math.max(x, y) < 5.5) return;
      final TvePhysicalOrientation o;
      if (y > x * 1.4) {
        o = TvePhysicalOrientation.portrait;
      } else if (x > y * 1.4) {
        o = TvePhysicalOrientation.landscape;
      } else {
        return; // zone diagonale : hystérésis
      }
      if (o == candidate) return;
      candidate = o;
      timer?.cancel();
      timer = Timer(settle, () {
        if (candidate != emitted) {
          emitted = candidate;
          out.add(candidate!);
        }
      });
    }

    out = StreamController<TvePhysicalOrientation>(
      onListen: () {
        try {
          sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
            onEvent,
            onError: (Object _) {},
            cancelOnError: false,
          );
        } catch (_) {
          // pas de capteur (web, desktop, simulateur…)
        }
      },
      onCancel: () async {
        timer?.cancel();
        await sub?.cancel();
      },
    );
    return out.stream;
  }
}

/// Appelle [onLandscape] / [onPortrait] quand le téléphone est physiquement
/// tourné, tant que ce widget est affiché.
class TveRotationWatcher extends StatefulWidget {
  final Widget child;
  final VoidCallback? onLandscape;
  final VoidCallback? onPortrait;
  final bool enabled;

  const TveRotationWatcher({super.key, required this.child, this.onLandscape, this.onPortrait, this.enabled = true});

  @override
  State<TveRotationWatcher> createState() => _TveRotationWatcherState();
}

class _TveRotationWatcherState extends State<TveRotationWatcher> {
  StreamSubscription<TvePhysicalOrientation>? _sub;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant TveRotationWatcher old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) _sync();
  }

  void _sync() {
    _sub?.cancel();
    _sub = null;
    if (!widget.enabled) return;
    _sub = TveFullscreen.physicalOrientation().listen((o) {
      if (!mounted) return;
      o == TvePhysicalOrientation.landscape ? widget.onLandscape?.call() : widget.onPortrait?.call();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Page plein écran d'un lecteur : quitte le plein écran quand on remet le
/// téléphone à la verticale — seulement après l'avoir vu à l'horizontale, pour
/// ne pas ressortir aussitôt quand on entre par le bouton téléphone en main.
class TveFullscreenPage extends StatefulWidget {
  final Widget child;
  const TveFullscreenPage({super.key, required this.child});

  /// Pousse [child] en plein écran et attend la sortie.
  static Future<void> push(BuildContext context, Widget child) async {
    await TveFullscreen.enter();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => TveFullscreenPage(child: child),
      ),
    );
    await TveFullscreen.exit();
  }

  @override
  State<TveFullscreenPage> createState() => _TveFullscreenPageState();
}

class _TveFullscreenPageState extends State<TveFullscreenPage> {
  bool _seenLandscape = false;

  @override
  Widget build(BuildContext context) => TveRotationWatcher(
        onLandscape: () => _seenLandscape = true,
        onPortrait: () {
          if (_seenLandscape) Navigator.of(context).maybePop();
        },
        child: ColoredBox(color: const Color(0xFF000000), child: widget.child),
      );
}
