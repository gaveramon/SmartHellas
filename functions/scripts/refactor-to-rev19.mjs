/**
 * Generate REV19 handler files from legacy switch-case index backups.
 * Run: node supabase/functions/scripts/refactor-to-rev19.mjs
 */
import fs from "node:fs";
import path from "node:path";

const FUNCTIONS_DIR = path.join(import.meta.dirname, "..");
const BACKUP_SUFFIX = ".legacy-index.ts";

const MODULES = [
  "devices",
  "booking",
  "locks",
  "integrations",
  "operations",
  "preconfig",
  "logistics",
  "commerce",
  "portal",
  "onboarding",
  "optimization",
  "monetization",
  "crm",
  "jobs",
];

const PUBLIC_ROUTES = {
  integrations: ["oauth-callback"],
};

const JOB_MODULES = new Set(["jobs"]);

function toHandlerFileName(route) {
  return `${route.replace(/-/g, "_")}.ts`;
}

function toHandlerExportName(route) {
  return route
    .split("-")
    .map((part, i) =>
      i === 0 ? part : part.charAt(0).toUpperCase() + part.slice(1)
    )
    .join("") + "Handler";
}

function parseAllImports(source) {
  const imports = [];
  const importRe = /^import\s[\s\S]*?from\s+["'][^"']+["'];?\s*/gm;
  let m;
  while ((m = importRe.exec(source)) !== null) {
    imports.push(m[0].trim());
  }
  return imports;
}

function extractSwitchCases(source) {
  const switchMatch = source.match(
    /switch\s*\(\s*route\s*\)\s*\{([\s\S]*?)\n\s*default\s*:/,
  );
  if (!switchMatch) return [];

  const switchBody = switchMatch[1];
  const caseStarts = [...switchBody.matchAll(/case\s+"([^"]+)"\s*:/g)];
  const cases = [];

  for (let i = 0; i < caseStarts.length; i++) {
    const route = caseStarts[i][1];
    const start = caseStarts[i].index + caseStarts[i][0].length;
    const end = i + 1 < caseStarts.length
      ? caseStarts[i + 1].index
      : switchBody.length;
    let body = switchBody.slice(start, end).trim();
    if (body.endsWith("}")) body = body.slice(0, -1).trim();
    cases.push({ route, body });
  }
  return cases;
}

function extractPreSwitchBlocks(source) {
  const blocks = [];
  const preSwitch = source.split(/switch\s*\(\s*route\s*\)/)[0];
  const routeIfRe =
    /if\s*\(\s*route\s*===\s*"([^"]+)"\s*\)\s*\{([\s\S]*?)\n\s*\}\n\n\s*const auth/s;
  const m = routeIfRe.exec(preSwitch);
  if (m) {
    let body = m[2].trim();
    body = body
      .replace(/^\s*const logger = createLogger\([^)]*\);\s*/m, "")
      .replace(/^\s*logger\.info\([^)]*\);\s*/m, "");
    blocks.push({ route: m[1], body });
  }
  return blocks;
}

function extractLocalHelpers(source) {
  const serveIdx = source.indexOf("Deno.serve");
  const preServe = source.slice(0, serveIdx);
  const helpers = [];
  const fnRe = /^function\s+(\w+)\([\s\S]*?\n\}\n/gm;
  let m;
  while ((m = fnRe.exec(preServe)) !== null) {
    helpers.push({ name: m[1], code: m[0] });
  }
  return helpers;
}

function bodyUsesSymbol(body, symbol) {
  return new RegExp(`\\b${symbol}\\b`).test(body);
}

function filterNamedImport(imp, body) {
  const fromMatch = imp.match(/from\s+["']([^"']+)["']/);
  if (!fromMatch) return null;
  const namedMatch = imp.match(/\{([\s\S]+)\}/);
  if (!namedMatch) return null;
  const kept = namedMatch[1]
    .split(",")
    .map((p) => p.trim())
    .filter(Boolean)
    .filter((p) => {
      const name = p.split(/\s+as\s+/)[0].trim();
      return bodyUsesSymbol(body, name);
    });
  if (kept.length === 0) return null;
  const fromPath = fromMatch[1].replace(/^\.\//, "../");
  return `import { ${kept.join(", ")} } from "${fromPath}";`;
}

function buildHandlerImports(body, allImports, helpers) {
  const lines = [];
  const errorSyms = ["ValidationError", "NotFoundError", "AppError"].filter((s) =>
    bodyUsesSymbol(body, s)
  );
  if (errorSyms.length) {
    lines.push(`import { ${errorSyms.join(", ")} } from "../../shared/errors.ts";`);
  }
  const responseSyms = ["success", "failure"].filter((s) => bodyUsesSymbol(body, s));
  if (responseSyms.length) {
    lines.push(`import { ${responseSyms.join(", ")} } from "../../shared/response.ts";`);
  }

  for (const imp of allImports) {
    if (
      imp.includes("./service.ts") ||
      imp.includes("./validation.ts")
    ) {
      const filtered = filterNamedImport(imp, body);
      if (filtered) lines.push(filtered);
    }
  }

  const usedHelpers = helpers.filter((h) => bodyUsesSymbol(body, h.name));
  if (usedHelpers.length) {
    for (const h of usedHelpers) {
      if (!bodyUsesSymbol(body, h.name)) continue;
      if (h.name === "parseLimitQuery") continue;
    }
  }

  if (bodyUsesSymbol(body, "parseLimitQuery")) {
    lines.push(`import { parseLimitQuery } from "../validation.ts";`);
  }

  return lines;
}

function buildHandlerFile(moduleName, route, body, allImports, helpers, isJob) {
  const exportName = toHandlerExportName(route);
  const ctxType = isJob ? "JobHandlerContext" : "HandlerContext";
  const importLines = buildHandlerImports(body, allImports, helpers);

  const usedHelpers = helpers.filter(
    (h) => bodyUsesSymbol(body, h.name) && h.name !== "parseLimitQuery",
  );

  const destructuring = isJob
    ? "const { req, logger, correlationId } = ctx;"
    : "const { req, auth, logger } = ctx;";

  const lines = [
    `import type { ${ctxType} } from "../core/index.ts";`,
    ...importLines,
  ];

  if (usedHelpers.length) {
    lines.push("");
    for (const h of usedHelpers) {
      lines.push(h.code.trim());
    }
  }

  lines.push(
    "",
    `export const ${exportName} = async (ctx: ${ctxType}) => {`,
    `  ${destructuring}`,
    ...body.split("\n").map((l) => `  ${l}`),
    `};`,
    "",
  );

  return lines.join("\n");
}

function buildRouteTs(moduleName, routes) {
  const imports = routes
    .map(
      (r) =>
        `import { ${toHandlerExportName(r.route)} } from "./handlers/${toHandlerFileName(r.route)}";`,
    )
    .join("\n");

  const mapType = JOB_MODULES.has(moduleName)
    ? "JobRouteHandlerMap"
    : "RouteHandlerMap";

  const entries = routes
    .map((r) => `  "${r.route}": ${toHandlerExportName(r.route)},`)
    .join("\n");

  return `import { createRouteResolver } from "../shared/core/index.ts";
import type { ${mapType} } from "../shared/core/index.ts";
${imports}

export const resolveRoute = createRouteResolver("${moduleName}");

export const routeHandlers: ${mapType} = {
${entries}
};
`;
}

function buildIndexTs(moduleName) {
  if (JOB_MODULES.has(moduleName)) {
    return `import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createJobApp } from "../shared/core/index.ts";
import { requireJobAuth } from "../shared/job-auth.ts";
import { resolveRoute, routeHandlers } from "./route.ts";

const FUNCTION_NAME = "${moduleName}";

Deno.serve(
  createJobApp({
    functionName: FUNCTION_NAME,
    resolveRoute,
    handlers: routeHandlers,
    authenticate: requireJobAuth,
  }),
);
`;
  }

  const publicRoutes = PUBLIC_ROUTES[moduleName];
  const publicLine = publicRoutes
    ? `\n    publicRoutes: new Set(${JSON.stringify(publicRoutes)}),`
    : "";

  return `import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createAuthenticatedApp } from "../shared/core/index.ts";
import { resolveRoute, routeHandlers } from "./route.ts";

const FUNCTION_NAME = "${moduleName}";

Deno.serve(
  createAuthenticatedApp({
    functionName: FUNCTION_NAME,
    resolveRoute,
    handlers: routeHandlers,${publicLine}
  }),
);
`;
}

function buildCoreIndex(isJob) {
  if (isJob) {
    return `export type {
  JobHandlerContext,
  JobRouteHandler,
  JobRouteHandlerMap,
  EdgeLogger,
} from "../../shared/core/index.ts";

export { createRouteResolver, lookupHandler } from "../../shared/core/index.ts";
`;
  }
  return `export type {
  HandlerContext,
  RouteHandler,
  RouteHandlerMap,
  EdgeLogger,
} from "../../shared/core/index.ts";

export { withMethod, dispatchMethod, createRouteResolver, lookupHandler } from "../../shared/core/index.ts";
`;
}

function buildMiddlewareIndex() {
  return `export {
  buildAuthenticatedContext,
  requireAuth,
  requireTenant,
  requireManager,
  requireAdmin,
  verifyTenantAccess,
  resolveTenantId,
  type AuthContext,
} from "../../shared/middleware/index.ts";
`;
}

function processModule(moduleName) {
  const moduleDir = path.join(FUNCTIONS_DIR, moduleName);
  const backupPath = path.join(moduleDir, BACKUP_SUFFIX);
  if (!fs.existsSync(backupPath)) {
    console.warn(`Skip ${moduleName}: no ${BACKUP_SUFFIX}`);
    return;
  }

  const source = fs.readFileSync(backupPath, "utf8");
  const isJob = JOB_MODULES.has(moduleName);
  const cases = extractSwitchCases(source);
  const preSwitch = extractPreSwitchBlocks(source);
  const routes = [...preSwitch, ...cases];
  const helpers = extractLocalHelpers(source);
  const allImports = parseAllImports(source);

  const handlersDir = path.join(moduleDir, "handlers");
  fs.mkdirSync(handlersDir, { recursive: true });
  fs.mkdirSync(path.join(moduleDir, "core"), { recursive: true });
  fs.mkdirSync(path.join(moduleDir, "middleware"), { recursive: true });

  for (const route of routes) {
    fs.writeFileSync(
      path.join(handlersDir, toHandlerFileName(route.route)),
      buildHandlerFile(
        moduleName,
        route.route,
        route.body,
        allImports,
        helpers,
        isJob,
      ),
    );
  }

  fs.writeFileSync(path.join(moduleDir, "route.ts"), buildRouteTs(moduleName, routes));
  fs.writeFileSync(path.join(moduleDir, "core", "index.ts"), buildCoreIndex(isJob));
  fs.writeFileSync(
    path.join(moduleDir, "middleware", "index.ts"),
    buildMiddlewareIndex(),
  );
  fs.writeFileSync(path.join(moduleDir, "index.ts"), buildIndexTs(moduleName));

  console.log(`✓ ${moduleName}: ${routes.length} handlers`);
}

for (const mod of MODULES) {
  processModule(mod);
}

console.log("\nDone.");
