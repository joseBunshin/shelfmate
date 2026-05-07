// E1-005 genre picker. 14 chips, multi-select, "at least 3" required for
// the primary CTA but Skip is allowed. Writes selected genres to
// users.genre_preferences via GenreRepository.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/genre_repository.dart';

class GenrePickerScreen extends ConsumerStatefulWidget {
  const GenrePickerScreen({super.key, required this.onDone});

  /// Called when the user finishes (continue or skip). The router uses this
  /// to advance into the referrer-connect step (or first-book-prompt if no
  /// referrer params present).
  final VoidCallback onDone;

  @override
  ConsumerState<GenrePickerScreen> createState() => _GenrePickerScreenState();
}

class _GenrePickerScreenState extends ConsumerState<GenrePickerScreen> {
  final Set<String> _selected = {};
  bool _busy = false;

  bool get _canContinue => _selected.length >= 3 && !_busy;

  Future<void> _save({required bool skipped}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(genreRepositoryProvider)
          .setGenrePreferences(skipped ? const [] : _selected.toList());
    } catch (e) {
      // Non-fatal: user can pick later in settings (E9).
      debugPrint('Failed to save genre prefs: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onDone();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('What do you read?'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => _save(skipped: true),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pick at least 3. We use these to surface friends-of-friends recs.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: v1Genres
                        .map(
                          (g) => FilterChip(
                            label: Text(_humanize(g)),
                            selected: _selected.contains(g),
                            onSelected: (on) => setState(() {
                              if (on) {
                                _selected.add(g);
                              } else {
                                _selected.remove(g);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _canContinue ? () => _save(skipped: false) : null,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _selected.length >= 3
                            ? 'Continue'
                            : 'Pick ${3 - _selected.length} more',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _humanize(String slug) {
    return slug
        .split('_')
        .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }
}
