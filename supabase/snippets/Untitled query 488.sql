insert into access_credentials (
    id,
    tenant_id,
    booking_id,
    lock_device_id,
    provider_code,
    credential_ref,
    status,
    valid_from,
    valid_until
)
values (
    '22222222-2222-2222-2222-222222222222',
    '99999999-9999-9999-9999-999999999999',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    'ttlock',
    'TEST-CODE-001',
    'pending',
    now(),
    now() + interval '7 days'
);
