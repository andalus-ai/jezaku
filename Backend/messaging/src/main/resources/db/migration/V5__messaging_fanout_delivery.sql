alter table messaging_fanout_envelopes
    add column attempts integer not null default 0,
    add column next_attempt_at timestamptz not null default now(),
    add column updated_at timestamptz not null default now(),
    add constraint chk_messaging_fanout_attempts_non_negative
        check (attempts >= 0),
    add constraint chk_messaging_fanout_next_attempt_after_created
        check (next_attempt_at >= created_at),
    add constraint chk_messaging_fanout_updated_after_created
        check (updated_at >= created_at);

create index idx_messaging_fanout_retry
    on messaging_fanout_envelopes (next_attempt_at, created_at)
    where status in ('queued', 'failed');
