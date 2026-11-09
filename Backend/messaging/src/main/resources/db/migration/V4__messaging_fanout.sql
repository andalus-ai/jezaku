create table messaging_fanout_envelopes (
    envelope_id varchar(80) primary key,
    outbox_id varchar(80) not null references messaging_outbox(outbox_id) on delete cascade,
    thread_id varchar(80) not null references messaging_threads(thread_id) on delete cascade,
    recipient_user_id varchar(120) not null,
    event_type varchar(96) not null,
    delivery_targets jsonb not null,
    payload jsonb not null,
    status varchar(32) not null default 'queued',
    created_at timestamptz not null,
    delivered_at timestamptz,
    last_error text not null default '',
    constraint uq_messaging_fanout_outbox_recipient
        unique (outbox_id, recipient_user_id),
    constraint chk_messaging_fanout_event_type
        check (event_type in (
            'messaging.thread.created',
            'messaging.message.sent',
            'messaging.message.deleted',
            'messaging.thread.read',
            'messaging.thread.muted',
            'messaging.thread.unmuted'
        )),
    constraint chk_messaging_fanout_status
        check (status in ('queued', 'delivered', 'failed')),
    constraint chk_messaging_fanout_targets_json
        check (jsonb_typeof(delivery_targets) = 'array'),
    constraint chk_messaging_fanout_targets_values
        check (delivery_targets <@ '["realtime", "notification"]'::jsonb),
    constraint chk_messaging_fanout_payload_json
        check (jsonb_typeof(payload) = 'object'),
    constraint chk_messaging_fanout_delivered_after_created
        check (delivered_at is null or delivered_at >= created_at)
);

create index idx_messaging_fanout_recipient_status_created
    on messaging_fanout_envelopes (recipient_user_id, status, created_at desc);

create index idx_messaging_fanout_thread_created
    on messaging_fanout_envelopes (thread_id, created_at desc);
