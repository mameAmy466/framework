import 'package:flutter/material.dart';

import '../../api/tve_exception.dart';
import '../../config/tve_strings.dart';
import '../tve_scope.dart';

TveStrings _strings(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<TveScope>()?.strings ?? const TveStrings();

class TveLoading extends StatelessWidget {
  const TveLoading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
}

class TveEmptyView extends StatelessWidget {
  final String? message;
  final IconData icon;
  const TveEmptyView({super.key, this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Theme.of(context).disabledColor),
            const SizedBox(height: 12),
            Text(message ?? _strings(context).empty, textAlign: TextAlign.center),
          ]),
        ),
      );
}

class TveErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const TveErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = _strings(context);
    final e = error;
    final msg = e is TveException
        ? (e.isNetwork ? s.networkError : (e.isPlaybackUnavailable ? s.playbackUnavailable : (e.detail ?? e.title)))
        : '$e';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(s.errorTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(msg, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: Text(s.retry)),
          ],
        ]),
      ),
    );
  }
}

/// FutureBuilder avec chargement / erreur / réessai intégrés.
class TveFuture<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  const TveFuture({super.key, required this.load, required this.builder});

  @override
  State<TveFuture<T>> createState() => _TveFutureState<T>();
}

class _TveFutureState<T> extends State<TveFuture<T>> {
  late Future<T> _f = widget.load();

  Future<void> _reload() async {
    final f = widget.load();
    setState(() => _f = f);
    await f.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) return TveErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const TveLoading();
          return widget.builder(context, snap.data as T, _reload);
        },
      );
}
