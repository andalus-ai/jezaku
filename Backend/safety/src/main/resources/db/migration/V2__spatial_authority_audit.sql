CREATE TABLE spatial_authority_audit (
    event_id VARCHAR(160) PRIMARY KEY,
    principal_id VARCHAR(160) NOT NULL,
    action VARCHAR(32) NOT NULL CHECK (action IN ('CREATED', 'UPDATED')),
    actor_id VARCHAR(160) NOT NULL,
    snapshot_json JSONB NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_spatial_authority_audit_history
    ON spatial_authority_audit (principal_id, occurred_at DESC);
