ALTER TABLE commerce_merchant_membership
    ADD COLUMN invited_by VARCHAR(128),
    ADD COLUMN invitation_expires_at TIMESTAMPTZ,
    ADD COLUMN activated_at TIMESTAMPTZ;

UPDATE commerce_merchant_membership
SET activated_at = updated_at
WHERE status = 'ACTIVE';

UPDATE commerce_merchant_membership
SET invited_by = 'system:migration',
    invitation_expires_at = created_at + INTERVAL '7 days'
WHERE status = 'INVITED';

ALTER TABLE commerce_merchant_membership
    ADD CONSTRAINT ck_commerce_membership_lifecycle
    CHECK (
        (status = 'INVITED' AND invitation_expires_at IS NOT NULL
            AND invited_by IS NOT NULL AND activated_at IS NULL)
        OR
        (status = 'ACTIVE' AND invitation_expires_at IS NULL AND activated_at IS NOT NULL)
        OR
        (status = 'REVOKED' AND invitation_expires_at IS NULL)
    );

ALTER TABLE commerce_merchant_membership
    ADD CONSTRAINT ck_commerce_owner_active
    CHECK (role <> 'OWNER' OR status = 'ACTIVE');

CREATE INDEX idx_commerce_membership_invitation_expiry
    ON commerce_merchant_membership(invitation_expires_at)
    WHERE status = 'INVITED';
