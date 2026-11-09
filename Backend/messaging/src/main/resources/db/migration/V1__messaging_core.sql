create table messaging_threads (
    thread_id varchar(80) primary key,
    thread_type varchar(32) not null,
    target_type varchar(48) not null default '',
    target_id varchar(160) not null default '',
    title varchar(200) not null,
    participant_ids jsonb not null,
    status varchar(32) not null,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    constraint chk_messaging_threads_type
        check (thread_type in ('direct', 'group', 'place', 'event', 'journey', 'memory')),
    constraint chk_messaging_threads_status
        check (status in ('active', 'archived')),
    constraint chk_messaging_threads_participants_json
        check (jsonb_typeof(participant_ids) = 'array'),
    constraint chk_messaging_threads_updated_after_created
        check (updated_at >= created_at)
);

create index idx_messaging_threads_status_updated_at
    on messaging_threads (status, updated_at desc);

create index idx_messaging_threads_target
    on messaging_threads (target_type, target_id)
    where target_type <> '' and target_id <> '';

create table messaging_messages (
    message_id varchar(80) primary key,
    thread_id varchar(80) not null references messaging_threads(thread_id) on delete cascade,
    sender_id varchar(120) not null,
    body text not null,
    media_ids jsonb not null default '[]'::jsonb,
    position_latitude double precision,
    position_longitude double precision,
    position_altitude_meters double precision,
    status varchar(32) not null,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    constraint chk_messaging_messages_status
        check (status in ('active', 'deleted')),
    constraint chk_messaging_messages_media_json
        check (jsonb_typeof(media_ids) = 'array'),
    constraint chk_messaging_messages_position_pair
        check ((position_latitude is null and position_longitude is null)
            or (position_latitude is not null
                and position_longitude is not null
                and position_latitude between -90 and 90
                and position_longitude between -180 and 180)),
    constraint chk_messaging_messages_updated_after_created
        check (updated_at >= created_at)
);

create index idx_messaging_messages_thread_created
    on messaging_messages (thread_id, created_at);

create index idx_messaging_messages_sender
    on messaging_messages (sender_id, created_at desc);

create table messaging_read_receipts (
    thread_id varchar(80) not null references messaging_threads(thread_id) on delete cascade,
    user_id varchar(120) not null,
    last_read_at timestamptz not null,
    primary key (thread_id, user_id)
);

create table messaging_mutes (
    thread_id varchar(80) not null references messaging_threads(thread_id) on delete cascade,
    user_id varchar(120) not null,
    muted boolean not null,
    updated_at timestamptz not null,
    primary key (thread_id, user_id)
);

create table messaging_activity (
    activity_id varchar(80) primary key,
    thread_id varchar(80) not null references messaging_threads(thread_id) on delete cascade,
    actor_user_id varchar(120) not null,
    activity_type varchar(64) not null,
    target_id varchar(160) not null default '',
    detail text not null default '',
    created_at timestamptz not null,
    constraint chk_messaging_activity_type
        check (activity_type in ('thread_created', 'message_sent', 'message_deleted', 'read', 'muted', 'unmuted'))
);

create index idx_messaging_activity_thread_created
    on messaging_activity (thread_id, created_at desc);
