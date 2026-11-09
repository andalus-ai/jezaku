alter table messaging_fanout_target_deliveries
    add column acknowledged_at timestamptz,
    add column updated_at timestamptz not null default now();

alter table messaging_fanout_target_deliveries
    drop constraint chk_messaging_target_delivery_status;

alter table messaging_fanout_target_deliveries
    add constraint chk_messaging_target_delivery_status
        check (status in ('ready', 'acknowledged')),
    add constraint chk_messaging_target_delivery_ack_after_created
        check (acknowledged_at is null or acknowledged_at >= created_at),
    add constraint chk_messaging_target_delivery_updated_after_created
        check (updated_at >= created_at);

create index idx_messaging_target_delivery_realtime_ready
    on messaging_fanout_target_deliveries (recipient_user_id, created_at)
    where delivery_target = 'realtime' and status = 'ready';
