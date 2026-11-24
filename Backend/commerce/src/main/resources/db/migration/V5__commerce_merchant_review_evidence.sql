-- A review case is independent of store-placement verification and merchant membership.
CREATE TABLE commerce_merchant_review_case (
    id VARCHAR(64) PRIMARY KEY,
    merchant_id VARCHAR(64) NOT NULL REFERENCES commerce_merchant(id),
    status VARCHAR(24) NOT NULL CHECK (status IN
        ('OPEN','IN_REVIEW','NEEDS_INFORMATION','APPROVED','REJECTED','CLOSED')),
    assigned_reviewer_user_id VARCHAR(128),
    opened_by VARCHAR(128) NOT NULL,
    opened_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    closed_at TIMESTAMPTZ,
    version BIGINT NOT NULL DEFAULT 0 CHECK (version >= 0),
    CHECK (updated_at >= opened_at),
    CHECK (
        (status IN ('APPROVED','REJECTED','CLOSED') AND closed_at IS NOT NULL AND closed_at <= updated_at)
        OR (status IN ('OPEN','IN_REVIEW','NEEDS_INFORMATION') AND closed_at IS NULL)
    ),
    CHECK (status <> 'IN_REVIEW' OR assigned_reviewer_user_id IS NOT NULL)
);

CREATE UNIQUE INDEX uq_commerce_active_review_case
    ON commerce_merchant_review_case(merchant_id)
    WHERE status IN ('OPEN','IN_REVIEW','NEEDS_INFORMATION');

CREATE INDEX idx_commerce_review_case_queue
    ON commerce_merchant_review_case(status, assigned_reviewer_user_id, opened_at);

CREATE TABLE commerce_merchant_evidence (
    id VARCHAR(64) PRIMARY KEY,
    review_case_id VARCHAR(64) NOT NULL REFERENCES commerce_merchant_review_case(id),
    merchant_id VARCHAR(64) NOT NULL REFERENCES commerce_merchant(id),
    media_asset_id VARCHAR(128) NOT NULL,
    category VARCHAR(32) NOT NULL CHECK (category IN
        ('BUSINESS_REGISTRATION','TAX_REGISTRATION','IDENTITY','ADDRESS_PROOF','AUTHORIZATION','OTHER')),
    status VARCHAR(16) NOT NULL CHECK (status IN ('RECEIVED','ACCEPTED','REJECTED','WITHDRAWN')),
    submitted_by VARCHAR(128) NOT NULL,
    submitted_at TIMESTAMPTZ NOT NULL,
    reviewed_by VARCHAR(128),
    reviewed_at TIMESTAMPTZ,
    reason_code VARCHAR(80),
    version BIGINT NOT NULL DEFAULT 0 CHECK (version >= 0),
    UNIQUE (review_case_id, media_asset_id),
    CHECK (
        (status IN ('ACCEPTED','REJECTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
        OR (status IN ('RECEIVED','WITHDRAWN') AND reviewed_by IS NULL AND reviewed_at IS NULL)
    ),
    CHECK (reviewed_at IS NULL OR reviewed_at >= submitted_at),
    CHECK ((status = 'REJECTED' AND reason_code IS NOT NULL)
        OR (status <> 'REJECTED' AND reason_code IS NULL))
);

CREATE INDEX idx_commerce_evidence_case
    ON commerce_merchant_evidence(review_case_id, submitted_at);

-- Append-only decision history; evidence_snapshot records the exact evidence versions
-- considered for each decision, not document contents.
CREATE TABLE commerce_merchant_review_decision (
    id BIGSERIAL PRIMARY KEY,
    review_case_id VARCHAR(64) NOT NULL REFERENCES commerce_merchant_review_case(id),
    merchant_id VARCHAR(64) NOT NULL REFERENCES commerce_merchant(id),
    reviewer_user_id VARCHAR(128) NOT NULL,
    decision VARCHAR(24) NOT NULL CHECK (decision IN ('APPROVED','REJECTED','NEEDS_INFORMATION','CLOSED')),
    reason_code VARCHAR(80) NOT NULL,
    case_version BIGINT NOT NULL CHECK (case_version >= 0),
    evidence_snapshot JSONB NOT NULL DEFAULT '[]'::jsonb,
    decided_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_commerce_review_decision_history
    ON commerce_merchant_review_decision(review_case_id, decided_at DESC);
