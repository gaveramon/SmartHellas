-- =====================================================
-- 004. DEVICE CATEGORY SEED
-- =====================================================

insert into public.device_categories
(
    code,
    name,
    is_gateway,
    is_lock,
    sort_order
)
values
    (
        'sensor',
        'Sensor',
        false,
        false,
        10
    ),
    (
        'switch',
        'Switch',
        false,
        false,
        20
    ),
    (
        'lock',
        'Lock',
        false,
        true,
        30
    ),
    (
        'thermostat',
        'Thermostat',
        false,
        false,
        40
    ),
    (
        'ir_controller',
        'IR Controller',
        false,
        false,
        50
    ),
    (
        'gateway',
        'Gateway',
        true,
        false,
        60
    ),
    (
        'other',
        'Other',
        false,
        false,
        99
    )

on conflict (code)
do update set
    name = excluded.name,
    is_gateway = excluded.is_gateway,
    is_lock = excluded.is_lock,
    sort_order = excluded.sort_order;



-- =====================================================
-- 007. PROVIDER AND CAPABILITY SEED DATA
-- =====================================================

insert into public.integration_providers (
    code,
    name,
    category,
    valid_from,
    supports_webhooks,
    supports_oauth
)
values
    ('aqara', 'Aqara', 'smarthome', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('ttlock', 'TTLock', 'lock', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('shelly', 'Shelly', 'smarthome', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('beds24', 'Beds24', 'pms', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('stripe', 'Stripe', 'payment', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('vivawallet', 'Viva Wallet', 'payment', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('zoho', 'Zoho', 'crm', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('home_assistant', 'Home Assistant', 'smarthome', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('generic', 'Generic', 'smarthome', '2026-01-01 00:00:00+00'::timestamptz, false, false),
    ('airbnb', 'Airbnb', 'ota', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('booking', 'Booking.com', 'ota', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('expedia', 'Expedia', 'ota', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('pricelabs', 'PriceLabs', 'pricing', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('hostaway', 'Hostaway', 'pms', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('guesty', 'Guesty', 'pms', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('smoobu', 'Smoobu', 'pms', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('mailgun', 'Mailgun', 'email', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('postmark', 'Postmark', 'email', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('smtp', 'SMTP', 'email', '2026-01-01 00:00:00+00'::timestamptz, false, false),
    ('twilio', 'Twilio', 'sms', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('whatsapp', 'WhatsApp', 'messaging', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('firebase', 'Firebase', 'notification', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('openai', 'OpenAI', 'ai', '2026-01-01 00:00:00+00'::timestamptz, false, false),
    ('openrouter', 'OpenRouter', 'ai', '2026-01-01 00:00:00+00'::timestamptz, false, false),
    ('anthropic', 'Anthropic', 'ai', '2026-01-01 00:00:00+00'::timestamptz, false, false)
on conflict (code)
do update set
    name = excluded.name,
    category = excluded.category,
    supports_webhooks = excluded.supports_webhooks,
    supports_oauth = excluded.supports_oauth,
    valid_from = excluded.valid_from,
    updated_at = now();



insert into public.integration_capabilities (
    provider_code,
    capability_code,
    is_supported
)
values
    ('aqara', 'send_command', true),
    ('aqara', 'receive_event', true),
    ('ttlock', 'send_command', true),
    ('ttlock', 'receive_event', true),
    ('ttlock', 'create_user', true),
    ('shelly', 'receive_event', true),
    ('beds24', 'sync_state', true),
    ('stripe', 'receive_event', true),
    ('zoho', 'send_command', true),
    ('home_assistant', 'sync_state', true),
    ('generic', 'send_command', true)
on conflict (provider_code, capability_code)
do nothing;


-- =====================================================
-- INTEGRATION WEBHOOK MAPPINGS SEED
-- =====================================================

insert into public.integration_webhook_mappings (
    provider_code,
    event_type,
    mapping_code,
    value_path,
    value_type,
    is_active
)
values
    -- Aqara
    ('aqara', 'device.status', 'provider_event_id', '<PROVIDER_EVENT_ID_PATH>', 'text', true),
    ('aqara', 'device.status', 'device_external_id', '<DEVICE_EXTERNAL_ID_PATH>', 'text', true),
    ('aqara', 'device.status', 'observed_at', '<OBSERVED_AT_PATH>', 'epoch_milliseconds', true),

    -- TTLock
    ('ttlock', 'device.status', 'provider_event_id', '<PROVIDER_EVENT_ID_PATH>', 'text', true),
    ('ttlock', 'device.status', 'device_external_id', '<DEVICE_EXTERNAL_ID_PATH>', 'text', true),
    ('ttlock', 'device.status', 'observed_at', '<OBSERVED_AT_PATH>', 'epoch_milliseconds', true),

    -- Shelly
    ('shelly', 'device.status', 'provider_event_id', '<PROVIDER_EVENT_ID_PATH>', 'text', true),
    ('shelly', 'device.status', 'device_external_id', '<DEVICE_EXTERNAL_ID_PATH>', 'text', true),
    ('shelly', 'device.status', 'observed_at', '<OBSERVED_AT_PATH>', 'epoch_milliseconds', true)
on conflict do nothing;

-- =====================================================
-- INTEGRATION OAUTH CONFIGURATION SEED
-- =====================================================

insert into public.integration_oauth_configs (
    provider_code,
    authorization_url,
    token_url,
    scopes,
    use_pkce,
    is_active
)
values
    (
        'aqara',
        '<AQARA_AUTHORIZATION_URL>',
        '<AQARA_TOKEN_URL>',
        '<AQARA_SCOPES>',
        true,
        true
    ),
    (
        'ttlock',
        '<TTLOCK_AUTHORIZATION_URL>',
        '<TTLOCK_TOKEN_URL>',
        '<TTLOCK_SCOPES>',
        true,
        true
    )
on conflict do nothing;