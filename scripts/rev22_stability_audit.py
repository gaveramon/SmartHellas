#!/usr/bin/env python3
"""REV22 post-hardening read-only stability audit."""
from __future__ import annotations

import hashlib
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIG = ROOT / "supabase" / "migrations"
ARCHIVE = ROOT / "supabase" / "migrations_archive_rev19"

MIGRATION_ORDER = [f"{i:03d}" for i in range(21)]
FILES = sorted(MIG.glob("[0-9][0-9][0-9]_*.sql"))

FUNC_SIG = re.compile(
    r"create\s+(?:or\s+replace\s+)?function\s+((?:platform|public)\.(\w+)\s*\([^)]*\))",
    re.I,
)
VIEW_DEF = re.compile(
    r"(create\s+or\s+replace\s+view\s+public\.(\w+)\s+as[\s\S]*?;)",
    re.I,
)
POLICY_DEF = re.compile(
    r"(create\s+policy\s+(\w+)\s+on\s+([\w.]+)[\s\S]*?;)",
    re.I,
)
FK_REF = re.compile(
    r"references\s+(?:public\.)?(\w+)\s*\(",
    re.I,
)
ENUM_DEF = re.compile(
    r"create\s+type\s+(?:public\.)?(\w+)\s+as\s+enum\s*\(([\s\S]*?)\)",
    re.I,
)
CREATE_TABLE = re.compile(
    r"create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?(\w+)",
    re.I,
)
ALTER_ADD_COL = re.compile(
    r"alter\s+table\s+(?:public\.)?(\w+)\s+add\s+column\s+(?:if\s+not\s+exists\s+)?(\w+)",
    re.I,
)

THIN_RPCS = {
    "insert_event", "create_property", "assign_device", "generate_lock_code",
    "create_booking", "create_subscription", "log_event",
}
REV21_FUNCS = {
    "resolve_active_tenant", "_rev21_resolve_membership", "current_tenant_id",
    "current_role", "has_role", "has_tenant_membership",
}
VIEW_OWNERS = {
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
NOTIFICATION_OBJECTS = {
    "notification_templates", "notification_preferences", "notification_queue",
    "notification_history", "notification_domain", "notification_api",
    "notification_resolve_template", "notification_is_channel_enabled",
    "automation_enqueue_notification",
}

FILE_ORDER = {f.name: i for i, f in enumerate(FILES)}


def read_all() -> dict[str, str]:
    return {f.name: f.read_text(encoding="utf-8", errors="replace") for f in FILES}


def norm_sig(sig: str) -> str:
    return re.sub(r"\s+", " ", sig.strip().lower())


def fn_hash(body: str) -> str:
    return hashlib.sha256(body.encode()).hexdigest()[:16]


def extract_functions(text: str) -> dict[str, dict]:
    out: dict[str, dict] = {}
    pos = 0
    pat = re.compile(
        r"create\s+(?:or\s+replace\s+)?function\s+((?:platform|public)\.\w+\s*\([^)]*\))",
        re.I,
    )
    while True:
        m = pat.search(text, pos)
        if not m:
            break
        sig = norm_sig(m.group(1))
        name = re.search(r"\.(\w+)\s*\(", sig).group(1).lower()
        rest = text[m.start():]
        em = re.search(r"\$\$\s*;", rest, re.S)
        if not em:
            break
        body = rest[: em.end()]
        out[name] = {"sig": sig, "hash": fn_hash(body), "body_len": len(body)}
        pos = m.start() + em.end()
    return out


def extract_views(text: str) -> dict[str, str]:
    return {m.group(2).lower(): m.group(1).strip() for m in VIEW_DEF.finditer(text)}


def extract_policies(text: str) -> dict[str, str]:
    return {m.group(2).lower(): m.group(1).strip() for m in POLICY_DEF.finditer(text)}


def extract_enums(text: str) -> dict[str, str]:
    return {m.group(1).lower(): re.sub(r"\s+", " ", m.group(2).strip().lower()) for m in ENUM_DEF.finditer(text)}


def archive_expected_signatures() -> dict[str, str]:
    """Build expected final signatures from archive (last-wins per function name)."""
    # Simulate consolidator source order for 017 RPCs from 025
    sources = [
        "025_foundation_rpcs_views_rev19.sql",
        "023_edge_api_thin_wrappers_rev19.sql",
        "024_edge_foundation_thin_rev19.sql",
        "046_edge_api_security_rev19.sql",
        "049_production_audit_fixes_rev19.sql",
    ]
    expected: dict[str, str] = {}
    for src in sources:
        p = ARCHIVE / src
        if not p.exists():
            continue
        for name, info in extract_functions(p.read_text(encoding="utf-8")).items():
            expected[name] = info["sig"]
    return expected


def check_ownership(sources: dict[str, str]) -> dict:
    issues = []
    views_by_file: dict[str, list[str]] = defaultdict(list)
    apis_by_file: dict[str, list[str]] = defaultdict(list)
    rpcs_by_file: dict[str, list[str]] = defaultdict(list)
    rev21_locs: dict[str, list[str]] = defaultdict(list)
    notif_locs: dict[str, list[str]] = defaultdict(list)

    for fname, text in sources.items():
        for vname in extract_views(text):
            views_by_file[vname].append(fname)
        for name, info in extract_functions(text).items():
            if name.endswith("_api"):
                apis_by_file[name].append(fname)
            if name in THIN_RPCS:
                rpcs_by_file[name].append(fname)
            if name in REV21_FUNCS or (name in REV21_FUNCS and "platform" in info["sig"]):
                rev21_locs[name].append(fname)
        for name in REV21_FUNCS:
            if re.search(rf"create\s+or\s+replace\s+function\s+(?:platform|public)\.{name}\s*\(", text, re.I):
                rev21_locs[name].append(fname)
        for obj in NOTIFICATION_OBJECTS:
            if re.search(rf"\b{obj}\b", text, re.I):
                if obj.startswith("notification") or obj == "automation_enqueue_notification":
                    notif_locs[obj].append(fname)

    for vname, locs in views_by_file.items():
        if len(locs) != 1:
            issues.append(f"view {vname}: {len(locs)} owners {locs}")
        elif VIEW_OWNERS.get(vname) and locs[0] != VIEW_OWNERS[vname]:
            issues.append(f"view {vname}: owner {locs[0]} != expected {VIEW_OWNERS[vname]}")

    for vname, owner in VIEW_OWNERS.items():
        if vname not in views_by_file:
            issues.append(f"view {vname}: MISSING (expected in {owner})")

    for name, locs in apis_by_file.items():
        if locs != ["017_edge_rpc_foundation.sql"]:
            issues.append(f"api {name}: {locs}")

    for name, locs in rpcs_by_file.items():
        allowed = {"017_edge_rpc_foundation.sql"}
        if name == "log_event":
            allowed.add("000_supabase_platform.sql")  # platform.log_event allowed
        bad = [x for x in locs if x not in allowed]
        if bad:
            issues.append(f"rpc {name}: extra locations {bad} (all: {locs})")

    for name, locs in rev21_locs.items():
        unique = list(dict.fromkeys(locs))
        if unique != ["002_core_saas.sql"]:
            issues.append(f"rev21 {name}: {unique}")

    for obj, locs in notif_locs.items():
        if obj == "notification_api":
            if locs != ["017_edge_rpc_foundation.sql"]:
                issues.append(f"notification_api: {list(dict.fromkeys(locs))}")
        elif obj in ("notification_templates", "notification_preferences", "notification_queue", "notification_history", "notification_domain", "notification_resolve_template", "notification_is_channel_enabled", "automation_enqueue_notification"):
            unique = list(dict.fromkeys(locs))
            if unique != ["006_operations_engine.sql"]:
                issues.append(f"{obj}: {unique}")

    return {
        "issues": issues,
        "view_count": len(views_by_file),
        "api_count": sum(len(v) for v in apis_by_file.values()),
    }


def check_fks(sources: dict[str, str]) -> list[str]:
    issues = []
    tables_by_file: dict[str, set[str]] = {}
    col_adds: list[tuple[str, str, str, int]] = []

    for fname, text in sources.items():
        tables_by_file[fname] = set(m.group(1).lower() for m in CREATE_TABLE.finditer(text))
        for m in ALTER_ADD_COL.finditer(text):
            col_adds.append((m.group(1).lower(), m.group(2).lower(), fname, FILE_ORDER[fname]))

    all_tables: dict[str, int] = {}
    for fname in sorted(sources, key=lambda x: FILE_ORDER[x]):
        for t in tables_by_file.get(fname, set()):
            all_tables[t] = FILE_ORDER[fname]

    critical_fks = [
        ("subscriptions", "plan_id", "product_plans", "009_commerce_engine.sql"),
        ("fulfilment_orders", "customer_proposal_id", "customer_proposals", "013_customer_proposal_monetization.sql"),
        ("optimization_recommendations", "customer_proposal_id", "customer_proposals", "013_customer_proposal_monetization.sql"),
    ]

    for table, col, ref_table, expected_file in critical_fks:
        text = sources.get(expected_file, "")
        if not re.search(
            rf"{table}[\s\S]*?{col}[\s\S]*?references\s+(?:public\.)?{ref_table}",
            text,
            re.I,
        ) and not re.search(
            rf"alter\s+table\s+(?:public\.)?{table}[\s\S]*?add\s+column[\s\S]*?{col}[\s\S]*?references\s+(?:public\.)?{ref_table}",
            text,
            re.I,
        ):
            issues.append(f"FK missing: {table}.{col} -> {ref_table} (expected in {expected_file})")

    # forward reference: column used in function before add column migration
    fo_text = sources.get("008_logistics_engine.sql", "")
    if re.search(r"customer_proposal_id", fo_text, re.I):
        fo_order = FILE_ORDER["008_logistics_engine.sql"]
        col_order = next((o for t, c, f, o in col_adds if t == "fulfilment_orders" and c == "customer_proposal_id"), 999)
        if fo_order < col_order and re.search(r"f\.customer_proposal_id|fulfilment_orders[\s\S]*customer_proposal_id", fo_text, re.I):
            issues.append(
                f"forward reference: 008 logistics_domain references fulfilment_orders.customer_proposal_id before 013 adds column (008={fo_order}, 013={col_order})"
            )

    return issues


def check_regressions(sources: dict[str, str]) -> list[str]:
    issues = []
    expected_rpcs = archive_expected_signatures()
    current_017 = extract_functions(sources.get("017_edge_rpc_foundation.sql", ""))

    for rpc in THIN_RPCS:
        if rpc not in current_017:
            issues.append(f"REGRESSION: thin RPC {rpc} missing from 017")
        elif rpc in expected_rpcs and current_017[rpc]["sig"] != expected_rpcs[rpc]:
            issues.append(
                f"REGRESSION: {rpc} signature changed: archive={expected_rpcs[rpc]} current={current_017[rpc]['sig']}"
            )

    # Compare view column structures via hash against archive SSOT
    archive_views: dict[str, str] = {}
    for src in ["025_foundation_rpcs_views_rev19.sql", "028_platform_views_extensions_rev19.sql",
                "026_onboarding_lifecycle_extensions_rev19.sql", "027_automation_extensions_rev19.sql"]:
        p = ARCHIVE / src
        if p.exists():
            archive_views.update(extract_views(p.read_text(encoding="utf-8")))

    for vname, owner in VIEW_OWNERS.items():
        cur = extract_views(sources.get(owner, "")).get(vname)
        arch = archive_views.get(vname)
        if cur and arch:
            cur_norm = re.sub(r"\s+", " ", cur.lower())
            arch_norm = re.sub(r"\s+", " ", arch.lower())
            if hashlib.sha256(cur_norm.encode()).hexdigest()[:12] != hashlib.sha256(arch_norm.encode()).hexdigest()[:12]:
                issues.append(f"REGRESSION: view {vname} body differs from archive source")
        elif arch and not cur:
            issues.append(f"REGRESSION: view {vname} missing vs archive")

    # Enum stability in 001
    arch_enums = extract_enums((ARCHIVE / "001_core_types_rev19.sql").read_text(encoding="utf-8"))
    cur_enums = extract_enums(sources.get("001_core_types.sql", ""))
    for ename, evals in arch_enums.items():
        if ename in cur_enums and cur_enums[ename] != evals:
            issues.append(f"REGRESSION: enum {ename} values changed")

    # Duplicate detection within files
    for fname, text in sources.items():
        fns = extract_functions(text)
        sigs = defaultdict(int)
        for name, info in extract_functions(text).items():
            sigs[name] += 1
        for name, cnt in sigs.items():
            if cnt > 1:
                issues.append(f"DUPLICATE function {name} x{cnt} in {fname}")

        views = [m.group(2).lower() for m in VIEW_DEF.finditer(text)]
        vcnt = defaultdict(int)
        for v in views:
            vcnt[v] += 1
        for v, cnt in vcnt.items():
            if cnt > 1:
                issues.append(f"DUPLICATE view {v} x{cnt} in {fname}")

    return issues


def check_over_rewrite(sources: dict[str, str]) -> list[str]:
    issues = []
    # Objects that should exist post-consolidation
    required_apis = [
        "auth_api", "booking_api", "commerce_api", "crm_api", "devices_api",
        "integrations_api", "locks_api", "logistics_api", "monetization_api",
        "notification_api", "onboarding_api", "operations_api", "optimization_api",
        "payment_api", "portal_api", "preconfig_api", "automation_api",
    ]
    f017 = extract_functions(sources.get("017_edge_rpc_foundation.sql", ""))
    for api in required_apis:
        if api not in f017:
            issues.append(f"MISSING required api: {api} in 017")

    # Renamed duplicate pattern: edge_soft_delete vs crm_soft_delete in wrong modules
    for fname, text in sources.items():
        if fname == "017_edge_rpc_foundation.sql":
            continue
        if re.search(r"create\s+or\s+replace\s+function\s+public\.edge_soft_delete_row", text, re.I):
            issues.append(f"edge_soft_delete_row leaked into {fname}")
        if re.search(r"create\s+or\s+replace\s+function\s+public\.integrations_domain_ext", text, re.I):
            issues.append(f"integrations_domain_ext leaked into {fname}")

    # 020 syntax
    t20 = sources.get("020_production_finalize.sql", "")
    if re.search(r"^\s*values\s*\(", t20, re.I | re.M) and "insert into platform.schema_migrations" not in t20.lower():
        issues.append("020 has orphan VALUES without INSERT")
    if re.search(r"^\s*values\s*\(", t20, re.I | re.M):
        orphan = len(re.findall(r"^\s*values\s*\(", t20, re.I | re.M))
        insert = len(re.findall(r"insert\s+into\s+platform\.schema_migrations", t20, re.I))
        if orphan > insert:
            issues.append(f"020 orphan VALUES lines ({orphan}) exceed INSERT blocks ({insert})")

    return issues


def main() -> None:
    sources = read_all()
    ownership = check_ownership(sources)
    fks = check_fks(sources)
    regressions = check_regressions(sources)
    over = check_over_rewrite(sources)

    cats = {
        "1_regression": regressions,
        "2_ownership": ownership["issues"],
        "3_cross_module": fks,
        "4_over_rewrite": over,
        "5_notification": [x for x in ownership["issues"] if "notification" in x.lower()],
    }

    print("=== REV22 STABILITY AUDIT ===\n")
    for cat, issues in cats.items():
        status = "PASS" if not issues else "FAIL"
        print(f"{cat}: {status} ({len(issues)} issues)")

    print("\n=== ALL ISSUES ===")
    for cat, issues in cats.items():
        for i in issues:
            print(f"[{cat}] {i}")

    total = sum(len(v) for v in cats.values())
    score = max(0, 100 - total * 5 - len(regressions) * 3)
    print(f"\nSTABILITY_SCORE: {score}")


if __name__ == "__main__":
    main()
