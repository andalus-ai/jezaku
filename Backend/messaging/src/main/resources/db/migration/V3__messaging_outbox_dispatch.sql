alter table messaging_outbox
    add column updated_at timestamptz not null default now(),
    add column last_error text not null default '';

create index idx_messaging_outbox_retry
    on messaging_outbox (status, next_attempt_at, attempts)
    where status in ('pending', 'failed');
