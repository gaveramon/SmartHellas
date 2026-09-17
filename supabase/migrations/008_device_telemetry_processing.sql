-- =====================================================
-- 7B. DEVICE TELEMETRY PROCESSING
-- =====================================================
-- TODO


-- =====================================================
-- 1. SCHEMA MIGRATION REGISTRATION
-- =====================================================

insert into platform.schema_migrations (
    migration_name,
    version,
    rollback_available
)
values (
    '007_b_device_telemetry_processing',
    'REV22.DEVICE.TELEMETRY.PROCESSING\\',
    false
)
on conflict (version) do nothing;


commit;


-- =====================================================
-- END 007a DEVICE TELEMETRY
--