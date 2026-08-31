#!/usr/bin/env python3
"""
REV22 deterministic migration consolidator.
Moves 54 historical migrations into 21 greenfield files per governance rules.
"""
from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "supabase" / "migrations"
OUT = ROOT / "supabase" / "migrations"
ARCHIVE = ROOT / "supabase" / "migrations_archive_rev19"

GRANT_PATTERNS = [
    re.compile(r"^\s*grant\s+execute\b", re.I),
    re.compile(r"^\s*revoke\s+.*\bon\s+function\b", re.I),
    re.compile(r"^\s*grant\s+select\s+on\s+(?:public\.)?v_", re.I),
    re.compile(r"^\s*revoke\s+.*\bon\s+(?:public\.)?v_", re.I),
]

# Functions explicitly owned by target (overrides prefix heuristics)
FUNCTION_OWNER: dict[str, str] = {
    # 002 REV21 + auth
    "platform._rev21_resolve_membership": "002",
    "public.resolve_active_tenant": "002",
    "platform.current_tenant_id": "002",
    "platform.current_role": "002",
    "platform.has_role": "002",
    "platform.has_tenant_membership": "002",
    "public.auth_domain": "002",
    "public.auth_domain_ext": "002",
    "public.auth_domain_ext_031": "002",
    "public.auth_resolve_tenant_switch": "002",
    "public.auth_switch_tenant": "002",
    "public.auth_invite_member": "002",
    "public.handle_new_tenant": "002",
    "public.enforce_tenant_owner_invariant": "002",
    # 003
    "public.devices_domain": "003",
    "public.devices_assign_device_to_room": "003",
    "public.enforce_device_hierarchy": "003",
    "public.enforce_device_assignment_tenant_consistency": "003",
    # 004
    "public.booking_domain": "004",
    "public.locks_domain": "004",
    "public.booking_create_booking_access": "004",
    "public.booking_compute_access_window": "004",
    "public.booking_calculate_access_window": "004",
    "public.booking_generate_booking_access": "004",
    "public.booking_regenerate_booking_access": "004",
    "public.enforce_booking_tenant_consistency": "004",
    "public.enforce_booking_access_consistency": "004",
    "public.enforce_lock_device_integrity": "004",
    "public.enforce_access_credential_consistency": "004",
    "public.enforce_property_tenant_consistency": "004",
    # 005
    "public.integrations_domain": "005",
    "public.integrations_domain_ext": "005",
    "public.integrations_oauth_url_encode": "005",
    "public.integrations_start_oauth": "005",
    "public.integrations_resolve_oauth_state": "005",
    "public.integrations_complete_oauth": "005",
    "public.integrations_exchange_oauth_tokens": "005",
    "public.integrations_oauth_complete_api": "005",
    "public.enforce_device_integration_consistency": "005",
    # 006
    "public.operations_domain": "006",
    "public.notification_resolve_template": "006",
    "public.notification_is_channel_enabled": "006",
    "public.notification_domain": "006",
    # 007-016 domains
    "public.preconfig_domain": "007",
    "public.logistics_domain": "008",
    "public.logistics_dispatch_fulfilment_order": "008",
    "public.enforce_fulfilment_order_consistency": "008",
    "public.commerce_domain": "009",
    "public.commerce_change_subscription_plan": "009",
    "public.commerce_create_subscription": "009",
    "public.payment_transition_status": "009",
    "public.payment_domain": "009",
    "public.sync_subscription_tier_from_plan": "009",
    "public.prevent_subscription_tier_drift": "009",
    "public.enforce_subscription_plan_required": "009",
    "public.portal_domain": "010",
    "public.enforce_portal_user_preference_membership": "010",
    "public.onboarding_domain": "011",
    "public.onboarding_lifecycle_allowed_transition": "011",
    "public.onboarding_lifecycle_apply_transition": "011",
    "public.onboarding_lifecycle_get": "011",
    "public.onboarding_lifecycle_list_transitions": "011",
    "public.enforce_onboarding_lifecycle_tenant_consistency": "011",
    "public.enforce_onboarding_lifecycle_transitions_consistency": "011",
    "public.optimization_domain": "012",
    "public.monetization_domain": "013",
    "public.enforce_proposal_items_tenant_consistency": "013",
    "public.trg_customer_proposals_status_timestamps": "013",
    "public.crm_domain": "015",
    "public.crm_soft_delete_row": "015",
    "public.trg_crm_contacts_consent_timestamps": "015",
    "public.trg_crm_leads_conversion_timestamp": "015",
    "public.trg_crm_notes_version_increment": "015",
    "public.automation_domain": "016",
    "public.automation_domain_ext": "016",
    "public.automation_cancel_run": "016",
    "public.automation_start_run": "016",
    "public.automation_dispatch_event": "016",
    "public.automation_enqueue_notification": "016",
    "public.enforce_automation_run_tenant_consistency": "016",
    "public.enforce_automation_run_step_consistency": "016",
    "public.enforce_automation_subscription_consistency": "016",
    # 017 edge
    "public.is_platform_admin": "017",
    "public.edge_require_tenant": "017",
    "public.edge_require_manager": "017",
    "public.edge_require_admin": "017",
    "public.insert_event": "017",
    "public.create_property": "017",
    "public.assign_device": "017",
    "public.assign_device_to_room": "017",
    "public.generate_lock_code": "017",
    "public.create_booking": "017",
    "public.onboarding_step_update": "017",
    "public.create_subscription": "017",
    "public.log_event": "017",
    "public.calculate_optimization_score": "017",
    "public.generate_monetization_proposal": "017",
    "public.change_subscription_plan": "017",
    "public.dispatch_fulfilment_order": "017",
    "public.get_onboarding_lifecycle": "017",
    "public.list_onboarding_lifecycle_transitions": "017",
    "public.onboarding_lifecycle_transition": "017",
    "public.integrations_oauth_complete": "017",
    # 018 cross-cutting
    "platform.has_tenant_access": "018",
    "public.has_tenant_access": "018",
    # 000 platform (selected - rest platform.* default 000)
    "public.edge_soft_delete_row": "000",
}

API_SUFFIX = "_api"
EDGE_PREFIX = "edge_require_"

# Whole source files whose non-grant, non-edge-api content goes primarily to one target
FILE_PRIMARY: dict[str, str] = {
    "000_supabase_platform_rev19.sql": "000",
    "001_core_types_rev19.sql": "001",
    "002_core_saas_rev19.sql": "002",
    "003_property_device_engine_rev19.sql": "003",
    "004_booking_lock_engine_rev19.sql": "004",
    "005_integration_engine_rev19.sql": "005",
    "006_operations_engine_rev19.sql": "006",
    "007_preconfig_engine_rev19.sql": "007",
    "008_logistics_engine_rev19.sql": "008",
    "009_commerce_engine_rev19.sql": "009",
    "010_service_portal_engine_rev19.sql": "010",
    "011_onboarding_engine_rev19.sql": "011",
    "012_optimization_engine_rev19.sql": "012",
    "013_customer_proposal_monetization_rev19.sql": "013",
    "014_platform_bootstrap_finale_rev19.sql": "014",
    "015_crm_engine_rev19.sql": "015",
    "016_automation_engine_rev19.sql": "016",
}

EXTENSION_ROUTES: dict[str, str] = {
    "018_devices_extensions_rev19.sql": "003",
    "019_booking_locks_extensions_rev19.sql": "004",
    "020_commerce_logistics_extensions_rev19.sql": "009",  # split below
    "021_module_extensions_rev19.sql": "006",
    "022_crm_extensions_rev19.sql": "015",
    "026_onboarding_lifecycle_extensions_rev19.sql": "011",
    "027_automation_extensions_rev19.sql": "016",
    "028_platform_views_extensions_rev19.sql": "000",
    "031_core_saas_auth_extensions_rev19.sql": "002",
    "033_auth_integrations_extensions_rev19.sql": "002",
    "034_operations_notifications_rev19.sql": "006",
    "035_commerce_payment_api_rev19.sql": "009",
    "036_booking_access_window_rev19.sql": "004",
    "037_platform_webhook_processing_rev19.sql": "000",
    "038_edge_api_architecture_completion_rev19.sql": "017",
    "039_edge_stabilization_routing_rev19.sql": "000",
    "040_integrations_oauth_start_rev19.sql": "005",
    "041_core_saas_tenant_switch_rev19.sql": "002",
    "042_core_saas_auth_security_rev19.sql": "002",
    "043_devices_security_rev19.sql": "003",
    "044_logistics_security_rev19.sql": "008",
    "045_integrations_oauth_security_rev19.sql": "005",
    "046_edge_api_security_rev19.sql": "017",
    "047_platform_security_rev19.sql": "000",
    "048_production_security_fixes_rev19.sql": "005",
    "049_production_audit_fixes_rev19.sql": "002",
    "050_rev20_baseline_consolidation.sql": "000",
    "051_rev21_tenant_authority_core.sql": "002",
    "052_rev21_tenant_access_control.sql": "018",
    "053_rev21_tenant_context.sql": "002",
    "017_edge_rpc_foundation_rev19.sql": "017",
    "023_edge_api_thin_wrappers_rev19.sql": "017",
    "024_edge_foundation_thin_rev19.sql": "017",
    "025_foundation_rpcs_views_rev19.sql": "017",
    "029_edge_automation_api_extensions_rev19.sql": "017",
    "030_edge_onboarding_lifecycle_extensions_rev19.sql": "017",
    "032_edge_platform_extensions_rev19.sql": "000",
}

VIEW_OWNER: dict[str, str] = {
    "tenant_user_context": "002",
    "v_properties_overview": "011",
    "v_devices_overview": "003",
    "v_onboarding_progress": "011",
    "v_onboarding_lifecycle_overview": "011",
    "v_bookings_overview": "004",
    "v_crm_pipeline": "015",
    "v_subscription_overview": "009",
    "v_automation_runs_overview": "016",
    "v_tenant_events_overview": "000",
    "v_tenant_audit_overview": "000",
}

TABLE_OWNER: dict[str, str] = {
    "integration_oauth_states": "005",
    "notification_templates": "006",
    "notification_preferences": "006",
    "notification_queue": "006",
    "notification_history": "006",
    "onboarding_lifecycle": "011",
    "onboarding_lifecycle_transitions": "011",
}

TYPE_OWNER: dict[str, str] = {
    "notification_channel": "001",
    "notification_delivery_status": "001",
}

FUNC_START = re.compile(
    r"^create\s+(?:or\s+replace\s+)?function\s+((?:platform|public)\.\w+|\w+)\s*\(",
    re.I | re.M,
)
VIEW_START = re.compile(r"^create\s+(?:or\s+replace\s+)?view\s+(?:public\.)?(\w+)", re.I | re.M)
POLICY_START = re.compile(r"^create\s+policy\s+(\w+)\s+on\s+", re.I | re.M)
TABLE_START = re.compile(
    r"^create\s+table\s+(?:if\s+not\s+exists\s+)?(?:(platform|public)\.)?(\w+)",
    re.I | re.M,
)
OBJECT_EMIT_ORDER = {
    "table:": 0,
    "type:": 1,
    "view:": 2,
    "function:": 3,
    "alter:": 4,
    "policy:": 5,
    "drop:": 6,
}
TYPE_START = re.compile(r"^create\s+type\s+(?:public\.)?(\w+)", re.I | re.M)
ALTER_TABLE = re.compile(r"^alter\s+table\s+", re.I)


def migration_sort_key(p: Path) -> int:
    m = re.match(r"^(\d+)_", p.name)
    return int(m.group(1)) if m else 9999


def is_grant_line(line: str) -> bool:
    s = line.strip()
    if not s or s.startswith("--"):
        return False
    for pat in GRANT_PATTERNS:
        if pat.search(s):
            return True
    return False


def split_statements(sql: str) -> list[str]:
    """Split SQL into statements, respecting $$ dollar-quoted bodies."""
    stmts: list[str] = []
    buf: list[str] = []
    in_dollar = False
    dollar_tag = ""
    for line in sql.splitlines(keepends=True):
        buf.append(line)
        if not in_dollar:
            if re.search(r"\$\$", line):
                parts = re.split(r"(\$\w*\$)", line)
                # toggle for each tag on line
                for part in parts:
                    if re.fullmatch(r"\$\w*\$", part):
                        if not in_dollar:
                            in_dollar = True
                            dollar_tag = part
                        elif part == dollar_tag:
                            in_dollar = False
                            dollar_tag = ""
        else:
            if dollar_tag and dollar_tag in line:
                # simplistic: end when closing tag appears alone or at end
                if re.search(re.escape(dollar_tag) + r"\s*;", line):
                    in_dollar = False
                    dollar_tag = ""
        if not in_dollar and line.rstrip().endswith(";"):
            stmts.append("".join(buf))
            buf = []
    if buf:
        tail = "".join(buf).strip()
        if tail:
            stmts.append(tail)
    return stmts


def classify_function(name: str) -> str:
    n = name.lower()
    if n in {k.lower() for k in FUNCTION_OWNER}:
        for k, v in FUNCTION_OWNER.items():
            if k.lower() == n:
                return v
    bare = n.split(".")[-1]
    if bare.endswith(API_SUFFIX) or bare == "notification_api" or bare == "payment_api":
        return "017"
    if bare.startswith("edge_require_") or bare == "is_platform_admin":
        return "017"
    if n.startswith("platform."):
        return "000"
    if bare.startswith("enforce_crm_") or bare.startswith("crm_"):
        return "015"
    if bare.startswith("enforce_onboarding") or bare.startswith("onboarding_"):
        return "011"
    return ""


def classify_statement(stmt: str, src_file: str) -> tuple[str, str | None]:
    """Return (target, object_key) for routing."""
    s = stmt.strip()
    low = s.lower()
    if is_grant_line(s.split("\n")[0]):
        return "019", None
    if low.startswith("insert into platform.schema_migrations"):
        return "020", None
    if "search_path" in low and "alter function" in low and "018" in src_file:
        return "018", None

    m = FUNC_START.search(s)
    if m:
        fname = m.group(1)
        if not fname.startswith(("platform.", "public.")):
            if "platform." in low[:200]:
                fname = "platform." + fname.split(".")[-1]
            else:
                fname = "public." + fname.split(".")[-1]
        owner = classify_function(fname)
        if not owner:
            owner = FILE_PRIMARY.get(src_file, EXTENSION_ROUTES.get(src_file, "000"))
            if fname.endswith("_api") or "edge_require" in fname:
                owner = "017"
        return owner, f"function:{fname.lower()}"

    m = VIEW_START.search(s)
    if m:
        vname = m.group(1).lower()
        return VIEW_OWNER.get(vname, FILE_PRIMARY.get(src_file, "000")), f"view:{vname}"

    m = POLICY_START.search(s)
    if m:
        # policy on table - route with source file primary
        if "access_credentials_select" in s:
            return "004", f"policy:{m.group(1).lower()}"
        prim = FILE_PRIMARY.get(src_file, EXTENSION_ROUTES.get(src_file, "000"))
        return prim, f"policy:{m.group(1).lower()}"

    m = TABLE_START.search(s)
    if m:
        schema, tname = m.group(1), m.group(2)
        fqname = f"{schema.lower()}.{tname.lower()}" if schema else tname.lower()
        return TABLE_OWNER.get(
            tname.lower(),
            FILE_PRIMARY.get(src_file, EXTENSION_ROUTES.get(src_file, "000")),
        ), f"table:{fqname}"

    m = TYPE_START.search(s)
    if m:
        tname = m.group(1).lower()
        return TYPE_OWNER.get(tname, "001"), f"type:{tname}"

    if ALTER_TABLE.match(s):
        if "external_webhooks" in low:
            return "000", "alter:external_webhooks"
        if "subscriptions" in low and "plan_id" in low:
            return "009", "alter:subscriptions_plan_id"
        if "fulfilment_orders" in low and "customer_proposal_id" in low:
            return "013", "alter:fulfilment_orders"
        if "optimization_recommendations" in low and "customer_proposal_id" in low:
            return "013", "alter:optimization_recommendations"
        prim = FILE_PRIMARY.get(src_file, EXTENSION_ROUTES.get(src_file, "000"))
        return prim, f"alter:{hash(s) % 10**8}"

    if low.startswith("drop "):
        prim = FILE_PRIMARY.get(src_file, EXTENSION_ROUTES.get(src_file, "000"))
        return prim, f"drop:{hash(s) % 10**8}"

    if "018_security" in src_file or src_file.endswith("052_rev21_tenant_access_control.sql"):
        if "has_tenant_access" in low:
            return "018", None

    if src_file.endswith("050_rev20_baseline_consolidation.sql"):
        if low.startswith("do $block$") or "alter function" in low and "search_path" in low:
            return "018", f"do:{hash(s) % 10**8}"

    prim = FILE_PRIMARY.get(src_file, EXTENSION_ROUTES.get(src_file, "000"))
    if src_file == "020_commerce_logistics_extensions_rev19.sql":
        if "logistics_domain" in low or "logistics_dispatch" in low:
            prim = "008"
    if src_file == "021_module_extensions_rev19.sql":
        if "portal_domain" in low:
            prim = "010"
        elif "onboarding_domain" in low:
            prim = "011"
        elif "optimization_domain" in low:
            prim = "012"
        elif "monetization_domain" in low:
            prim = "013"
        elif "preconfig_domain" in low:
            prim = "007"
        elif "integrations_complete_oauth" in low:
            prim = "005"
        elif "operations_domain" in low:
            prim = "006"
    if src_file == "033_auth_integrations_extensions_rev19.sql":
        if "integrations_" in low and "auth_" not in low.split("function")[1][:30] if "function" in low else False:
            pass
    if src_file == "049_production_audit_fixes_rev19.sql":
        if "booking_create_booking_access" in low:
            return "004", "function:public.booking_create_booking_access"
        if "monetization_api" in low:
            return "017", "function:public.monetization_api"

    return prim, f"misc:{hash(s) % 10**8}"


def strip_grants_from_statement(stmt: str) -> str | None:
    lines = stmt.splitlines()
    if all(is_grant_line(l) or not l.strip() or l.strip().startswith("--") for l in lines if l.strip()):
        return None
    kept = [l for l in lines if not is_grant_line(l)]
    out = "\n".join(kept).strip()
    return out if out else None


def extract_edge_require_tenant_052(all_sql: str) -> str | None:
    """Extract final edge_require_tenant from 052."""
    if "052_rev21" not in all_sql:
        return None
    return None  # handled by statement routing


def main() -> None:
    sources = sorted(SRC.glob("*.sql"), key=migration_sort_key)
    if not sources:
        raise SystemExit("No source migrations found")

    targets = {f"{i:03d}": [] for i in range(21)}
    grants: list[str] = []
    verify: list[str] = []
    # object store: target -> key -> stmt (last wins)
    objects: dict[str, dict[str, str]] = {f"{i:03d}": {} for i in range(21)}
    misc_blocks: dict[str, list[str]] = {f"{i:03d}": [] for i in range(21)}

    for path in sources:
        src_name = path.name
        text = path.read_text(encoding="utf-8")
        stmts = split_statements(text)
        for stmt in stmts:
            first = stmt.strip().split("\n")[0] if stmt.strip() else ""
            if is_grant_line(first) or any(is_grant_line(l) for l in stmt.splitlines() if l.strip() and not l.strip().startswith("--")):
                # statement contains grant lines - extract grants only to 019, rest stripped
                for line in stmt.splitlines():
                    if is_grant_line(line):
                        grants.append(line.strip())
                cleaned = strip_grants_from_statement(stmt)
                if not cleaned:
                    continue
                stmt = cleaned

            if stmt.strip().lower().startswith("insert into platform.schema_migrations"):
                verify.append(stmt.strip())
                continue

            target, key = classify_statement(stmt, src_name)

            # 021 split logistics/commerce
            if src_name == "020_commerce_logistics_extensions_rev19.sql":
                low = stmt.lower()
                if "logistics_domain" in low or "logistics_dispatch" in low:
                    target = "008"
                elif "commerce_" in low or "trg_customer_proposals" in low:
                    target = "013" if "trg_customer" in low else "009"

            if src_name == "049_production_audit_fixes_rev19.sql":
                if "booking_create_booking_access" in stmt.lower():
                    target = "004"
                elif "monetization_api" in stmt.lower():
                    target = "017"
                elif "auth_invite_member" in stmt.lower():
                    target = "002"

            if src_name == "048_production_security_fixes_rev19.sql":
                if "monetization_api" in stmt.lower():
                    target = "017"
                elif "enforce_device_integration" in stmt.lower():
                    target = "005"

            if src_name == "047_platform_security_rev19.sql":
                if "crm_soft_delete" in stmt.lower():
                    target = "015"
                elif "auth_domain_ext" in stmt.lower():
                    target = "002"
                elif "access_credentials_select" in stmt.lower():
                    target = "004"

            if src_name == "050_rev20_baseline_consolidation.sql":
                low = stmt.lower()
                if "locks_api" in low or "operations_api" in low or "integrations_api" in low:
                    target = "017"
                elif "auth_domain" in low and "create or replace function" in low:
                    target = "002"
                elif low.startswith("do $block$") and "search_path" in low:
                    target = "018"
                elif "grant " in low or "revoke " in low:
                    for line in stmt.splitlines():
                        if is_grant_line(line):
                            grants.append(line.strip())
                    continue

            if src_name == "052_rev21_tenant_access_control.sql":
                if "integrations_api" in stmt.lower() and "create or replace function" in stmt.lower():
                    target = "017"
                elif "integrations_resolve_oauth_state" in stmt.lower():
                    target = "005"
                elif "edge_require_tenant" in stmt.lower():
                    target = "017"
                elif "has_tenant_access" in stmt.lower():
                    target = "018"

            if src_name == "033_auth_integrations_extensions_rev19.sql":
                low = stmt.lower()
                if "integrations_domain_ext" in low or "integrations_api" in low:
                    if "auth_" not in low.split("function")[1][:20] if "function" in low else False:
                        target = "005" if "integrations_domain" in low else "017"
                if "auth_" in low and "create or replace function" in low:
                    target = "002" if "auth_api" not in low else "017"

            if src_name == "025_foundation_rpcs_views_rev19.sql":
                if "create or replace view" in stmt.lower():
                    m = VIEW_START.search(stmt)
                    if m:
                        target = VIEW_OWNER.get(m.group(1).lower(), "017")
                elif "create or replace function" in stmt.lower():
                    target = "017"

            if key and key.startswith(("function:", "view:", "table:", "type:", "policy:")):
                objects[target][key] = stmt
            else:
                if target in ("018", "019", "020"):
                    if target == "019":
                        continue
                    if target == "020":
                        verify.append(stmt)
                        continue
                misc_blocks[target].append(stmt)

    # Remove REV21 duplicates from 000 (original tenant helpers superseded by 002/018)
    for dup in [
        "function:platform.current_tenant_id",
        "function:platform.current_role",
        "function:platform.has_tenant_access",
        "function:platform.has_role",
        "function:public.has_tenant_access",
    ]:
        objects["000"].pop(dup, None)

    OUT_NAMES = {
        "000": "000_supabase_platform.sql",
        "001": "001_core_types.sql",
        "002": "002_core_saas.sql",
        "003": "003_property_device_engine.sql",
        "004": "004_booking_lock_engine.sql",
        "005": "005_integration_engine.sql",
        "006": "006_operations_engine.sql",
        "007": "007_preconfig_engine.sql",
        "008": "008_logistics_engine.sql",
        "009": "009_commerce_engine.sql",
        "010": "010_service_portal_engine.sql",
        "011": "011_onboarding_engine.sql",
        "012": "012_optimization_engine.sql",
        "013": "013_customer_proposal_monetization.sql",
        "014": "014_platform_bootstrap.sql",
        "015": "015_crm_engine.sql",
        "016": "016_automation_engine.sql",
        "017": "017_edge_rpc_foundation.sql",
        "018": "018_security_hardening.sql",
        "019": "019_grant_matrix.sql",
        "020": "020_production_finalize.sql",
    }

    # Archive old migrations
    if ARCHIVE.exists():
        shutil.rmtree(ARCHIVE)
    ARCHIVE.mkdir(parents=True)
    for p in sources:
        shutil.move(str(p), str(ARCHIVE / p.name))

    OUT.mkdir(parents=True, exist_ok=True)

    for tid, fname in OUT_NAMES.items():
        header = f"-- REV22 greenfield baseline: {fname}\n-- Consolidated from migrations_archive_rev19 (000-053)\n\n"
        parts = [header]
        if tid == "019":
            parts.append("-- SINGLE SSOT for EXECUTE and view grants\n\n")
            parts.append("\n".join(sorted(set(grants))))
            parts.append("\n")
        elif tid == "020":
            parts.append("-- Production finalization: verification only\n\n")
            # 21 schema_migrations rows
            migrations = list(OUT_NAMES.values())
            for m in migrations:
                ver = m.replace(".sql", "").upper().replace("_", ".")
                parts.append(
                    f"insert into platform.schema_migrations (migration_name, version, rollback_available)\n"
                    f"values ('{m.replace('.sql', '')}', '{ver}', false)\n"
                    f"on conflict (version) do nothing;\n\n"
                )
            parts.append("select platform.ensure_pg_cron_jobs();\n\n")
            parts.append(
                "do $$\n"
                "declare v_count int;\n"
                "begin\n"
                "  select count(*) into v_count from pg_proc p join pg_namespace n on n.oid = p.pronamespace\n"
                "  where n.nspname = 'public' and p.proname like '%_domain';\n"
                "  if v_count < 10 then raise exception 'domain function count verification failed';\n"
                "  end if;\n"
                "end $$;\n"
            )
        else:
            seen: set[int] = set()
            deferred_triggers: list[str] = []
            deferred_inserts: list[str] = []

            def is_seed_insert(stmt: str) -> bool:
                low = stmt.lower()
                if "insert into platform.schema_migrations" in low:
                    return False
                return bool(re.search(r"^\s*insert into\b", stmt, re.I | re.M))

            def object_sort_key(item: tuple[str, str]) -> tuple[int, str]:
                key, _ = item
                prefix = key.split(":", 1)[0] + ":"
                return (OBJECT_EMIT_ORDER.get(prefix, 99), key)

            table_and_type_objects: list[str] = []
            other_objects: list[str] = []
            for key, stmt in sorted(objects.get(tid, {}).items(), key=object_sort_key):
                prefix = key.split(":", 1)[0] + ":"
                if prefix in ("table:", "type:"):
                    table_and_type_objects.append(stmt)
                else:
                    other_objects.append(stmt)

            for stmt in table_and_type_objects:
                parts.append(stmt)
                parts.append("\n\n")

            for stmt in misc_blocks.get(tid, []):
                h = hash(stmt)
                if h in seen:
                    continue
                seen.add(h)
                if re.match(r"^\s*create trigger\b", stmt, re.I):
                    deferred_triggers.append(stmt)
                elif is_seed_insert(stmt):
                    deferred_inserts.append(stmt)
                else:
                    parts.append(stmt)
                    parts.append("\n\n")

            for stmt in other_objects:
                parts.append(stmt)
                parts.append("\n\n")

            for stmt in deferred_triggers:
                parts.append(stmt)
                parts.append("\n\n")

            for stmt in deferred_inserts:
                parts.append(stmt)
                parts.append("\n\n")

        out_path = OUT / fname
        out_path.write_text("".join(parts), encoding="utf-8")
        print(f"Wrote {out_path} ({out_path.stat().st_size} bytes)")

    print(f"Archived {len(sources)} files to {ARCHIVE}")


if __name__ == "__main__":
    main()
