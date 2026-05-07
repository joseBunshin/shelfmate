// ReferrerRepository — calls the verify-referrer Edge Function with the
// Branch deferred-deep-link token + install_id + sender's user_id.
// On success, a pending friendship row is created server-side.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/client.dart';

class ReferrerOutcome {
  ReferrerOutcome({required this.ok, this.reason, this.senderId});

  final bool ok;
  final String?
  reason; // 'replay'|'invalidated'|'blocked'|'sender_missing'|'self_referral'
  final String? senderId;
}

class ReferrerRepository {
  ReferrerRepository(this._client);

  final SupabaseClient _client;

  /// Invokes the verify-referrer Edge Function. Caller is expected to be
  /// authenticated; the function uses auth.uid() as the new-installer id.
  Future<ReferrerOutcome> claimReferrer({
    required String branchToken,
    required String installId,
    required String fromUserId,
  }) async {
    final response = await _client.functions.invoke(
      'verify-referrer',
      body: {
        'branch_token': branchToken,
        'install_id': installId,
        'from_user_id': fromUserId,
      },
    );

    final data = response.data;
    if (data is Map) {
      final ok = data['ok'] == true;
      final reason = data['reason']?.toString();
      return ReferrerOutcome(
        ok: ok,
        reason: reason,
        senderId: ok ? fromUserId : null,
      );
    }
    return ReferrerOutcome(ok: false, reason: 'malformed_response');
  }
}

final referrerRepositoryProvider = Provider<ReferrerRepository>((ref) {
  return ReferrerRepository(ref.watch(supabaseClientProvider));
});
