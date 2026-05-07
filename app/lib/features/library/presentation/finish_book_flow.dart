// E2-005 finish-book flow. Three steps:
//   1. Rating  (1-5 half-stars; Done skips)
//   2. Note    (optional text; keyboard does NOT auto-open per spec)
//   3. Celebration (book cover + scale-fade animation + Share + Library)
//
// The flow is the magic-moment seam (R25). Real polish lands as designs
// land — this is the interaction shape, with visual refinement coming.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_book_repository.dart';
import '../domain/book.dart';
import '../domain/user_book.dart';
import 'book_cover.dart';

class FinishBookFlow extends ConsumerStatefulWidget {
  const FinishBookFlow({
    super.key,
    required this.book,
    this.existingUserBookId,
  });

  final Book book;
  final String? existingUserBookId;

  @override
  ConsumerState<FinishBookFlow> createState() => _FinishBookFlowState();
}

enum _Step { rating, note, celebration }

class _FinishBookFlowState extends ConsumerState<FinishBookFlow> {
  _Step _step = _Step.rating;
  double _rating = 0;
  final TextEditingController _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    setState(() => _saving = true);
    final repo = ref.read(userBookRepositoryProvider);
    UserBook updated;
    if (widget.existingUserBookId != null) {
      final existing = repo.findById(widget.existingUserBookId!);
      if (existing != null) {
        updated = existing.copyWith(
          status: UserBookStatus.read,
          rating: _rating > 0 ? _rating : null,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          finishedAt: DateTime.now(),
        );
        await repo.update(updated);
      }
    } else {
      final inserted = await repo.upsertBook(widget.book, UserBookStatus.read);
      updated = inserted.copyWith(
        rating: _rating > 0 ? _rating : null,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        finishedAt: DateTime.now(),
      );
      await repo.update(updated);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _step = _Step.celebration;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _step == _Step.celebration ? null : AppBar(),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (_step) {
            _Step.rating => _RatingStep(
              key: const ValueKey('rating'),
              book: widget.book,
              rating: _rating,
              onChange: (v) => setState(() => _rating = v),
              onContinue: () => setState(() => _step = _Step.note),
              onSkip: _commit,
              saving: _saving,
            ),
            _Step.note => _NoteStep(
              key: const ValueKey('note'),
              book: widget.book,
              controller: _note,
              onSave: _commit,
              saving: _saving,
            ),
            _Step.celebration => _CelebrationStep(
              key: const ValueKey('celebration'),
              book: widget.book,
            ),
          },
        ),
      ),
    );
  }
}

class _RatingStep extends StatelessWidget {
  const _RatingStep({
    super.key,
    required this.book,
    required this.rating,
    required this.onChange,
    required this.onContinue,
    required this.onSkip,
    required this.saving,
  });

  final Book book;
  final double rating;
  final ValueChanged<double> onChange;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Center(
            child: SizedBox(width: 140, child: BookCoverWidget(book: book)),
          ),
          const SizedBox(height: 24),
          Text(
            book.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            book.authorsLine,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text(
            'How was it?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _StarRater(value: rating, onChange: onChange),
          const Spacer(),
          FilledButton(
            onPressed: saving ? null : (rating > 0 ? onContinue : null),
            child: const Text('Continue'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: saving ? null : onSkip,
            child: const Text('Skip rating'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NoteStep extends StatelessWidget {
  const _NoteStep({
    super.key,
    required this.book,
    required this.controller,
    required this.onSave,
    required this.saving,
  });

  final Book book;
  final TextEditingController controller;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'Anything to remember?',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Optional. You can edit it later from Book Detail.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 6,
            // Per spec: keyboard does NOT auto-open. autofocus stays false.
            decoration: const InputDecoration(
              hintText: 'A line, a paragraph, or nothing.',
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CelebrationStep extends StatefulWidget {
  const _CelebrationStep({super.key, required this.book});
  final Book book;

  @override
  State<_CelebrationStep> createState() => _CelebrationStepState();
}

class _CelebrationStepState extends State<_CelebrationStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween(
      begin: 0.92,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_ctrl);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) => Opacity(
              opacity: _fade.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Center(
                  child: SizedBox(
                    width: 180,
                    child: BookCoverWidget(book: widget.book),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Finished!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            widget.book.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.ios_share),
            label: const Text('Share this read'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share card — coming soon')),
              );
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Back to library'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StarRater extends StatelessWidget {
  const _StarRater({required this.value, required this.onChange});
  final double value;
  final ValueChanged<double> onChange;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final position = i + 1.0;
        IconData icon;
        if (value >= position) {
          icon = Icons.star;
        } else if (value >= position - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return GestureDetector(
          onTap: () => onChange(value == position ? position - 0.5 : position),
          onLongPress: () => onChange(position - 0.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(icon, color: color, size: 36),
          ),
        );
      }),
    );
  }
}
