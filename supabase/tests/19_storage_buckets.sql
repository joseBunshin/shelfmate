-- pgTAP coverage for U4 storage buckets + RLS.
--
-- Verifies the migration created both buckets with correct config and
-- that the storage.objects RLS policies are wired. Cannot exercise the
-- full upload path from pgTAP (storage backend isn't available), but
-- can verify the policies attach to the right bucket.

begin;

select plan(8);

-- Buckets exist with expected config
select is(
  (select public from storage.buckets where id = 'covers'),
  true,
  'storage: covers bucket is public-read'
);

select is(
  (select public from storage.buckets where id = 'avatars'),
  false,
  'storage: avatars bucket is NOT public'
);

select is(
  (select file_size_limit from storage.buckets where id = 'covers'),
  (5 * 1024 * 1024)::bigint,
  'storage: covers bucket size limit = 5 MiB'
);

select is(
  (select file_size_limit from storage.buckets where id = 'avatars'),
  (2 * 1024 * 1024)::bigint,
  'storage: avatars bucket size limit = 2 MiB'
);

-- Policies attached
select ok(
  exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'covers_public_read'
  ),
  'storage RLS: covers_public_read policy attached'
);

select ok(
  exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'avatars_owner_insert'
  ),
  'storage RLS: avatars_owner_insert policy attached'
);

select ok(
  exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'avatars_owner_update'
  ),
  'storage RLS: avatars_owner_update policy attached'
);

select ok(
  exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'covers_service_write'
  ),
  'storage RLS: covers_service_write policy attached'
);

select * from finish();

rollback;
