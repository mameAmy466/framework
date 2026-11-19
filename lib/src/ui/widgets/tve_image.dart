import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Image réseau en cache avec placeholder, arrondi et repli si l'URL est nulle.
class TveImage extends StatelessWidget {
  final String? url;
  final double? width, height;
  final BoxFit fit;
  final double? radius;
  final double aspectRatio;
  final IconData placeholderIcon;

  const TveImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
    this.aspectRatio = 16 / 9,
    this.placeholderIcon = Icons.image_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ph = Container(
      color: c.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(placeholderIcon, color: c.onSurfaceVariant),
    );
    Widget img = url == null || url!.isEmpty
        ? ph
        : CachedNetworkImage(
            imageUrl: url!,
            width: width,
            height: height,
            fit: fit,
            placeholder: (_, __) => ph,
            errorWidget: (_, __, ___) => ph,
          );
    if (width == null && height == null) img = AspectRatio(aspectRatio: aspectRatio, child: img);
    final r = radius ?? 0;
    return r == 0 ? img : ClipRRect(borderRadius: BorderRadius.circular(r), child: img);
  }
}
