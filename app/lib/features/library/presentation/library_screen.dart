// E2 Library tab. Three sub-tabs (Reading / Read / Want to Read) over the
// userBooksStreamProvider. Empty state shows the first-book prompt copy.
// Tapping a book opens BookDetailScreen. FAB → AddBookScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_book_repository.dart';
import '../domain/user_book.dart';
import 'add_book_screen.dart';
import 'book_cover.dart';
import 'book_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  static const _tabs = [
    UserBookStatus.reading,
    UserBookStatus.read,
    UserBookStatus.wantToRead,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBooks = ref.watch(userBooksStreamProvider);

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: TabBar(tabs: _tabs.map((s) => Tab(text: s.label)).toList()),
        ),
        body: asyncBooks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (books) {
            if (books.isEmpty) {
              return const _EmptyLibrary();
            }
            return TabBarView(
              children: _tabs.map((status) {
                final filtered = books.where((u) => u.status == status).toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                if (filtered.isEmpty) {
                  return _EmptyShelf(status: status);
                }
                return _ShelfList(books: filtered);
              }).toList(),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddBookScreen())),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'Your shelves are empty',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap Add below to find the book you\'re reading.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.status});
  final UserBookStatus status;

  @override
  Widget build(BuildContext context) {
    final hint = switch (status) {
      UserBookStatus.reading => 'No books in progress.',
      UserBookStatus.read => 'No finished reads yet.',
      UserBookStatus.wantToRead => 'No backlog yet.',
      UserBookStatus.dropped => 'Nothing dropped.',
    };
    return Center(
      child: Text(hint, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _ShelfList extends StatelessWidget {
  const _ShelfList({required this.books});
  final List<UserBook> books;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      itemCount: books.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final ub = books[i];
        return _BookRow(userBook: ub);
      },
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({required this.userBook});
  final UserBook userBook;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookDetailScreen(userBookId: userBook.id),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 64, child: BookCoverWidget(book: userBook.book)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userBook.book.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userBook.book.authorsLine,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (userBook.rating != null) ...[
                    const SizedBox(height: 6),
                    _StarRow(rating: userBook.rating!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Row(
      children: List.generate(5, (i) {
        final v = rating - i;
        IconData icon;
        if (v >= 1) {
          icon = Icons.star;
        } else if (v >= 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: color, size: 16);
      }),
    );
  }
}
