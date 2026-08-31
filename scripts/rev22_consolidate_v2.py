#!/usr/bin/env python3
"""REV22 deterministic consolidator v2 — explicit source composition."""
from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "supabase" / "migrations_archive_rev19"
OUT = ROOT / "supabase" / "migrations"

GRANT_LINE = re.compile(
    r"^\s*(grant\s+execute|revoke\s+.*\bon\s+function|grant\s+select\s+on\s+(?:public\.)?v_)",
    re.I,
)
SCHEMA_MIG = re.compile(r"^\s*insert\s+into\s+platform\.schema_migrations", re.I)

OUT_FILES = [
    "000_supabase_platform.sql",
    "001_core_types.sql",
    "002_core_saas.sql",
    "003_property_device_engine.sql",
    "004_booking_lock_engine.sql",
    "005_integration_engine.sql",
    "006_operations_engine.sql",
    "007_preconfig_engine.sql",
    "008_logistics_engine.sql",
    "009_commerce_engine.sql",
    "010_service_portal_engine.sql",
    "011_onboarding_engine.sql",
    "012_optimization_engine.sql",
    "013_customer_proposal_monetization.sql",
    "014_platform_bootstrap.sql",
    "015_crm_engine.sql",
    "016_automation_engine.sql",
    "017_edge_rpc_foundation.sql",
    "018_security_hardening.sql",
    "019_grant_matrix.sql",
    "020_production_finalize.sql",
]

# Sources applied IN ORDER (later overrides earlier for same function name)
COMPOSITION: dict[str, list[str]] = {
    "000_supabase_platform.sql": [
        "000_supabase_platform_rev19.sql",
        "028_platform_views_extensions_rev19.sql",
        "032_edge_platform_extensions_rev19.sql",
        "037_platform_webhook_processing_rev19.sql",
        "039_edge_stabilization_routing_rev19.sql",
        "045_integrations_oauth_security_rev19.sql",
        "047_platform_security_rev19.sql",
    ],
    "001_core_types.sql": [
        "001_core_types_rev19.sql",
    ],
    "002_core_saas.sql": [
        "002_core_saas_rev19.sql",
        "031_core_saas_auth_extensions_rev19.sql",
        "033_auth_integrations_extensions_rev19.sql",
        "041_core_saas_tenant_switch_rev19.sql",
        "042_core_saas_auth_security_rev19.sql",
        "047_platform_security_rev19.sql",
        "049_production_audit_fixes_rev19.sql",
        "051_rev21_tenant_authority_core.sql",
        "053_rev21_tenant_context.sql",
    ],
    "003_property_device_engine.sql": [
        "003_property_device_engine_rev19.sql",
        "018_devices_extensions_rev19.sql",
        "043_devices_security_rev19.sql",
        "025_foundation_rpcs_views_rev19.sql",
    ],
    "004_booking_lock_engine.sql": [
        "004_booking_lock_engine_rev19.sql",
        "019_booking_locks_extensions_rev19.sql",
        "036_booking_access_window_rev19.sql",
        "047_platform_security_rev19.sql",
        "049_production_audit_fixes_rev19.sql",
        "025_foundation_rpcs_views_rev19.sql",
    ],
    "005_integration_engine.sql": [
        "005_integration_engine_rev19.sql",
        "032_edge_platform_extensions_rev19.sql",
        "033_auth_integrations_extensions_rev19.sql",
        "040_integrations_oauth_start_rev19.sql",
        "045_integrations_oauth_security_rev19.sql",
        "048_production_security_fixes_rev19.sql",
        "052_rev21_tenant_access_control.sql",
    ],
    "006_operations_engine.sql": [
        "006_operations_engine_rev19.sql",
        "021_module_extensions_rev19.sql",
        "034_operations_notifications_rev19.sql",
    ],
    "007_preconfig_engine.sql": [
        "007_preconfig_engine_rev19.sql",
        "021_module_extensions_rev19.sql",
    ],
    "008_logistics_engine.sql": [
        "008_logistics_engine_rev19.sql",
        "020_commerce_logistics_extensions_rev19.sql",
        "044_logistics_security_rev19.sql",
    ],
    "009_commerce_engine.sql": [
        "009_commerce_engine_rev19.sql",
        "020_commerce_logistics_extensions_rev19.sql",
        "035_commerce_payment_api_rev19.sql",
        "025_foundation_rpcs_views_rev19.sql",
    ],
    # 025 views only via PICK_FROM_025; 035 domain via PICK_FROM_035
    "010_service_portal_engine.sql": [
        "010_service_portal_engine_rev19.sql",
        "021_module_extensions_rev19.sql",
    ],
    "011_onboarding_engine.sql": [
        "011_onboarding_engine_rev19.sql",
        "021_module_extensions_rev19.sql",
        "026_onboarding_lifecycle_extensions_rev19.sql",
        "025_foundation_rpcs_views_rev19.sql",
    ],
    "012_optimization_engine.sql": [
        "012_optimization_engine_rev19.sql",
        "021_module_extensions_rev19.sql",
    ],
    "013_customer_proposal_monetization.sql": [
        "013_customer_proposal_monetization_rev19.sql",
        "021_module_extensions_rev19.sql",
        "020_commerce_logistics_extensions_rev19.sql",
    ],
    "014_platform_bootstrap.sql": [
        "014_platform_bootstrap_finale_rev19.sql",
    ],
    "015_crm_engine.sql": [
        "015_crm_engine_rev19.sql",
        "022_crm_extensions_rev19.sql",
        "047_platform_security_rev19.sql",
        "025_foundation_rpcs_views_rev19.sql",
    ],
    "016_automation_engine.sql": [
        "016_automation_engine_rev19.sql",
        "027_automation_extensions_rev19.sql",
    ],
    "017_edge_rpc_foundation.sql": [
        "017_edge_rpc_foundation_rev19.sql",
        "023_edge_api_thin_wrappers_rev19.sql",
        "024_edge_foundation_thin_rev19.sql",
        "025_foundation_rpcs_views_rev19.sql",
        "029_edge_automation_api_extensions_rev19.sql",
        "030_edge_onboarding_lifecycle_extensions_rev19.sql",
        "038_edge_api_architecture_completion_rev19.sql",
        "039_edge_stabilization_routing_rev19.sql",
        "040_integrations_oauth_start_rev19.sql",
        "046_edge_api_security_rev19.sql",
        "048_production_security_fixes_rev19.sql",
        "049_production_audit_fixes_rev19.sql",
        "052_rev21_tenant_access_control.sql",
        "034_operations_notifications_rev19.sql",
        "035_commerce_payment_api_rev19.sql",
        "050_rev20_baseline_consolidation.sql",
    ],
    "018_security_hardening.sql": [],
    "019_grant_matrix.sql": [],
    "020_production_finalize.sql": [],
}

# Functions to EXCLUDE from a target when pulling from a multi-domain source file
EXCLUDE_FROM: dict[tuple[str, str], set[str]] = {
    ("006_operations_engine.sql", "021_module_extensions_rev19.sql"): {
        "portal_domain", "onboarding_domain", "optimization_domain", "monetization_domain",
        "preconfig_domain", "integrations_complete_oauth",
    },
    ("009_commerce_engine.sql", "020_commerce_logistics_extensions_rev19.sql"): {
        "logistics_domain", "logistics_dispatch_fulfilment_order",
    },
    ("008_logistics_engine.sql", "020_commerce_logistics_extensions_rev19.sql"): {
        "commerce_domain", "commerce_change_subscription_plan", "commerce_create_subscription",
        "trg_customer_proposals_status_timestamps",
    },
    ("013_customer_proposal_monetization.sql", "020_commerce_logistics_extensions_rev19.sql"): {
        "commerce_domain", "logistics_domain", "commerce_change_subscription_plan",
        "commerce_create_subscription", "logistics_dispatch_fulfilment_order",
    },
    ("013_customer_proposal_monetization.sql", "021_module_extensions_rev19.sql"): {
        "portal_domain", "onboarding_domain", "optimization_domain", "operations_domain",
        "preconfig_domain", "integrations_complete_oauth",
    },
    ("002_core_saas.sql", "033_auth_integrations_extensions_rev19.sql"): {
        "integrations_domain_ext", "integrations_api", "auth_api",
    },
    ("002_core_saas.sql", "031_core_saas_auth_extensions_rev19.sql"): {
        "auth_api",
    },
    ("002_core_saas.sql", "050_rev20_baseline_consolidation.sql"): {
        "locks_api", "operations_api", "integrations_api",
    },
    ("005_integration_engine.sql", "033_auth_integrations_extensions_rev19.sql"): {
        "auth_domain_ext_031", "auth_domain_ext", "auth_api",
    },
    ("005_integration_engine.sql", "045_integrations_oauth_security_rev19.sql"): {
        "integrations_oauth_complete_api",
    },
    ("005_integration_engine.sql", "048_production_security_fixes_rev19.sql"): {
        "monetization_api",
    },
    ("005_integration_engine.sql", "052_rev21_tenant_access_control.sql"): {
        "edge_require_tenant", "has_tenant_access", "integrations_api",
    },
    ("017_edge_rpc_foundation.sql", "040_integrations_oauth_start_rev19.sql"): {
        "integrations_domain_ext",
    },
    ("017_edge_rpc_foundation.sql", "048_production_security_fixes_rev19.sql"): {
        "enforce_device_integration_consistency", "monetization_api",
    },
    ("000_supabase_platform.sql", "039_edge_stabilization_routing_rev19.sql"): {
        "auth_switch_tenant", "auth_invite_member", "integrations_oauth_complete_api",
        "auth_api", "integrations_api",
    },
    ("000_supabase_platform.sql", "045_integrations_oauth_security_rev19.sql"): {
        "integrations_oauth_complete_api", "integrations_domain",
    },
    ("000_supabase_platform.sql", "032_edge_platform_extensions_rev19.sql"): {
        "integration_oauth_states", "integrations_resolve_oauth_state",
        "integrations_complete_oauth", "integrations_oauth_complete",
    },
    ("000_supabase_platform.sql", "047_platform_security_rev19.sql"): {
        "crm_soft_delete_row", "auth_domain_ext", "access_credentials_select",
    },
    ("002_core_saas.sql", "047_platform_security_rev19.sql"): {
        "crm_soft_delete_row", "edge_soft_delete_row", "access_credentials_select",
    },
    ("004_booking_lock_engine.sql", "047_platform_security_rev19.sql"): {
        "crm_soft_delete_row", "edge_soft_delete_row", "auth_domain_ext",
    },
    ("015_crm_engine.sql", "047_platform_security_rev19.sql"): {
        "edge_soft_delete_row", "auth_domain_ext", "access_credentials_select",
    },
    ("049_production_audit_fixes_rev19.sql", ""): set(),
}

PICK_FROM_025: dict[str, set[str]] = {
    "003_property_device_engine.sql": {"v_properties_overview", "v_devices_overview"},
    "004_booking_lock_engine.sql": {"v_bookings_overview"},
    "009_commerce_engine.sql": {"v_subscription_overview"},
    "011_onboarding_engine.sql": {"v_onboarding_progress"},
    "015_crm_engine.sql": {"v_crm_pipeline"},
    "017_edge_rpc_foundation.sql": {
        "insert_event",
        "create_property",
        "assign_device",
        "generate_lock_code",
        "create_booking",
        "create_subscription",
        "log_event",
        "onboarding_step_update",
        "calculate_optimization_score",
        "generate_monetization_proposal",
    },
}

PICK_FROM_039: dict[str, set[str]] = {
    "000_supabase_platform.sql": {
        "process_integration_queue_batch",
        "process_device_command_batch",
        "process_retry_task_batch",
        "process_shipment_dispatch_batch",
        "process_notification_batch",
        "run_platform_cron_tick",
    },
    "017_edge_rpc_foundation.sql": {
        "auth_switch_tenant",
        "auth_invite_member",
        "integrations_oauth_complete_api",
        "auth_api",
        "integrations_api",
    },
}

PICK_FROM_045: dict[str, set[str]] = {
    "000_supabase_platform.sql": {
        "upsert_vault_secret",
        "sync_http_request",
        "integrations_exchange_oauth_tokens",
    },
    "005_integration_engine.sql": {"integrations_domain"},
    "017_edge_rpc_foundation.sql": {"integrations_oauth_complete_api"},
}

PICK_FROM_021: dict[str, set[str]] = {
    "006_operations_engine.sql": {"operations_domain"},
    "007_preconfig_engine.sql": {"preconfig_domain"},
    "010_service_portal_engine.sql": {"portal_domain"},
    "011_onboarding_engine.sql": {"onboarding_domain"},
    "012_optimization_engine.sql": {"optimization_domain"},
    "013_customer_proposal_monetization.sql": {"monetization_domain"},
}

PICK_FROM_020: dict[str, set[str]] = {
    "008_logistics_engine.sql": {"logistics_domain", "logistics_dispatch_fulfilment_order"},
    "009_commerce_engine.sql": {
        "commerce_domain", "commerce_change_subscription_plan", "commerce_create_subscription",
    },
    "013_customer_proposal_monetization.sql": {"trg_customer_proposals_status_timestamps"},
}

PICK_FROM_033: dict[str, set[str]] = {
    "002_core_saas.sql": {"auth_domain_ext_031", "auth_domain_ext"},
    "005_integration_engine.sql": {"integrations_domain_ext"},
}

PICK_FROM_047: dict[str, set[str]] = {
    "002_core_saas.sql": {"auth_domain_ext"},
    "015_crm_engine.sql": {"crm_soft_delete_row"},
    "000_supabase_platform.sql": {"edge_soft_delete_row"},
}

PICK_FROM_049: dict[str, set[str]] = {
    "002_core_saas.sql": {"auth_invite_member"},
    "004_booking_lock_engine.sql": {"booking_create_booking_access"},
    "017_edge_rpc_foundation.sql": {"monetization_api"},
}

PICK_FROM_050: dict[str, set[str]] = {
    "002_core_saas.sql": {"auth_domain"},
    "017_edge_rpc_foundation.sql": {"locks_api", "operations_api", "integrations_api"},
}

PICK_FROM_034: dict[str, set[str]] = {
    "017_edge_rpc_foundation.sql": {"notification_api"},
}

PICK_FROM_035: dict[str, set[str]] = {
    "009_commerce_engine.sql": {"payment_domain", "payment_transition_status"},
    "017_edge_rpc_foundation.sql": {"payment_api"},
}

PICK_FROM_052: dict[str, set[str]] = {
    "017_edge_rpc_foundation.sql": {"integrations_api", "edge_require_tenant"},
    "005_integration_engine.sql": {"integrations_resolve_oauth_state"},
}

PICK_SOURCES: dict[str, dict[str, set[str]]] = {
    "021_module_extensions_rev19.sql": PICK_FROM_021,
    "020_commerce_logistics_extensions_rev19.sql": PICK_FROM_020,
    "033_auth_integrations_extensions_rev19.sql": PICK_FROM_033,
    "047_platform_security_rev19.sql": PICK_FROM_047,
    "049_production_audit_fixes_rev19.sql": PICK_FROM_049,
    "050_rev20_baseline_consolidation.sql": PICK_FROM_050,
    "034_operations_notifications_rev19.sql": PICK_FROM_034,
    "035_commerce_payment_api_rev19.sql": PICK_FROM_035,
    "052_rev21_tenant_access_control.sql": PICK_FROM_052,
    "025_foundation_rpcs_views_rev19.sql": PICK_FROM_025,
    "039_edge_stabilization_routing_rev19.sql": PICK_FROM_039,
    "045_integrations_oauth_security_rev19.sql": PICK_FROM_045,
}

FUNC_BLOCK = re.compile(
    r"(create\s+(?:or\s+replace\s+)?function\s+(?:platform|public)\.(\w+))",
    re.I,
)


def strip_lines(text: str, drop_schema_mig: bool = True) -> tuple[str, list[str]]:
    grants: list[str] = []
    out: list[str] = []
    for line in text.splitlines():
        if GRANT_LINE.match(line):
            grants.append(line.strip())
            continue
        if drop_schema_mig and SCHEMA_MIG.match(line):
            continue
        out.append(line)
    return "\n".join(out), grants


def extract_view_blocks(text: str) -> dict[str, str]:
    """Return view_name -> full create view block."""
    blocks: dict[str, str] = {}
    pattern = re.compile(
        r"create\s+or\s+replace\s+view\s+public\.(\w+)",
        re.I,
    )
    pos = 0
    while True:
        m = pattern.search(text, pos)
        if not m:
            break
        name = m.group(1).lower()
        start = m.start()
        rest = text[m.start():]
        end_match = re.search(r";\s*(?:\n|$)", rest)
        if not end_match:
            break
        end = m.start() + end_match.end()
        block = text[start:end].strip()
        blocks[name] = block
        pos = end
    return blocks


def extract_function_blocks(text: str) -> dict[str, str]:
    """Return function_name -> full block (from create through trailing grants stripped)."""
    blocks: dict[str, str] = {}
    pattern = re.compile(
        r"create\s+(?:or\s+replace\s+)?function\s+(?:platform|public)\.(\w+)\s*\(",
        re.I,
    )
    pos = 0
    while True:
        m = pattern.search(text, pos)
        if not m:
            break
        name = m.group(1).lower()
        start = m.start()
        # find end: $$; after language body
        rest = text[m.start():]
        end_match = re.search(r"\$\$\s*;", rest, re.S)
        if not end_match:
            break
        end = m.start() + end_match.end()
        block = text[start:end]
        block, _ = strip_lines(block)
        blocks[name] = block.strip()
        pos = end
    return blocks


def extract_non_function_sql(text: str, exclude_funcs: set[str]) -> str:
    """Keep everything that isn't a function block matching exclude_funcs."""
    blocks = extract_function_blocks(text)
    result = text
    for name, block in blocks.items():
        if name in exclude_funcs:
            result = result.replace(block, "")
    result, _ = strip_lines(result)
    # remove empty migration headers-only chunks
    return result


def strip_grant_do_blocks(text: str) -> tuple[str, list[str]]:
    """Remove DO blocks that perform dynamic grant/revoke on functions."""
    extracted: list[str] = []
    pattern = re.compile(r"do\s+\$block\$.*?end;\s*\$block\$;", re.S | re.I)

    def repl(m: re.Match[str]) -> str:
        block = m.group(0)
        if "grant execute on function" in block.lower() or "revoke all on function" in block.lower():
            extracted.append(block.strip())
            return ""
        return block

    cleaned = pattern.sub(repl, text)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    return cleaned, extracted


def remove_superseded_platform_tenant_stubs(text: str) -> str:
    """000 must not retain tenant helpers superseded by 002/018."""
    blocks = extract_function_blocks(text)
    for fn in (
        "current_tenant_id",
        "current_role",
        "has_tenant_access",
        "is_owner",
        "is_admin",
        "is_support",
        "has_permission",
        "has_role",
    ):
        if fn in blocks:
            text = text.replace(blocks[fn], "")
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text


def read_source(name: str) -> str:
    p = ARCHIVE / name
    if not p.exists():
        return ""
    return p.read_text(encoding="utf-8")


def build_018() -> str:
    do_block = read_source("050_rev20_baseline_consolidation.sql")
    m = re.search(
        r"(-- =+\s*\n-- SECURITY DEFINER HARDENING.*?end;\s*\n\$block\$;)",
        do_block,
        re.S,
    )
    hardening = m.group(1) if m else ""
    return f"""-- REV22 greenfield baseline: 018_security_hardening.sql
-- Cross-cutting security only

-- RLS tenant access shims (052 final)
create or replace function platform.has_tenant_access(tid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select tid = public.resolve_active_tenant((select auth.uid()));
$$;

create or replace function public.has_tenant_access(p_public_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select p_public_tenant_id = public.resolve_active_tenant((select auth.uid()));
$$;

comment on function platform.has_tenant_access(uuid) is
    'RLS shim only. tid = resolve_active_tenant(auth.uid()). Not an authority surface.';

comment on function public.has_tenant_access(uuid) is
    'RLS shim only. p_public_tenant_id = resolve_active_tenant(auth.uid()). Not an authority surface.';

{hardening}
"""


def build_019(all_grants: list[str]) -> str:
    lines = sorted(set(all_grants))
    return (
        "-- REV22 greenfield baseline: 019_grant_matrix.sql\n"
        "-- SINGLE SSOT for EXECUTE and view grants\n\n"
        + "\n".join(lines)
        + "\n"
    )


def build_020() -> str:
    parts = [
        "-- REV22 greenfield baseline: 020_production_finalize.sql",
        "-- Verification and finalization only",
        "",
    ]
    for fname in OUT_FILES:
        name = fname.replace(".sql", "")
        ver = name.upper().replace("_", ".")
        parts.append(
            f"insert into platform.schema_migrations (migration_name, version, rollback_available)\n"
            f"values ('{name}', '{ver}', false)\n"
            f"on conflict (version) do nothing;\n"
        )
    parts.extend(
        [
            "",
            "select platform.ensure_pg_cron_jobs();",
            "",
            "do $$",
            "declare v_api int; v_domain int;",
            "begin",
            "  select count(*) into v_api from pg_proc p join pg_namespace n on n.oid = p.pronamespace",
            "    where n.nspname = 'public' and p.proname like '%\\_api' escape '\\';",
            "  if v_api < 15 then",
            "    raise exception 'production finalize: expected at least 15 public *_api functions, got %', v_api;",
            "  end if;",
            "  select count(*) into v_domain from pg_proc p join pg_namespace n on n.oid = p.pronamespace",
            "    where n.nspname = 'public' and p.proname like '%\\_domain' escape '\\';",
            "  if v_domain < 10 then",
            "    raise exception 'production finalize: expected at least 10 public *_domain functions, got %', v_domain;",
            "  end if;",
            "end $$;",
            "",
        ]
    )
    return "\n".join(parts)


def compose_target(fname: str) -> tuple[str, list[str]]:
    sources = COMPOSITION.get(fname, [])
    all_grants: list[str] = []
    func_registry: dict[str, str] = {}
    view_registry: dict[str, str] = {}
    static_parts: list[str] = [f"-- REV22 greenfield baseline: {fname}\n"]

    for src in sources:
        raw = read_source(src)
        if not raw:
            continue
        exclude = EXCLUDE_FROM.get((fname, src), set())
        cleaned, grants = strip_lines(raw)
        all_grants.extend(grants)

        fblocks = extract_function_blocks(cleaned)
        vblocks = extract_view_blocks(cleaned)

        if src in PICK_SOURCES and fname in PICK_SOURCES[src]:
            pick_set = {x.lower() for x in PICK_SOURCES[src][fname]}
            for fn, block in fblocks.items():
                if fn in pick_set:
                    func_registry[fn] = block
            for vn, block in vblocks.items():
                if vn in pick_set:
                    view_registry[vn] = block
            continue

        for fn, block in fblocks.items():
            if fn not in exclude:
                func_registry[fn] = block

        non_fn = cleaned
        for block in fblocks.values():
            non_fn = non_fn.replace(block, "")
        non_fn = re.sub(r"\n{3,}", "\n\n", non_fn).strip()
        if non_fn:
            static_parts.append(f"\n-- --- from {src} ---\n{non_fn}\n")

    if view_registry:
        static_parts.append("\n-- --- consolidated views (SSOT) ---\n")
        seen_views: set[str] = set()
        for block in view_registry.values():
            if block in seen_views:
                continue
            seen_views.add(block)
            static_parts.append(block + "\n\n")

    if func_registry:
        static_parts.append("\n-- --- consolidated functions (final bodies) ---\n")
        seen_blocks: set[str] = set()
        for block in func_registry.values():
            if block in seen_blocks:
                continue
            seen_blocks.add(block)
            static_parts.append(block + "\n\n")

    return "".join(static_parts), all_grants


# --- REV22 SSOT hardening (post-compose enforcement) ---

VIEW_OWNERS: dict[str, str] = {
    "v_properties_overview": "003_property_device_engine.sql",
    "v_devices_overview": "003_property_device_engine.sql",
    "v_bookings_overview": "004_booking_lock_engine.sql",
    "v_onboarding_progress": "011_onboarding_engine.sql",
    "v_onboarding_lifecycle_overview": "011_onboarding_engine.sql",
    "v_subscription_overview": "009_commerce_engine.sql",
    "v_crm_pipeline": "015_crm_engine.sql",
    "v_automation_runs_overview": "016_automation_engine.sql",
    "v_tenant_events_overview": "000_supabase_platform.sql",
    "v_tenant_audit_overview": "000_supabase_platform.sql",
}

THIN_RPCS = {
    "insert_event",
    "create_property",
    "assign_device",
    "generate_lock_code",
    "create_booking",
    "create_subscription",
    "log_event",
}

FORBIDDEN_IN_000 = {
    "integrations_domain",
    "auth_api",
    "integrations_api",
    "integrations_oauth_complete_api",
    "auth_switch_tenant",
}

FORBIDDEN_IN_017 = {
    "integrations_domain_ext",
    "enforce_device_integration_consistency",
}


def remove_function_by_name(text: str, names: set[str]) -> tuple[str, list[str]]:
    removed: list[str] = []
    blocks = extract_function_blocks(text)
    for name in names:
        if name in blocks:
            text = text.replace(blocks[name], "")
            removed.append(name)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text, removed


def remove_views_not_owned(text: str, fname: str) -> tuple[str, list[str]]:
    removed: list[str] = []
    blocks = extract_view_blocks(text)
    for vname, block in blocks.items():
        owner = VIEW_OWNERS.get(vname)
        if owner != fname:
            text = text.replace(block, "")
            removed.append(vname)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text, removed


def remove_api_functions(text: str) -> tuple[str, list[str]]:
    blocks = extract_function_blocks(text)
    removed: list[str] = []
    for name, block in blocks.items():
        if name.endswith("_api"):
            text = text.replace(block, "")
            removed.append(name)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text, removed


def dedupe_view_blocks(text: str) -> tuple[str, list[str]]:
    """Remove duplicate create view blocks (keep last) within a file."""
    removed: list[str] = []
    pattern = re.compile(
        r"(create\s+or\s+replace\s+view\s+public\.(\w+)[\s\S]*?;\s*)",
        re.I,
    )
    matches = list(pattern.finditer(text))
    seen_last: dict[str, int] = {}
    for i, m in enumerate(matches):
        seen_last[m.group(2).lower()] = i
    for i, m in enumerate(matches):
        vname = m.group(2).lower()
        if seen_last[vname] != i:
            text = text.replace(m.group(1), "")
            removed.append(vname)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text, removed


def dedupe_create_policies(text: str) -> tuple[str, list[str]]:
    """Remove duplicate create policy blocks (keep last) within a file."""
    removed: list[str] = []
    pattern = re.compile(
        r"(?:drop policy if exists (\w+) on[\s\S]*?)?create policy (\w+) on[\s\S]*?;",
        re.I,
    )
    matches = list(pattern.finditer(text))
    seen_last: dict[str, int] = {}
    for i, m in enumerate(matches):
        seen_last[m.group(2).lower()] = i
    for i, m in enumerate(matches):
        pname = m.group(2).lower()
        if seen_last[pname] != i:
            text = text.replace(m.group(0), "")
            removed.append(pname)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text, removed


def strip_notification_domain_sql(text: str) -> tuple[str, list[str]]:
    """Remove notification tables/functions from non-006 modules."""
    removed: list[str] = []
    blocks = extract_function_blocks(text)
    for name, block in blocks.items():
        if name.startswith("notification_") or name == "automation_enqueue_notification":
            text = text.replace(block, "")
            removed.append(name)
    for marker in ("notification_templates", "notification_preferences", "notification_queue", "notification_history"):
        tbl_pat = re.compile(
            rf"create table if not exists public\.{marker}[\s\S]*?;\s*",
            re.I,
        )
        for m in tbl_pat.finditer(text):
            text = text.replace(m.group(0), "")
            removed.append(marker)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text, list(dict.fromkeys(removed))


def enforce_ssot_hardening() -> dict[str, list[str]]:
    report: dict[str, list[str]] = {"removed": [], "files": []}

    for fname in OUT_FILES:
        if fname in ("018_security_hardening.sql", "019_grant_matrix.sql", "020_production_finalize.sql"):
            continue
        path = OUT / fname
        text = path.read_text(encoding="utf-8")
        orig = text
        file_removed: list[str] = []

        text, r = remove_views_not_owned(text, fname)
        file_removed.extend(f"view:{x}" for x in r)

        if fname != "017_edge_rpc_foundation.sql":
            text, r = remove_api_functions(text)
            file_removed.extend(f"api:{x}" for x in r)
            thin = THIN_RPCS
            if fname == "000_supabase_platform.sql":
                thin = set()
            text, r = remove_function_by_name(text, thin)
            file_removed.extend(f"rpc:{x}" for x in r)

        if fname == "000_supabase_platform.sql":
            text, r = remove_function_by_name(text, FORBIDDEN_IN_000)
            file_removed.extend(f"000-forbidden:{x}" for x in r)
            text = re.sub(
                r"create\s+or\s+replace\s+function\s+public\.log_event[\s\S]*?\$\$\s*;",
                "",
                text,
                count=1,
                flags=re.I,
            )

        if fname == "017_edge_rpc_foundation.sql":
            text, r = remove_function_by_name(text, FORBIDDEN_IN_017)
            file_removed.extend(f"017-forbidden:{x}" for x in r)
            text, r = remove_views_not_owned(text, fname)
            file_removed.extend(f"view:{x}" for x in r)

        if fname in ("001_core_types.sql", "016_automation_engine.sql"):
            text, r = strip_notification_domain_sql(text)
            file_removed.extend(f"notification:{x}" for x in r)

        text, r = dedupe_view_blocks(text)
        file_removed.extend(f"view-dup:{x}" for x in r)

        text, r = dedupe_create_policies(text)
        file_removed.extend(f"policy-dup:{x}" for x in r)

        if text != orig:
            path.write_text(text, encoding="utf-8")
            report["files"].append(fname)
            report["removed"].extend(f"{fname}: {x}" for x in file_removed)

    return report


def main() -> None:
    if not ARCHIVE.exists():
        raise SystemExit(f"Archive not found: {ARCHIVE}")

    # Remove current output files
    for p in OUT.glob("*.sql"):
        p.unlink()

    total_grants: list[str] = []

    for fname in OUT_FILES:
        if fname == "018_security_hardening.sql":
            (OUT / fname).write_text(build_018(), encoding="utf-8")
            continue
        if fname == "020_production_finalize.sql":
            (OUT / fname).write_text(build_020(), encoding="utf-8")
            continue
        if fname == "019_grant_matrix.sql":
            continue
        body, grants = compose_target(fname)
        total_grants.extend(grants)
        (OUT / fname).write_text(body, encoding="utf-8")
        print(f"Wrote {fname} ({len(body)} bytes)")

    # Collect grants from ALL archive files for 019 completeness
    for p in sorted(ARCHIVE.glob("*.sql")):
        _, g = strip_lines(p.read_text(encoding="utf-8"))
        total_grants.extend(g)

    # 050 dynamic grant DO blocks → 019 only
    grant050 = read_source("050_rev20_baseline_consolidation.sql")
    if grant050:
        total_grants.append("-- --- 050 grant lockdown DO blocks (execute via 019 deployment) ---")
        for block in re.findall(r"do \$block\$.*?end;\s*\$block\$;", grant050, re.S | re.I):
            if "grant execute" in block.lower() or "revoke all on function" in block.lower():
                total_grants.append(block.strip())

    (OUT / "019_grant_matrix.sql").write_text(build_019(total_grants), encoding="utf-8")
    print("Wrote 019_grant_matrix.sql")

    # Final pass: strip grant DO blocks, execute grants, tenant stubs from 000
    extra_grants: list[str] = []
    for fname in OUT_FILES:
        if fname in ("019_grant_matrix.sql", "018_security_hardening.sql", "020_production_finalize.sql"):
            continue
        path = OUT / fname
        text = path.read_text(encoding="utf-8")
        text, do_grants = strip_grant_do_blocks(text)
        extra_grants.extend(do_grants)
        text, leaked = strip_lines(text)
        extra_grants.extend(leaked)
        if fname == "000_supabase_platform.sql":
            text = remove_superseded_platform_tenant_stubs(text)
        path.write_text(text, encoding="utf-8")
    total_grants.extend(extra_grants)
    (OUT / "019_grant_matrix.sql").write_text(build_019(total_grants), encoding="utf-8")

    hardening = enforce_ssot_hardening()
    print(f"SSOT hardening: {len(hardening['files'])} files touched")
    for entry in hardening["removed"][:40]:
        print(f"  - {entry}")
    if len(hardening["removed"]) > 40:
        print(f"  ... and {len(hardening['removed']) - 40} more")
    print("Done.")


if __name__ == "__main__":
    main()
