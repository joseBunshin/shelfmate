# What this PR does

<!-- 1-3 sentences describing the change. Reference U-IDs from the plan
     (U1-U8) and buildspec story IDs (E1-001, E2-005, etc.) when applicable. -->

## Plan / story references

- **Implementation unit:** U?
- **Buildspec stories:** E?-???
- **Origin requirements:** R?

## Privacy-affected migration discipline

<!-- Per AGENTS.md: every migration that touches one of the privacy-affected
     tables (users, privacy_settings, comments, user_books, friendships,
     book_lists, book_list_shares, recommendations, profiles) MUST include an
     accompanying RLS policy update in the same commit. -->

- [ ] No privacy-affected tables touched, OR
- [ ] Privacy-affected tables touched AND accompanying RLS policy update is in this commit AND pgTAP suite is updated to cover the new state

## Test plan

- [ ] Unit + widget tests added/updated
- [ ] Integration test added if change crosses layers
- [ ] pgTAP test added if RLS policy changed
- [ ] Smoke test still passes locally

## User-visible changes

<!-- Screenshots / GIF / before-after if UI; or "none" for backend / infra. -->
