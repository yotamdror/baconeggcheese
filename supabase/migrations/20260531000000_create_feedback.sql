create table if not exists feedback (
  id          bigserial primary key,
  created_at  timestamptz not null default now(),
  message     text        not null,
  app_version text
);

alter table feedback enable row level security;

create policy "service role only"
  on feedback
  for all
  using (auth.role() = 'service_role');
