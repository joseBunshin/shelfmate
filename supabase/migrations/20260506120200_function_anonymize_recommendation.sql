-- U2: anonymisation trigger for recommendations on sender deletion.
--
-- The recommendations.sender_id FK is ON DELETE SET NULL so the rec survives
-- when the sender deletes their account (R23). The recipient still has the
-- book in their inbox — they just see "A ShelfMate user" as the sender. This
-- trigger writes that snapshot the moment sender_id transitions to NULL.
--
-- Why this is a trigger and not part of delete-account: the FK SET NULL
-- happens inside Postgres regardless of which path triggered the delete
-- (Edge Function, manual SQL, cascade chain). Putting the anonymisation
-- in a row trigger guarantees the snapshot is consistent with the state
-- of sender_id, no matter how sender_id became NULL.

create or replace function public.fn_anonymize_recommendation_sender()
returns trigger
language plpgsql
as $$
begin
  if old.sender_id is not null and new.sender_id is null then
    new.sender_display_name_snapshot := 'A ShelfMate user';
  end if;
  return new;
end;
$$;

create trigger anonymize_recommendation_sender
  before update on public.recommendations
  for each row execute function public.fn_anonymize_recommendation_sender();

comment on function public.fn_anonymize_recommendation_sender() is
  'Sets sender_display_name_snapshot to a generic label when sender_id transitions to NULL (which happens via FK ON DELETE SET NULL when the sender deletes their account). R23.';
