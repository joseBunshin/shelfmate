// Open Library search + ISBN lookup client.
//
// Open Library is the v1 primary source for book metadata; Google Books is
// the U4 fallback (lands when search misses or covers are unavailable).
// Both APIs are public — no auth required, no rate limits we'll hit at
// dev volume. Production hardening (exponential backoff, SQLite cache,
// 7-day TTL) per spec lands in U4 follow-up.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/book.dart';

class OpenLibraryClient {
  OpenLibraryClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _searchEndpoint = 'https://openlibrary.org/search.json';
  static const _coversBase = 'https://covers.openlibrary.org/b/id';

  /// Free-text search. Returns up to 10 results.
  Future<List<Book>> search(String query) async {
    if (query.trim().isEmpty) return const [];

    final uri = Uri.parse(_searchEndpoint).replace(
      queryParameters: {
        'q': query,
        'limit': '10',
        'fields': 'key,title,author_name,first_publish_year,isbn,cover_i',
      },
    );

    try {
      final resp = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return const [];
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final docs = (body['docs'] as List?) ?? const [];
      return docs.map(_docToBook).toList();
    } catch (e) {
      debugPrint('OpenLibrary search failed: $e');
      return const [];
    }
  }

  /// ISBN lookup — used by the scanner flow (E2-002). v1 falls back to a
  /// search-by-ISBN since the /isbn/{n}.json endpoint sometimes returns 404
  /// for valid ISBNs that are present in search.
  Future<Book?> byIsbn(String isbn) async {
    final results = await search('isbn:$isbn');
    if (results.isEmpty) return null;
    return results.first;
  }

  Book _docToBook(dynamic raw) {
    final doc = raw as Map<String, dynamic>;
    final key = (doc['key'] as String?) ?? '';
    final externalId = key.isNotEmpty
        ? 'openlibrary:$key'
        : 'openlibrary:unknown';
    final coverId = doc['cover_i'] as int?;
    final coverUrl = coverId != null ? '$_coversBase/$coverId-L.jpg' : null;
    final isbns =
        (doc['isbn'] as List?)?.whereType<String>().toList() ?? const [];
    final isbn13 = isbns.firstWhere((i) => i.length == 13, orElse: () => '');
    final authors =
        (doc['author_name'] as List?)?.whereType<String>().toList() ?? const [];

    return Book(
      // Local id is just the external_id; the real Supabase row id will
      // be assigned at insert time when the books cache is wired.
      id: externalId,
      externalId: externalId,
      isbn13: isbn13.isEmpty ? null : isbn13,
      title: (doc['title'] as String?) ?? 'Untitled',
      authors: authors,
      coverUrl: coverUrl,
      publicationYear: doc['first_publish_year'] as int?,
    );
  }

  void dispose() => _client.close();
}

final openLibraryClientProvider = Provider<OpenLibraryClient>((ref) {
  final client = OpenLibraryClient();
  ref.onDispose(client.dispose);
  return client;
});
