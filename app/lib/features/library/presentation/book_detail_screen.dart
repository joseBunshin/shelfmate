// E3-001 Book Detail. Renders status pill + cover + title/author + rating
// + own note. Friend-activity strip + recommend/list-add action buttons
// land in U5 once the social layer Flutter UI exists.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_book_repository.dart';
import '../domain/user_book.dart';
import 'book_cover.dart';
import 'finish_book_flow.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.userBookId});

  final String userBookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ub = ref.watch(userBookRepositoryProvider).findById(userBookId);
    if (ub == null) {
      return const Scaffold(body: Center(child: Text('Book not found.')));
    }
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 130, child: BookCoverWidget(book: ub.book)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusPill(status: ub.status),
                    const SizedBox(height: 8),
                    Text(
                      ub.book.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ub.book.authorsLine,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (ub.book.publicationYear != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${ub.book.publicationYear}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (ub.rating != null) _RatingRow(rating: ub.rating!),
          if (ub.note != null && ub.note!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Your note',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(ub.note!, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: 24),
          _ActionRow(userBook: ub),
          const SizedBox(height: 24),
          if (ub.book.description != null &&
              ub.book.description!.isNotEmpty) ...[
            Text('About', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              ub.book.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Friend activity',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Friend notes + reactions land in U5 (social layer).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final UserBookStatus status;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondaryContainer;
    final on = Theme.of(context).colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: on,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            rating - i >= 1
                ? Icons.star
                : rating - i >= 0.5
                ? Icons.star_half
                : Icons.star_border,
            color: color,
          ),
        const SizedBox(width: 8),
        Text(
          rating.toStringAsFixed(1),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.userBook});
  final UserBook userBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = userBook.status == UserBookStatus.read;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!isRead)
          OutlinedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Mark read'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FinishBookFlow(
                  book: userBook.book,
                  existingUserBookId: userBook.id,
                ),
              ),
            ),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.send_outlined),
          label: const Text('Recommend'),
          onPressed: () => _showComingSoon(context, 'Recommend (U5)'),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Add to list'),
          onPressed: () => _showComingSoon(context, 'Lists (U5)'),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.ios_share),
          label: const Text('Share card'),
          onPressed: () => _showComingSoon(context, 'Share card (U4)'),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String label) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('$label — coming soon')));
  }
}
