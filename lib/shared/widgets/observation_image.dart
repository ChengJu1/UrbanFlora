import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// One widget that handles every kind of photo source we use: HTTPS URLs
/// from Firebase, web blob URLs, and local file paths.
class ObservationImage extends StatelessWidget {
  const ObservationImage({
    required this.source,
    this.fit = BoxFit.cover,
    this.placeholderColor,
    this.errorIcon,
    super.key,
  });

  final String source;
  final BoxFit fit;
  final Color? placeholderColor;
  final Widget? errorIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = placeholderColor ?? scheme.surfaceContainerHigh;
    final error = errorIcon ?? const Icon(Icons.broken_image_outlined);

    if (source.isEmpty) {
      return ColoredBox(color: placeholder);
    }

    final isHttp =
        source.startsWith('http://') || source.startsWith('https://');
    final isBlob = source.startsWith('blob:');

    if (isHttp) {
      return CachedNetworkImage(
        imageUrl: source,
        fit: fit,
        placeholder: (_, __) => ColoredBox(color: placeholder),
        errorWidget: (_, __, ___) => Center(child: error),
      );
    }

    if (isBlob || kIsWeb) {
      return Image.network(
        source,
        fit: fit,
        errorBuilder: (_, __, ___) => Center(child: error),
      );
    }

    final path = source.startsWith('file://')
        ? Uri.parse(source).toFilePath()
        : source;
    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: (_, __, ___) => Center(child: error),
    );
  }
}
