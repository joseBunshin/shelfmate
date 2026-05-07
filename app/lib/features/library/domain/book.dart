// Book domain model. Mirrors public.books from U2 schema. Used across the
// Library, Add Book, Book Detail, and Recommendations features.

import 'package:flutter/foundation.dart';

@immutable
class Book {
  const Book({
    required this.id,
    required this.externalId,
    required this.title,
    required this.authors,
    this.isbn13,
    this.coverUrl,
    this.publicationYear,
    this.description,
  });

  final String id;
  final String externalId;
  final String? isbn13;
  final String title;
  final List<String> authors;
  final String? coverUrl;
  final int? publicationYear;
  final String? description;

  String get authorsLine =>
      authors.isEmpty ? 'Unknown author' : authors.join(', ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Book && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
