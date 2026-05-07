// UserBook domain model. Mirrors public.user_books from U2 schema.

import 'package:flutter/foundation.dart';

import 'book.dart';

enum UserBookStatus {
  reading,
  read,
  wantToRead,
  dropped;

  /// Human-friendly label for the status.
  String get label {
    switch (this) {
      case UserBookStatus.reading:
        return 'Reading';
      case UserBookStatus.read:
        return 'Read';
      case UserBookStatus.wantToRead:
        return 'Want to Read';
      case UserBookStatus.dropped:
        return 'Dropped';
    }
  }

  /// Wire-form value matching the public.user_book_status enum.
  String get wireValue {
    switch (this) {
      case UserBookStatus.reading:
        return 'reading';
      case UserBookStatus.read:
        return 'read';
      case UserBookStatus.wantToRead:
        return 'want_to_read';
      case UserBookStatus.dropped:
        return 'dropped';
    }
  }
}

@immutable
class UserBook {
  const UserBook({
    required this.id,
    required this.book,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.rating,
    this.note,
    this.progressPage,
    this.finishedAt,
  });

  final String id;
  final Book book;
  final UserBookStatus status;
  final double? rating;
  final String? note;
  final int? progressPage;
  final DateTime? finishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserBook copyWith({
    UserBookStatus? status,
    double? rating,
    String? note,
    int? progressPage,
    DateTime? finishedAt,
    DateTime? updatedAt,
  }) {
    return UserBook(
      id: id,
      book: book,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      note: note ?? this.note,
      progressPage: progressPage ?? this.progressPage,
      finishedAt: finishedAt ?? this.finishedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserBook && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
