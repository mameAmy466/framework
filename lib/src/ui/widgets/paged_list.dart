import 'package:flutter/material.dart';

import '../../models/common.dart';
import 'states.dart';

/// Liste / grille infinie sur une collection paginée par curseur de l'API.
///
/// ```dart
/// TvePagedView<TveNews>(
///   fetch: (cursor) => tve.api.listNews(cursor: cursor),
///   itemBuilder: (context, news) => NewsTile(news),
/// )
/// ```
class TvePagedView<T> extends StatefulWidget {
  final Future<TvePage<T>> Function(String? cursor) fetch;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Si non nul : grille avec cette largeur max par élément.
  final double? gridMaxExtent;
  final double gridAspectRatio;
  final EdgeInsets padding;
  final double spacing;
  final Widget? header;
  final String? emptyMessage;

  const TvePagedView({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.gridMaxExtent,
    this.gridAspectRatio = 0.9,
    this.padding = const EdgeInsets.all(12),
    this.spacing = 12,
    this.header,
    this.emptyMessage,
  });

  @override
  State<TvePagedView<T>> createState() => _TvePagedViewState<T>();
}

class _TvePagedViewState<T> extends State<TvePagedView<T>> {
  final _items = <T>[];
  String? _cursor;
  bool _hasMore = true, _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _more();
  }

  @override
  void didUpdateWidget(covariant TvePagedView<T> old) {
    super.didUpdateWidget(old);
    if (old.key != widget.key) _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await widget.fetch(_cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(p.items);
        _cursor = p.nextCursor;
        _hasMore = p.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      if (_error != null) return TveErrorView(error: _error!, onRetry: _refresh);
      if (_loading || _hasMore) return const TveLoading();
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(children: [
          if (widget.header != null) widget.header!,
          TveEmptyView(message: widget.emptyMessage),
        ]),
      );
    }

    final footer = _error != null
        ? TveErrorView(error: _error!, onRetry: _more)
        : (_hasMore ? const TveLoading() : const SizedBox(height: 24));

    final sliver = widget.gridMaxExtent == null
        ? SliverList.separated(
            itemCount: _items.length,
            separatorBuilder: (_, __) => SizedBox(height: widget.spacing),
            itemBuilder: (c, i) => widget.itemBuilder(c, _items[i]),
          )
        : SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: widget.gridMaxExtent!,
              childAspectRatio: widget.gridAspectRatio,
              mainAxisSpacing: widget.spacing,
              crossAxisSpacing: widget.spacing,
            ),
            itemCount: _items.length,
            itemBuilder: (c, i) => widget.itemBuilder(c, _items[i]),
          );

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600) _more();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.header != null) SliverToBoxAdapter(child: widget.header),
            SliverPadding(padding: widget.padding, sliver: sliver),
            SliverToBoxAdapter(child: footer),
          ],
        ),
      ),
    );
  }
}
