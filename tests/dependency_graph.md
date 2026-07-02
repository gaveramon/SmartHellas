# SmartHellas Database Dependency Graph

Generated from live FK introspection plus trigger-enforced edges in migrations `000`–`015`.

## Seed Insert Order

1. **000** — `auth.users` → `platform.profiles`
2. **002** — `tenants` → `tenant_memberships`
3. **009** — `product_plans` → `plan_pricing`, `feature_entitlements` → `subscriptions`
4. **005** — `integration_providers` (pre-seeded) → `tenant_integrations`
5. **003** — `properties` → `rooms` → `devices` (gateway, then lock) → `device_integration_map` → `device_assignments`
6. **004** — `property_access_schedules` → `bookings` → `booking_access` → `lock_devices` → `access_credentials`
7. **007/011** — `device_bundles` → `bundle_devices` → `onboarding_blueprints` → `onboarding_blueprint_steps` → `preconfig_templates` → `onboarding_sessions` → `onboarding_step_state`
8. **008** — `shipping_carriers` → `warehouses` → `logistics_templates` → `package_definitions` → `fulfilment_orders`
9. **006** — `operation_templates` → `operation_workflows` → `workflow_steps` / `workflow_triggers` → `support_tickets` → `support_messages`
10. **013** — `monetization_packages` → `customer_proposals` → `proposal_items`
11. **010** — `tenant_portal_settings`, `dashboard_configs`
12. **015** — `crm_pipelines` → `crm_pipeline_stages` → contacts/companies/leads → `crm_opportunities`
13. **012** — `optimization_rules`, `insight_events`
14. **014** — `platform.payment_intents`, `service_activation_state` sync

## Trigger-Enforced Dependencies

| Table | Function | Rule |
|-------|----------|------|
| bookings | enforce_booking_tenant_consistency | tenant_id = property.tenant_id |
| device_assignments | enforce_device_assignment_tenant_consistency | device tenant = room property tenant |
| devices | enforce_device_hierarchy | child lock/sensor requires gateway parent |
| lock_devices | enforce_lock_device_integrity | is_lock category + device_integration_map |
| access_credentials | enforce_access_credential_integrity | booking/lock/map alignment |
| subscriptions | enforce_subscription_plan_required | active status requires plan_id |
| subscriptions | sync_subscription_tier_from_plan | tier from product_plans |
| fulfilment_orders | enforce_fulfilment_order_integrity | property/bundle/carrier/warehouse scope |
| support_tickets | enforce_support_ticket_user_membership | user is active member |
| crm_* | enforce_crm_* | owner_user_id membership; pipeline/stage tenant match |
| payment_intents | enforce_payment_intent_target_tenant | target belongs to tenant |
| tenant_memberships | enforce_tenant_owner_invariant | cannot remove last owner |

## FK Roots

- `public.tenants`
- `public.integration_providers`
- `public.device_categories`
- Catalog tables: `product_plans`, `device_bundles`, `onboarding_blueprints`, `shipping_carriers`

## Run Tests

```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 -f tests/integration_tests.sql
```

Fixtures use deterministic UUIDs in `tests.fixture_registry` and marker `__integration_test__`.
