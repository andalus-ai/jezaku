-- Reviewer grants are provisioned by trusted operators outside the merchant-facing API.
-- Runtime services receive SELECT access only; merchant owners cannot grant themselves review powers.
CREATE TABLE commerce_merchant_reviewer (
    user_id VARCHAR(128) PRIMARY KEY,
    status VARCHAR(16) NOT NULL CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED')),
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CHECK (valid_until IS NULL OR valid_until > valid_from),
    CHECK (updated_at >= created_at)
);

CREATE TABLE commerce_merchant_reviewer_scope (
    user_id VARCHAR(128) NOT NULL REFERENCES commerce_merchant_reviewer(user_id),
    jurisdiction VARCHAR(16) NOT NULL,
    PRIMARY KEY (user_id, jurisdiction)
);

CREATE TABLE commerce_merchant_reviewer_permission (
    user_id VARCHAR(128) NOT NULL REFERENCES commerce_merchant_reviewer(user_id),
    permission VARCHAR(16) NOT NULL CHECK (permission IN ('VERIFY','REJECT','SUSPEND','REINSTATE')),
    PRIMARY KEY (user_id, permission)
);

CREATE INDEX idx_commerce_reviewer_scope_jurisdiction
    ON commerce_merchant_reviewer_scope(jurisdiction, user_id);
