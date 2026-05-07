// UserBookRepository — abstract over storage backend so the U4 dev flow can
// run against an in-memory store (works without Supabase secrets) and the
// U1.3 wiring session swaps in a Supabase-backed implementation without
// touching any feature code.
//
// The in-memory store is INTENTIONALLY non-persistent. Hot reload + app
// restart wipe state. Once Supabase init is wired with real credentials,
// SupabaseUserBookRepository (lands in U1.3) takes over and persistence
// works through public.user_books with RLS.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/book.dart';
import '../domain/user_book.dart';

abstract class UserBookRepository {
  Stream<List<UserBook>> watchAll();
  List<UserBook> currentSnapshot();
  UserBook? findById(String id);
  Future<UserBook> upsertBook(Book book, UserBookStatus status);
  Future<UserBook> update(UserBook userBook);
  Future<void> delete(String userBookId);
}

class InMemoryUserBookRepository implements UserBookRepository {
  final Map<String, UserBook> _byId = {};
  final StreamController<List<UserBook>> _controller =
      StreamController<List<UserBook>>.broadcast();

  void _emit() => _controller.add(_byId.values.toList(growable: false));

  @override
  Stream<List<UserBook>> watchAll() async* {
    yield _byId.values.toList(growable: false);
    yield* _controller.stream;
  }

  @override
  List<UserBook> currentSnapshot() => _byId.values.toList(growable: false);

  @override
  UserBook? findById(String id) => _byId[id];

  @override
  Future<UserBook> upsertBook(Book book, UserBookStatus status) async {
    // De-dup on book.id — adding the same book twice updates the existing row.
    final existing = _byId.values
        .where((u) => u.book.id == book.id)
        .firstOrNull;
    if (existing != null) {
      final updated = existing.copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
      _byId[updated.id] = updated;
      _emit();
      return updated;
    }
    final now = DateTime.now();
    final id = 'mem:${DateTime.now().microsecondsSinceEpoch}';
    final created = UserBook(
      id: id,
      book: book,
      status: status,
      createdAt: now,
      updatedAt: now,
      finishedAt: status == UserBookStatus.read ? now : null,
    );
    _byId[id] = created;
    _emit();
    return created;
  }

  @override
  Future<UserBook> update(UserBook userBook) async {
    _byId[userBook.id] = userBook;
    _emit();
    return userBook;
  }

  @override
  Future<void> delete(String userBookId) async {
    _byId.remove(userBookId);
    _emit();
  }

  void dispose() => _controller.close();
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

final userBookRepositoryProvider = Provider<UserBookRepository>((ref) {
  final repo = InMemoryUserBookRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final userBooksStreamProvider = StreamProvider<List<UserBook>>((ref) {
  return ref.watch(userBookRepositoryProvider).watchAll();
});
