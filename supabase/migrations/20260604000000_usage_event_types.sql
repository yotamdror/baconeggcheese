-- Funnel event types: places_search (server) → result_loaded → drawer_open / alternate_selected → navigate_tapped
alter table usage_events
  add column if not exists event_type text,
  add column if not exists in_manhattan boolean;

update usage_events set event_type = 'places_search' where event_type is null;

alter table usage_events
  alter column event_type set not null;

alter table usage_events
  add constraint usage_events_event_type_check check (
    event_type in (
      'places_search',
      'result_loaded',
      'drawer_open',
      'alternate_selected',
      'navigate_tapped',
      'share_tapped'
    )
  );
