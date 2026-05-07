// Genre prefs persistence — writes to public.users.genre_preferences (jsonb
// column on the users table from U2 schema). Read at sign-in to skip the
// picker for returning users.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/client.dart';

/// The 14 v1 genres per buildspec E1-005. Order is intentional — UX shows
/// the most-common picks first to reduce decision time.
const List<String> v1Genres = [
  'literary',
  'sci_fi',
  'fantasy',
  'mystery',
  'romance',
  'thriller',
  'historical',
  'memoir',
  'biography',
  'essays',
  'poetry',
  'short_stories',
  'horror',
  'graphic_novels',
];

class GenreRepository {
  GenreRepository(this._client);

  final SupabaseClient _client;

  Future<void> setGenrePreferences(List<String> genres) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot save genre preferences without a session');
    }
    await _client
        .from('users')
        .update({'genre_preferences': genres})
        .eq('id', userId);
  }

  Future<List<String>> readGenrePreferences() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final row = await _client
        .from('users')
        .select('genre_preferences')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return const [];
    final raw = row['genre_preferences'];
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return const [];
  }
}

final genreRepositoryProvider = Provider<GenreRepository>((ref) {
  return GenreRepository(ref.watch(supabaseClientProvider));
});
