CREATE TABLE commerce_merchant (
    id VARCHAR(64) PRIMARY KEY,
    legal_name VARCHAR(240) NOT NULL,
    display_name VARCHAR(160) NOT NULL,
    jurisdiction VARCHAR(16) NOT NULL,
    status VARCHAR(32) NOT NULL CHECK (status IN ('PENDING_VERIFICATION','VERIFIED','SUSPENDED','REJECTED')),
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    version BIGINT NOT NULL DEFAULT 0 CHECK (version >= 0),
    CHECK (updated_at >= created_at)
);

CREATE INDEX idx_commerce_merchant_status ON commerce_merchant(status);

CREATE TABLE commerce_merchant_membership (
    id VARCHAR(64) PRIMARY KEY,
    merchant_id VARCHAR(64) NOT NULL REFERENCES commerce_merchant(id),
    user_id VARCHAR(128) NOT NULL,
    role VARCHAR(32) NOT NULL CHECK (role IN ('OWNER','ADMIN','STORE_MANAGER','ANALYST')),
    status VARCHAR(16) NOT NULL CHECK (status IN ('ACTIVE','INVITED','REVOKED')),
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    version BIGINT NOT NULL DEFAULT 0 CHECK (version >= 0),
    UNIQUE (merchant_id, user_id),
    CHECK (updated_at >= created_at)
);

CREATE INDEX idx_commerce_membership_user ON commerce_merchant_membership(user_id, status);

CREATE TABLE commerce_store (
    id VARCHAR(64) PRIMARY KEY,
    merchant_id VARCHAR(64) NOT NULL REFERENCES commerce_merchant(id),
    name VARCHAR(160) NOT NULL,
    time_zone VARCHAR(80) NOT NULL,
    status VARCHAR(16) NOT NULL CHECK (status IN ('DRAFT','ACTIVE','SUSPENDED','CLOSED')),
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    version BIGINT NOT NULL DEFAULT 0 CHECK (version >= 0),
    CHECK (updated_at >= created_at)
);

CREATE INDEX idx_commerce_store_merchant ON commerce_store(merchant_id, status);

CREATE TABLE commerce_store_placement (
    store_id VARCHAR(64) PRIMARY KEY REFERENCES commerce_store(id),
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    horizontal_accuracy_meters DOUBLE PRECISION NOT NULL CHECK (horizontal_accuracy_meters > 0),
    source VARCHAR(120) NOT NULL,
    status VARCHAR(16) NOT NULL CHECK (status IN ('PROPOSED','VERIFIED','REJECTED','REVOKED')),
    verified_by VARCHAR(128),
    verified_at TIMESTAMPTZ,
    revision BIGINT NOT NULL DEFAULT 0 CHECK (revision >= 0),
    CHECK ((status = 'VERIFIED' AND verified_by IS NOT NULL AND verified_at IS NOT NULL)
        OR (status <> 'VERIFIED' AND verified_by IS NULL AND verified_at IS NULL))
);

CREATE INDEX idx_commerce_store_placement_geo
    ON commerce_store_placement(latitude, longitude)
    WHERE status = 'VERIFIED';

CREATE TABLE commerce_audit_event (
    id BIGSERIAL PRIMARY KEY,
    aggregate_type VARCHAR(32) NOT NULL CHECK (aggregate_type IN ('MERCHANT','STORE','PLACEMENT','MEMBERSHIP')),
    aggregate_id VARCHAR(64) NOT NULL,
    merchant_id VARCHAR(64),
    actor_id VARCHAR(128) NOT NULL,
    action VARCHAR(64) NOT NULL,
    previous_version BIGINT,
    new_version BIGINT,
    occurred_at TIMESTAMPTZ NOT NULL,
    reason_code VARCHAR(80),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX idx_commerce_audit_aggregate
    ON commerce_audit_event(aggregate_type, aggregate_id, occurred_at DESC);
CREATE INDEX idx_commerce_audit_merchant
    ON commerce_audit_event(merchant_id, occurred_at DESC);
