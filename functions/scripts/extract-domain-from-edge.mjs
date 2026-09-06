/**
 * Extract domain SSOT functions from Edge *_api migrations and build thin Edge wrappers.
 * Run: node supabase/functions/scripts/extract-domain-from-edge.mjs
 */
import fs from "node:fs";
import path from "node:path";

const migrationsDir = path.join(import.meta.dirname, "../../migrations");

const API_SPECS = [
  {
    file: "018_edge_rpc_devices_rev19.sql",
    apiName: "devices_api",
    domainName: "devices_domain",
    migration: "024_devices_extensions_rev19.sql",
    version: "REV19.DOMAIN.DEVICES.EXT",
    title: "003 Property & Device Engine extensions",
    extraCalls: { assign_device_to_room: "devices_assign_device_to_room" },
  },
  {
    file: "019_edge_rpc_booking_locks_rev19.sql",
    apis: [
      { apiName: "booking_api", domainName: "booking_domain" },
      { apiName: "locks_api", domainName: "locks_domain" },
    ],
    migration: "025_booking_locks_extensions_rev19.sql",
    version: "REV19.DOMAIN.BOOKING_LOCKS.EXT",
    title: "004 Booking & Lock Engine extensions",
  },
  {
    file: "020_edge_rpc_commerce_logistics_rev19.sql",
    apis: [
      { apiName: "commerce_api", domainName: "commerce_domain" },
      { apiName: "logistics_api", domainName: "logistics_domain" },
    ],
    migration: "026_commerce_logistics_extensions_rev19.sql",
    version: "REV19.DOMAIN.COMMERCE_LOGISTICS.EXT",
    title: "009 Commerce + 008 Logistics extensions",
    extraCalls: {
      change_subscription_plan: "commerce_change_subscription_plan",
      dispatch_fulfilment_order: "logistics_dispatch_fulfilment_order",
    },
  },
  {
    file: "022_edge_rpc_crm_rev19.sql",
    apiName: "crm_api",
    domainName: "crm_domain",
    migration: "028_crm_extensions_rev19.sql",
    version: "REV19.DOMAIN.CRM.EXT",
    title: "015 CRM Engine extensions",
    extraCalls: { edge_soft_delete_row: "crm_soft_delete_row" },
  },
  {
    file: "021_edge_rpc_modules_rev19.sql",
    apis: [
      { apiName: "portal_api", domainName: "portal_domain" },
      { apiName: "onboarding_api", domainName: "onboarding_domain" },
      { apiName: "optimization_api", domainName: "optimization_domain" },
      { apiName: "monetization_api", domainName: "monetization_domain" },
      { apiName: "operations_api", domainName: "operations_domain" },
      { apiName: "preconfig_api", domainName: "preconfig_domain" },
      { apiName: "integrations_api", domainName: "integrations_domain" },
      { apiName: "auth_api", domainName: "auth_domain" },
    ],
    migration: "027_module_extensions_rev19.sql",
    version: "REV19.DOMAIN.MODULES.EXT",
    title: "010–011–012–013–006–007–005–002 module extensions",
  },
];

const EDGE_GUARD_RE =
  /^\s*perform public\.edge_require_(tenant|manager|admin)\(\);\s*$/;

function extractFunctionBody(sql, funcName) {
  const re = new RegExp(
    `create or replace function public\\.${funcName}\\([\\s\\S]*?\\$\\$\\s*([\\s\\S]*?)\\s*\\$\\$;`,
    "i",
  );
  const m = sql.match(re);
  if (!m) throw new Error(`Function ${funcName} not found`);
  return m[1].trim();
}

function stripEdgeGuards(body) {
  return body
    .split("\n")
    .filter((line) => !EDGE_GUARD_RE.test(line))
    .join("\n");
}

function replaceCalls(body, extraCalls = {}) {
  let out = body;
  for (const [from, to] of Object.entries(extraCalls)) {
    out = out.replaceAll(`public.${from}`, `public.${to}`);
  }
  return out;
}

function buildGuardCase(body) {
  const guards = new Map();
  const whenRe = /when '([^']+)' then/g;
  const lines = body.split("\n");
  let currentOps = [];
  let i = 0;

  while (i < lines.length) {
    const whenMatch = lines[i].match(/^\s*when '([^']+)' then\s*$/);
    if (whenMatch) {
      currentOps = [whenMatch[1]];
      i++;
      continue;
    }
    const guardMatch = lines[i].match(EDGE_GUARD_RE);
    if (guardMatch && currentOps.length) {
      const guard = guardMatch[1];
      if (!guards.has(guard)) guards.set(guard, []);
      guards.get(guard).push(...currentOps);
      currentOps = [];
      i++;
      continue;
    }
    if (lines[i].match(/^\s*else\s*$/)) currentOps = [];
    i++;
  }

  const parts = [];
  for (const [guard, ops] of guards) {
    const unique = [...new Set(ops)];
    parts.push(
      `        when ${unique.map((o) => `'${o}'`).join(", ")} then\n            perform public.edge_require_${guard}();`,
    );
  }
  return parts.join("\n");
}

function buildThinWrapper(apiName, domainName, originalBody) {
  const guardCase = buildGuardCase(originalBody);
  return `
create or replace function public.${apiName}(
    p_op text,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
${guardCase}
        else
            raise exception 'unknown ${apiName} operation: %', p_op;
    end case;

    return public.${domainName}(p_op, p_payload);
end;
$$;

revoke all on function public.${apiName}(text, jsonb) from public;
grant execute on function public.${apiName}(text, jsonb) to authenticated, service_role;
`;
}

function buildDomainFunction(domainName, strippedBody) {
  return `
create or replace function public.${domainName}(
    p_op text,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
${strippedBody}
$$;

revoke all on function public.${domainName}(text, jsonb) from public;
grant execute on function public.${domainName}(text, jsonb) to authenticated, service_role;
`;
}

function processApi(sql, spec, apiSpec, extraCalls) {
  const body = extractFunctionBody(sql, apiSpec.apiName);
  const stripped = replaceCalls(stripEdgeGuards(body), extraCalls);
  const domain = buildDomainFunction(apiSpec.domainName, stripped);
  const thin = buildThinWrapper(apiSpec.apiName, apiSpec.domainName, body);
  return { domain, thin };
}

for (const spec of API_SPECS) {
  const sql = fs.readFileSync(path.join(migrationsDir, spec.file), "utf8");
  const apis = spec.apis ?? [{ apiName: spec.apiName, domainName: spec.domainName }];
  const chunks = [
    `-- =====================================================`,
    `-- ${spec.migration}`,
    `-- ${spec.title}`,
    `-- Domain SSOT: business logic extracted from Edge ${spec.file}`,
    `-- =====================================================`,
    "",
    `insert into platform.schema_migrations (migration_name, version, rollback_available)`,
    `values ('${spec.migration.replace(".sql", "")}', '${spec.version}', false)`,
    `on conflict (version) do nothing;`,
    "",
  ];

  const thinChunks = [];

  for (const apiSpec of apis) {
    const { domain, thin } = processApi(sql, spec, apiSpec, spec.extraCalls ?? {});
    chunks.push(domain);
    thinChunks.push(thin);
  }

  fs.writeFileSync(path.join(migrationsDir, spec.migration), chunks.join("\n"));
  console.log(`Wrote ${spec.migration}`);
}

// Edge thin wrappers migration
const thinAll = [
  `-- =====================================================`,
  `-- 029_edge_api_thin_wrappers_rev19.sql`,
  `-- Pure Edge API layer: guards only, delegates to *_domain SSOT`,
  `-- =====================================================`,
  "",
  `insert into platform.schema_migrations (migration_name, version, rollback_available)`,
  `values ('029_edge_api_thin_wrappers_rev19', 'REV19.EDGE.API.THIN', false)`,
  `on conflict (version) do nothing;`,
  "",
];

for (const spec of API_SPECS) {
  const sql = fs.readFileSync(path.join(migrationsDir, spec.file), "utf8");
  const apis = spec.apis ?? [{ apiName: spec.apiName, domainName: spec.domainName }];
  for (const apiSpec of apis) {
    const body = extractFunctionBody(sql, apiSpec.apiName);
    thinAll.push(buildThinWrapper(apiSpec.apiName, apiSpec.domainName, body));
  }
}

fs.writeFileSync(
  path.join(migrationsDir, "029_edge_api_thin_wrappers_rev19.sql"),
  thinAll.join("\n"),
);
console.log("Wrote 029_edge_api_thin_wrappers_rev19.sql");
