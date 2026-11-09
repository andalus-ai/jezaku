create table messaging_fanout_target_deliveries (
    delivery_id varchar(96) primary key,
    envelope_id varchar(96) not null references messaging_fanout_envelopes(envelope_id) on delete cascade,
    thread_id varchar(96) not null references messaging_threads(thread_id) on delete cascade,
    recipient_user_id varchar(96) not null,
    delivery_target varchar(32) not null,
    event_type varchar(96) not null,
    payload jsonb not null,
    status varchar(32) not null default 'ready',
    created_at timestamptz not null default now(),
    constraint uq_messaging_target_delivery_envelope_target
        unique (envelope_id, delivery_target),
    constraint chk_messaging_target_delivery_target
        check (delivery_target in ('realtime', 'notification')),
    constraint chk_messaging_target_delivery_event_type
        check (event_type in (
            'messaging.thread.created',
            'messaging.message.sent',
            'messaging.message.deleted',
            'messaging.thread.read',
            'messaging.thread.muted',
            'messaging.thread.unmuted'
        )),
    constraint chk_messaging_target_delivery_status
        check (status in ('ready')),
    constraint chk_messaging_target_delivery_payload_json
        check (jsonb_typeof(payload) = 'object')
);

create index idx_messaging_target_delivery_recipient_target_created
    on messaging_fanout_target_deliveries (recipient_user_id, delivery_target, created_at desc);

create index idx_messaging_target_delivery_envelope
    on messaging_fanout_target_deliveries (envelope_id);
