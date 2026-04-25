create table if not exists usage_events (
  id          bigserial primary key,
  created_at  timestamptz not null default now(),
  category    text        not null check (category in ('pizza', 'bagel', 'bec')),
  result_count int        not null default 0,
  lat_approx  numeric(8,3),
  lng_approx  numeric(8,3)
);

-- Service role can insert; anon cannot read
alter table usage_events enable row level security;

create policy "service role only"
  on usage_events
  for all
  using (auth.role() = 'service_role');
