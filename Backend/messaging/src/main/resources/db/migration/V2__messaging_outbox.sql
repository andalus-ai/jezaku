create table messaging_outbox (
    outbox_id varchar(80) primary key,
    aggregate_type varchar(64) not null,
    aggregate_id varchar(160) not null,
    event_type varchar(96) not null,
    payload jsonb not null,
    status varchar(32) not null default 'pending',
    attempts integer not null default 0,
    created_at timestamptz not null,
    next_attempt_at timestamptz not null,
    processed_at timestamptz,
    constraint chk_messaging_outbox_event_type
        check (event_type in (
            'messaging.thread.created',
            'messaging.message.sent',
            'messaging.message.deleted',
            'messaging.thread.read',
            'messaging.thread.muted',
            'messaging.thread.unmuted'
        )),
    constraint chk_messaging_outbox_status
        check (status in ('pending', 'dispatched', 'failed')),
    constraint chk_messaging_outbox_attempts
        check (attempts >= 0),
    constraint chk_messaging_outbox_payload_json
        check (jsonb_typeof(payload) = 'object'),
    constraint chk_messaging_outbox_processed_after_created
        check (processed_at is null or processed_at >= created_at)
);

create index idx_messaging_outbox_pending
    on messaging_outbox (status, next_attempt_at, created_at)
    where status = 'pending';

create index idx_messaging_outbox_aggregate
    on messaging_outbox (aggregate_type, aggregate_id, created_at);
