#!/usr/bin/env python3
"""Regenerate REV22 greenfield migrations from archive (no archival move)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import rev22_consolidate as c  # noqa: E402

SRC = ROOT / "supabase" / "migrations_archive_rev19"
OUT = ROOT / "supabase" / "migrations"
OBJECT_EMIT_ORDER = c.OBJECT_EMIT_ORDER

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


def route_statement(stmt: str, src_name: str) -> str:
    target, key = c.classify_statement(stmt, src_name)

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
        if "auth_" in low and "create or replace function" in low:
            target = "002" if "auth_api" not in low else "017"

    if src_name == "025_foundation_rpcs_views_rev19.sql":
        if "create or replace view" in stmt.lower():
            m = c.VIEW_START.search(stmt)
            if m:
                target = c.VIEW_OWNER.get(m.group(1).lower(), "017")
        elif "create or replace function" in stmt.lower():
            target = "017"

    return target, key


def main() -> None:
    sources = sorted(SRC.glob("*.sql"), key=c.migration_sort_key)
    if not sources:
        raise SystemExit(f"No archive migrations in {SRC}")

    grants: list[str] = []
    verify: list[str] = []
    objects: dict[str, dict[str, str]] = {f"{i:03d}": {} for i in range(21)}
    misc_blocks: dict[str, list[str]] = {f"{i:03d}": [] for i in range(21)}

    for path in sources:
        src_name = path.name
        text = path.read_text(encoding="utf-8")
        for stmt in c.split_statements(text):
            first = stmt.strip().split("\n")[0] if stmt.strip() else ""
            if c.is_grant_line(first) or any(
                c.is_grant_line(line)
                for line in stmt.splitlines()
                if line.strip() and not line.strip().startswith("--")
            ):
                for line in stmt.splitlines():
                    if c.is_grant_line(line):
                        grants.append(line.strip())
                cleaned = c.strip_grants_from_statement(stmt)
                if not cleaned:
                    continue
                stmt = cleaned

            if stmt.strip().lower().startswith("insert into platform.schema_migrations"):
                verify.append(stmt.strip())
                continue

            target, key = route_statement(stmt, src_name)

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

    for dup in [
        "function:platform.current_tenant_id",
        "function:platform.current_role",
        "function:platform.has_tenant_access",
        "function:platform.has_role",
        "function:public.has_tenant_access",
    ]:
        objects["000"].pop(dup, None)

    OUT.mkdir(parents=True, exist_ok=True)

    for tid, fname in OUT_NAMES.items():
        header = (
            f"-- REV22 greenfield baseline: {fname}\n"
            f"-- Consolidated from migrations_archive_rev19 (000-053)\n\n"
        )
        parts = [header]

        if tid == "019":
            parts.append("-- SINGLE SSOT for EXECUTE and view grants\n\n")
            parts.append("\n".join(sorted(set(grants))))
            parts.append("\n")
        elif tid == "020":
            parts.append("-- Production finalization: verification only\n\n")
            for m in OUT_NAMES.values():
                ver = m.replace(".sql", "").upper().replace("_", ".")
                parts.append(
                    "insert into platform.schema_migrations "
                    "(migration_name, version, rollback_available)\n"
                    f"values ('{m.replace('.sql', '')}', '{ver}', false)\n"
                    "on conflict (version) do nothing;\n\n"
                )
            parts.append("select platform.ensure_pg_cron_jobs();\n\n")
            parts.append(
                "do $$\n"
                "declare v_count int;\n"
                "begin\n"
                "  select count(*) into v_count from pg_proc p "
                "join pg_namespace n on n.oid = p.pronamespace\n"
                "  where n.nspname = 'public' and p.proname like '%_domain';\n"
                "  if v_count < 10 then "
                "raise exception 'domain function count verification failed';\n"
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

    print(f"Regenerated {len(OUT_NAMES)} files from {len(sources)} archive sources")


if __name__ == "__main__":
    main()
