// E2-001 Add Book search + result list. Open Library is the source.
// Tapping a result opens the shelf-picker bottom sheet; choosing Read
// kicks off the finish-book flow (E2-005).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/open_library_client.dart';
import '../data/user_book_repository.dart';
import '../domain/book.dart';
import '../domain/user_book.dart';
import 'book_cover.dart';
import 'finish_book_flow.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  const AddBookScreen({super.key});

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Book> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ref.read(openLibraryClientProvider).search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Search failed. Try again.';
      });
    }
  }

  Future<void> _openShelfPicker(Book book) async {
    final status = await showModalBottomSheet<UserBookStatus>(
      context: context,
      builder: (_) => _ShelfPickerSheet(book: book),
    );
    if (!mounted || status == null) return;

    if (status == UserBookStatus.read) {
      // Kick into the finish-book flow — adds + collects rating + note
      // + plays the celebration moment (E2-005).
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => FinishBookFlow(book: book)),
      );
      return;
    }

    await ref.read(userBookRepositoryProvider).upsertBook(book, status);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('Added to ${status.label}')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a book')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Title, author, or ISBN',
                ),
              ),
            ),
            Expanded(
              child: _Body(
                searching: _searching,
                error: _error,
                results: _results,
                onTap: _openShelfPicker,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.searching,
    required this.error,
    required this.results,
    required this.onTap,
  });

  final bool searching;
  final String? error;
  final List<Book> results;
  final void Function(Book) onTap;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text(error!));
    }
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Type a title, author, or ISBN to search Open Library.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 16),
      itemBuilder: (context, i) {
        final b = results[i];
        return InkWell(
          onTap: () => onTap(b),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 56, child: BookCoverWidget(book: b)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.authorsLine,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (b.publicationYear != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${b.publicationYear}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShelfPickerSheet extends StatelessWidget {
  const _ShelfPickerSheet({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                book.title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Reading'),
              onTap: () => Navigator.of(context).pop(UserBookStatus.reading),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Read'),
              subtitle: const Text('Rate + note + celebration'),
              onTap: () => Navigator.of(context).pop(UserBookStatus.read),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('Want to Read'),
              onTap: () => Navigator.of(context).pop(UserBookStatus.wantToRead),
            ),
          ],
        ),
      ),
    );
  }
}
