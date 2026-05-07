-- U1 smoke test. Verifies the init migration applied + extensions present.
-- Real RLS test suite (R22 — 36-base + NULL/no-row/symmetric edge cases)
-- lands in U2.

begin;

select plan(3);

-- The pgcrypto extension provides gen_random_uuid() used by primary keys
-- across the schema landing in U2.
select has_extension('pgcrypto', 'pgcrypto extension is installed');

-- The pg_net extension powers U7's webhook revalidation trigger.
select has_extension('pg_net', 'pg_net extension is installed');

-- The http extension is loaded for diagnostic use (rare; off the critical path).
select has_extension('http', 'http extension is installed');

select * from finish();

rollback;
