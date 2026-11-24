-- Durable, ordered change feed for consumers that invalidate spatial assessments.
-- Inserted atomically with the restriction mutation and monotonic revision increment.
CREATE TABLE spatial_policy_change_outbox (
    policy_revision BIGINT PRIMARY KEY CHECK (policy_revision > 0),
    event_id VARCHAR(96) NOT NULL UNIQUE,
    event_type VARCHAR(96) NOT NULL CHECK (event_type = 'spatial.policy.changed'),
    event_version SMALLINT NOT NULL CHECK (event_version = 1),
    restriction_id VARCHAR(160) NOT NULL,
    restriction_version INTEGER NOT NULL CHECK (restriction_version > 0),
    action VARCHAR(16) NOT NULL CHECK (action IN ('CREATED', 'UPDATED', 'REVOKED')),
    jurisdiction VARCHAR(160) NOT NULL,
    outcome VARCHAR(32) NOT NULL CHECK (outcome IN (
        'ALLOWED', 'CAUTION', 'RESTRICTED', 'PROHIBITED', 'EMERGENCY_LOCKDOWN'
    )),
    activities TEXT[] NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

