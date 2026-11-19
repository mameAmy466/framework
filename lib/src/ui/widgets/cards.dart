import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../tve_scope.dart';
import 'tve_image.dart';

String formatDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

String formatDate(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  final diff = DateTime.now().difference(l);
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes.clamp(1, 59)} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year}';
}

String formatTime(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Carte vignette + titre + sous-titre (+ badge durée), utilisée dans toutes les grilles.
class TveMediaCard extends StatelessWidget {
  final String? image;
  final String title;
  final String? subtitle;
  final String? badge;
  final double aspectRatio;
  final VoidCallback? onTap;
  final int titleLines;

  const TveMediaCard({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    this.badge,
    this.aspectRatio = 16 / 9,
    this.onTap,
    this.titleLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final r = TveScope.of(context).design.radius;
    final t = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(r),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          TveImage(image, radius: r, aspectRatio: aspectRatio),
          if (badge != null && badge!.isNotEmpty)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Text(title, maxLines: titleLines, overflow: TextOverflow.ellipsis, style: t.titleSmall),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
      ]),
    );
  }
}

/// Rendu HTML (à propos, politique, articles) avec liens cliquables.
class TveHtml extends StatelessWidget {
  final String html;
  const TveHtml(this.html, {super.key});

  @override
  Widget build(BuildContext context) => HtmlWidget(
        html,
        textStyle: Theme.of(context).textTheme.bodyLarge,
        onTapUrl: (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      );
}

/// Badge « EN DIRECT ».
class TveLiveBadge extends StatelessWidget {
  const TveLiveBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
        child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
}
