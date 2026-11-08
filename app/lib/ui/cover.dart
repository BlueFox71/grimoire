import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/model.dart';
import 'theme.dart';

/// Couverture du livre ; sans image (ou si elle ne se charge pas) : aplat coloré + titre.
class Cover extends StatelessWidget {
  final Book book;
  final double width;
  final double? radius;
  const Cover(this.book, {super.key, this.width = 44, this.radius});

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    final placeholder = _Placeholder(book: book, width: width, height: height);
    final url = book.coverUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? width / 12),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final Book book;
  final double width;
  final double height;
  const _Placeholder({required this.book, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final hue = (book.title.hashCode % 360).abs().toDouble();
    final top = HSLColor.fromAHSL(1, hue, 0.45, 0.38).toColor();
    final bottom = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.5, 0.22).toColor();
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom])),
      padding: EdgeInsets.all(width / 10),
      alignment: Alignment.bottomCenter,
      child: width < 60
          ? null
          : Text(
              book.title,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: displayStyle(width / 7, Colors.white, weight: 600),
            ),
    );
  }
}
