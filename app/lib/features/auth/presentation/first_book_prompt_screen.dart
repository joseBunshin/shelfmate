// E1-007 first-book activation prompt — Library tab empty state with a
// prominent Add button. Real Library tab + Add Book flow lands in U4;
// this screen is the empty-state placeholder rendered between
// onboarding and U4's Library implementation.

import 'package:flutter/material.dart';

class FirstBookPromptScreen extends StatelessWidget {
  const FirstBookPromptScreen({super.key, required this.onAdd});

  /// Tapping the Add button transitions to U4's Add Book flow. Until U4,
  /// callers can pass a placeholder that shows a "coming soon" snack bar.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: SafeArea(
        child: Center(
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
                  'Add the book you\'re reading right now to get started.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add a book'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
