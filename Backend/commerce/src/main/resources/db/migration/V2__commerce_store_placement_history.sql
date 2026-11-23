-- Preserve every authoritative store-placement revision, including the provenance
-- needed to explain how a location entered or left public use.
CREATE TABLE commerce_store_placement_revision (
    store_id VARCHAR(64) NOT NULL REFERENCES commerce_store(id),
    revision BIGINT NOT NULL CHECK (revision >= 0),
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    horizontal_accuracy_meters DOUBLE PRECISION NOT NULL CHECK (horizontal_accuracy_meters > 0),
    source VARCHAR(120) NOT NULL,
    status VARCHAR(16) NOT NULL CHECK (status IN ('PROPOSED','VERIFIED','REJECTED','REVOKED')),
    verified_by VARCHAR(128),
    verified_at TIMESTAMPTZ,
    action VARCHAR(64) NOT NULL,
    recorded_by VARCHAR(128) NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL,
    reason_code VARCHAR(80),
    PRIMARY KEY (store_id, revision),
    CHECK ((status = 'VERIFIED' AND verified_by IS NOT NULL AND verified_at IS NOT NULL)
        OR (status <> 'VERIFIED' AND verified_by IS NULL AND verified_at IS NULL))
);

CREATE INDEX idx_commerce_placement_revision_recorded
    ON commerce_store_placement_revision(store_id, recorded_at DESC);

-- Backfill the current snapshot so every existing store starts with a history row.
INSERT INTO commerce_store_placement_revision (
    store_id, revision, latitude, longitude, horizontal_accuracy_meters, source,
    status, verified_by, verified_at, action, recorded_by, recorded_at, reason_code
)
SELECT p.store_id, p.revision, p.latitude, p.longitude, p.horizontal_accuracy_meters, p.source,
       p.status, p.verified_by, p.verified_at, 'BASELINE', 'system:migration',
       COALESCE((SELECT MAX(a.occurred_at)
                 FROM commerce_audit_event a
                 WHERE a.aggregate_type = 'PLACEMENT' AND a.aggregate_id = p.store_id),
                CURRENT_TIMESTAMP),
       'MIGRATION_BASELINE'
FROM commerce_store_placement p;
