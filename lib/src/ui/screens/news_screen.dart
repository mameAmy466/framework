import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/catalog.dart';
import '../tve_scope.dart';
import '../widgets/cards.dart';
import '../widgets/paged_list.dart';
import '../widgets/states.dart';
import '../widgets/tve_image.dart';

/// Actualités : puces de catégories + liste paginée.
class TveNewsScreen extends StatefulWidget {
  const TveNewsScreen({super.key});

  @override
  State<TveNewsScreen> createState() => _TveNewsScreenState();
}

class _TveNewsScreenState extends State<TveNewsScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    return Column(children: [
      if (tve.group.has('news-categories'))
        SizedBox(
          height: 52,
          child: FutureBuilder(
            future: tve.api.listNewsCategories(limit: 50),
            builder: (context, snap) {
              final cats = (snap.data?.items ?? const <TveNewsCategory>[]).where((c) => c.postsCount > 0).toList();
              if (cats.isEmpty) return const SizedBox.shrink();
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  ChoiceChip(
                    label: Text(tve.strings.news),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                  for (final c in cats) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(c.name),
                      selected: _category == c.slug,
                      onSelected: (_) => setState(() => _category = c.slug),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      Expanded(
        child: TvePagedView<TveNews>(
          key: ValueKey(_category),
          fetch: (c) => tve.api.listNews(
            category: _category == null ? null : [_category!],
            limit: tve.config.pageSize,
            cursor: c,
          ),
          itemBuilder: (context, n) => TveNewsTile(news: n),
        ),
      ),
    ]);
  }
}

class TveNewsTile extends StatelessWidget {
  final TveNews news;
  const TveNewsTile({super.key, required this.news});

  @override
  Widget build(BuildContext context) {
    final r = TveScope.of(context).design.radius;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TveNewsDetailScreen(slug: news.slug))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: TveImage(news.image, radius: r, aspectRatio: 4 / 3)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(news.title,
                maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              [if (news.categories.isNotEmpty) news.categories.first.label, formatDate(news.publishedAt)].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
        ),
      ]),
    );
  }
}

class TveNewsDetailScreen extends StatelessWidget {
  final String slug;
  const TveNewsDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tve.strings.news)),
      body: TveFuture<TveNews>(
        load: () => tve.api.getNews(slug, include: const ['categories']),
        builder: (context, n, _) => ListView(children: [
          if (n.image != null) TveImage(n.image),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(formatDate(n.publishedAt), style: Theme.of(context).textTheme.bodySmall)),
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () => SharePlus.instance.share(ShareParams(text: tve.shareText(n.title))),
                ),
              ]),
              const Divider(),
              TveHtml(n.contentHtml ?? n.excerpt ?? ''),
            ]),
          ),
        ]),
      ),
    );
  }
}
