CREATE TABLE spatial_authority (
    principal_id VARCHAR(160) PRIMARY KEY,
    issuer_type VARCHAR(64) NOT NULL,
    status VARCHAR(24) NOT NULL CHECK (status IN ('PENDING', 'VERIFIED', 'SUSPENDED', 'REVOKED')),
    valid_from TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (expires_at IS NULL OR expires_at > valid_from)
);

CREATE TABLE spatial_authority_scope (
    principal_id VARCHAR(160) NOT NULL REFERENCES spatial_authority(principal_id) ON DELETE CASCADE,
    jurisdiction_code VARCHAR(160) NOT NULL,
    include_descendants BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (principal_id, jurisdiction_code)
);

CREATE TABLE spatial_authority_permission (
    principal_id VARCHAR(160) NOT NULL REFERENCES spatial_authority(principal_id) ON DELETE CASCADE,
    permission VARCHAR(64) NOT NULL CHECK (permission IN (
        'CREATE_RESTRICTION', 'UPDATE_RESTRICTION', 'REVOKE_RESTRICTION', 'ISSUE_EMERGENCY_LOCKDOWN'
    )),
    PRIMARY KEY (principal_id, permission)
);

CREATE TABLE spatial_restriction (
    restriction_id VARCHAR(160) PRIMARY KEY,
    version INTEGER NOT NULL CHECK (version > 0),
    issuer_type VARCHAR(64) NOT NULL,
    issuer_id VARCHAR(160) NOT NULL REFERENCES spatial_authority(principal_id),
    jurisdiction VARCHAR(160) NOT NULL,
    legal_basis TEXT NOT NULL DEFAULT '',
    center_latitude DOUBLE PRECISION NOT NULL CHECK (center_latitude BETWEEN -90 AND 90),
    center_longitude DOUBLE PRECISION NOT NULL CHECK (center_longitude BETWEEN -180 AND 180),
    radius_meters DOUBLE PRECISION NOT NULL CHECK (radius_meters > 0 AND radius_meters < 'Infinity'::DOUBLE PRECISION),
    outcome VARCHAR(32) NOT NULL CHECK (outcome IN (
        'ALLOWED', 'CAUTION', 'RESTRICTED', 'PROHIBITED', 'EMERGENCY_LOCKDOWN'
    )),
    effective_from TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (expires_at IS NULL OR expires_at > effective_from)
);

CREATE TABLE spatial_restriction_activity (
    restriction_id VARCHAR(160) NOT NULL REFERENCES spatial_restriction(restriction_id) ON DELETE CASCADE,
    activity VARCHAR(32) NOT NULL CHECK (activity IN (
        'ALL', 'PUBLISH', 'DISCOVER', 'RENDER', 'NAVIGATE', 'REDEEM', 'INTERACT'
    )),
    PRIMARY KEY (restriction_id, activity)
);

CREATE INDEX idx_spatial_restriction_active_window
    ON spatial_restriction (active, effective_from, expires_at);
CREATE INDEX idx_spatial_restriction_jurisdiction
    ON spatial_restriction (jurisdiction);
CREATE INDEX idx_spatial_restriction_issuer
    ON spatial_restriction (issuer_id);

CREATE TABLE spatial_restriction_audit (
    event_id VARCHAR(160) PRIMARY KEY,
    restriction_id VARCHAR(160) NOT NULL,
    restriction_version INTEGER NOT NULL,
    action VARCHAR(32) NOT NULL CHECK (action IN ('CREATED', 'UPDATED', 'REVOKED')),
    actor_id VARCHAR(160) NOT NULL,
    reason TEXT NOT NULL DEFAULT '',
    snapshot_json JSONB NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_spatial_restriction_audit_history
    ON spatial_restriction_audit (restriction_id, occurred_at DESC);
