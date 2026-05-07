// E1-006 referrer connect. Shows the inviter's name + Add/Skip CTAs after
// Branch matched the install token. Match-failure path skips this screen
// entirely (handled in routing) and surfaces the manual-add prompt.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/referrer_repository.dart';

class ReferrerConnectScreen extends ConsumerStatefulWidget {
  const ReferrerConnectScreen({
    super.key,
    required this.inviterName,
    required this.fromUserId,
    required this.branchToken,
    required this.installId,
    required this.onDone,
  });

  final String inviterName;
  final String fromUserId;
  final String branchToken;
  final String installId;
  final VoidCallback onDone;

  @override
  ConsumerState<ReferrerConnectScreen> createState() =>
      _ReferrerConnectScreenState();
}

class _ReferrerConnectScreenState extends ConsumerState<ReferrerConnectScreen> {
  bool _busy = false;

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      final outcome = await ref
          .read(referrerRepositoryProvider)
          .claimReferrer(
            branchToken: widget.branchToken,
            installId: widget.installId,
            fromUserId: widget.fromUserId,
          );
      // Outcome is informational here — even on `ok=false` we advance, since
      // referrer-connect is best-effort per R13. The user can manually add
      // friends in the social tab.
      debugPrint('referrer outcome ok=${outcome.ok} reason=${outcome.reason}');
    } catch (e) {
      debugPrint('verify-referrer failed: $e');
    } finally {
      if (mounted) widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'You were invited by',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.inviterName,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'Add them as a friend to share notes and recs.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _connect,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Add ${widget.inviterName}'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : widget.onDone,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
