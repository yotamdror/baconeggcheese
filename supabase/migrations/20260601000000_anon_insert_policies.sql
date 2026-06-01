-- DB-level enforcement so anon inserts via REST API can't bypass edge function limits
alter table feedback add constraint feedback_message_length
  check (char_length(message) <= 2000);

-- Allow edge functions to use the anon key instead of service_role for inserts
create policy "anon insert"
  on feedback
  for insert
  to anon
  with check (true);

create policy "anon insert"
  on usage_events
  for insert
  to anon
  with check (true);
