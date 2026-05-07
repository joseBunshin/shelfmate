// Reusable book cover widget with gradient-initials fallback when no
// coverUrl is available (covers AE9 cover-fallback case). Mirrors the
// web-side BookCover component's behavior.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../domain/book.dart';

class BookCoverWidget extends StatelessWidget {
  const BookCoverWidget({
    super.key,
    required this.book,
    this.width,
    this.height,
  });

  final Book book;
  final double? width;
  final double? height;

  String _initials() {
    final parts = book.title
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp(r'^[A-Za-z]').hasMatch(w))
        .toList();
    if (parts.isEmpty) return 'B';
    return parts.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    final widget = book.coverUrl == null
        ? _Fallback(initials: _initials())
        : CachedNetworkImage(
            imageUrl: book.coverUrl!,
            fit: BoxFit.cover,
            placeholder: (_, _) => _Fallback(initials: _initials()),
            errorWidget: (_, _, _) => _Fallback(initials: _initials()),
          );

    return ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: SizedBox(width: width, height: height, child: widget),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF374151), Color(0xFF1F2937), Color(0xFF030712)],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE4E4E7),
          ),
        ),
      ),
    );
  }
}
