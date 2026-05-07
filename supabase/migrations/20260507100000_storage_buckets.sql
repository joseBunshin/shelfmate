-- U4 storage: buckets for book covers + user avatars.
--
-- Affected privacy tables: none directly. Storage objects are governed
-- by storage.objects RLS policies which we set per-bucket.
--
-- Buckets:
--   covers   — book cover images. Public read (rendered on E10 landings),
--              service_role-only write (proxy-cover Edge Function uploads).
--              Content-addressed paths: covers/<book_id>.jpg.
--   avatars  — user avatar images. Authenticated read (app surfaces),
--              owner-only write. Path: avatars/<user_id>/<filename>.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('covers', 'covers', true, 5 * 1024 * 1024,
   array['image/jpeg', 'image/png', 'image/webp']::text[]),
  ('avatars', 'avatars', false, 2 * 1024 * 1024,
   array['image/jpeg', 'image/png', 'image/webp']::text[])
on conflict (id) do nothing;

-- ==========================================================================
-- covers — public read, service_role write
-- ==========================================================================
-- Public read so the E10 anon surfaces (rec landing, list, profile) can
-- render covers without auth. Writes go through the proxy-cover Edge
-- Function which uses service_role.

create policy covers_public_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'covers');

create policy covers_service_write on storage.objects
  for insert to service_role
  with check (bucket_id = 'covers');

create policy covers_service_update on storage.objects
  for update to service_role
  using (bucket_id = 'covers')
  with check (bucket_id = 'covers');

create policy covers_service_delete on storage.objects
  for delete to service_role
  using (bucket_id = 'covers');

-- ==========================================================================
-- avatars — authenticated read, owner-only write
-- ==========================================================================
-- Owner is encoded in the path: avatars/<user_id>/<filename>. The first
-- path segment must equal auth.uid()::text for the writer to claim it.

create policy avatars_authed_read on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars');

create policy avatars_owner_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_owner_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_owner_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_service_all on storage.objects
  for all to service_role
  using (bucket_id = 'avatars')
  with check (bucket_id = 'avatars');
