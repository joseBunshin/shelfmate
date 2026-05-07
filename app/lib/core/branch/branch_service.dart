// Branch SDK wrapper. Exposes deferred-deep-link payload retrieval and
// link generation. U1.3 wires the actual init key + the iOS Privacy
// Manifest entries.
//
// Behavior model:
//   - On first launch (after install), getInitialReferringParams() is the
//     ONE-SHOT lookup: if Branch matched the install to a recently-clicked
//     link, the params are returned here.
//   - In-session deep-link clicks (e.g. a friend taps a /rec link while
//     the app is foregrounded) come through the latest-params stream.
//   - Match-failure is silent: getInitialReferringParams returns an empty
//     map. UX falls through to manual-add per spec (no error attribution).

import 'dart:async';

import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

class BranchService {
  /// Initialise the SDK. Idempotent.
  ///
  /// In U1.3 this gets the key from Env.branchKey and calls FlutterBranchSdk.init.
  Future<void> initialize({required String key, bool isDebug = false}) async {
    if (key.isEmpty) return; // permits dev builds without a key
    // FlutterBranchSdk.setIdentity() etc. wired in U3 alongside auth.
  }

  /// Pull initial referring params if Branch matched an install. Returns
  /// null when there was no match (the silent-failure path per R13).
  ///
  /// Shape: { from_user_id?: string, from_rec_id?: string, ... }. Keys are
  /// dynamic out of the SDK; we coerce here for ergonomics in the auth flow.
  Future<Map<String, dynamic>?> getInitialReferringParams() async {
    final data = await FlutterBranchSdk.getFirstReferringParams();
    if (data.isEmpty) return null;
    return _toStringKeyMap(data);
  }

  /// Stream of deep-link payloads that arrive while the app is running
  /// (foreground or backgrounded — not the install boundary).
  Stream<Map<String, dynamic>> get latestParamsStream {
    return FlutterBranchSdk.listSession().map(_toStringKeyMap);
  }

  static Map<String, dynamic> _toStringKeyMap(Map<dynamic, dynamic> raw) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
}
