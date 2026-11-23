-- One global monotonic revision for every committed spatial restriction mutation.
-- The row is updated in the same transaction as the restriction and audit event.
CREATE TABLE spatial_policy_state (
    state_key VARCHAR(32) PRIMARY KEY CHECK (state_key = 'GLOBAL'),
    revision BIGINT NOT NULL CHECK (revision >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO spatial_policy_state (state_key, revision)
VALUES ('GLOBAL', 0);
