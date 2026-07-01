import fs from "node:fs";
import path from "node:path";

const root = path.join(import.meta.dirname, "..");

const MODULE_MAP = {
  booking: "booking",
  locks: "locks",
  commerce: "commerce",
  logistics: "logistics",
  portal: "portal",
  onboarding: "onboarding",
  optimization: "optimization",
  monetization: "monetization",
  operations: "operations",
  preconfig: "preconfig",
  crm: "crm",
};

function camelToSnake(name) {
  return name
    .replace(/([A-Z])/g, "_$1")
    .toLowerCase()
    .replace(/^_/, "");
}

function paramToPayloadKey(paramName) {
  return camelToSnake(paramName);
}

function parseSignature(line) {
  const m = line.match(
    /^export async function (\w+)\(\s*auth: AuthContext(?:,\s*([\s\S]*?))?\):\s*Promise<([\s\S]+)>$/,
  );
  if (!m) return null;

  const name = m[1];
  const paramsRaw = (m[2] ?? "").trim();
  const returnType = m[3].trim();

  const params = [];
  if (paramsRaw) {
    for (const part of paramsRaw.split(",")) {
      const p = part.trim();
      if (!p) continue;
      const pm = p.match(/^(\w+)(\?)?:\s*([\s\S]+)$/);
      if (!pm) continue;
      params.push({ name: pm[1], optional: pm[2] === "?", type: pm[3].trim() });
    }
  }

  return { name, params, returnType };
}

function buildPayload(params) {
  if (params.length === 0) {
    return { prelude: ["tid(auth);"], payload: "{}" };
  }

  const inputParam = params.find(
    (p) => p.name === "input" || p.type.endsWith("Request"),
  );

  if (params.length === 1 && inputParam) {
    return { prelude: [], payload: `{ ...${inputParam.name} }` };
  }

  if (params.length === 1 && params[0].type === "string") {
    const key = paramToPayloadKey(params[0].name);
    return {
      prelude: ["tid(auth);"],
      payload: `{ ${key}: ${params[0].name} }`,
    };
  }

  const prelude = ["tid(auth);"];
  const build = ["const payload: Record<string, unknown> = {};"];
  for (const p of params) {
    const key = paramToPayloadKey(p.name);
    if (p.optional) {
      build.push(`if (${p.name}) payload.${key} = ${p.name};`);
    } else {
      build.push(`payload.${key} = ${p.name};`);
    }
  }
  if (inputParam) {
    build.unshift(`const payload: Record<string, unknown> = { ...${inputParam.name} };`);
    return { prelude, payload: "payload", build };
  }
  return { prelude, payload: "payload", build };
}

function generateFn(module, fn) {
  const op = camelToSnake(fn.name);
  const body = buildPayload(fn.params);

  const paramList = ["auth: AuthContext"];
  for (const p of fn.params) {
    paramList.push(`${p.name}${p.optional ? "?" : ""}: ${p.type}`);
  }

  const lines = [
    `export async function ${fn.name}(${paramList.join(", ")}): Promise<${fn.returnType}> {`,
  ];

  if (body.build) {
    for (const line of body.build) lines.push(`  ${line}`);
  }
  for (const line of body.prelude) lines.push(`  ${line}`);

  lines.push(
    `  return await callModuleApiAuth<${fn.returnType}>(auth, "${module}", "${op}", ${body.payload});`,
  );
  lines.push("}");
  return lines.join("\n");
}

function extractSignaturesFromIndex(indexPath) {
  const text = fs.readFileSync(indexPath, "utf8");
  const marker = 'from "./service.ts"';
  const markerIdx = text.indexOf(marker);
  if (markerIdx < 0) return [];

  const before = text.slice(0, markerIdx);
  const importStart = before.lastIndexOf("import");
  const importBlock = before.slice(importStart);
  const braceMatch = importBlock.match(/\{([\s\S]*)\}\s*$/);
  if (!braceMatch) return [];

  return braceMatch[1]
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s && !s.startsWith("type "));
}

function inferSignature(fnName, folder) {
  const typesPath = path.join(root, folder, "types.ts");
  const typesText = fs.existsSync(typesPath)
    ? fs.readFileSync(typesPath, "utf8")
    : "";

  const cap = fnName.replace(/^[a-z]/, (c) => c.toUpperCase());
  const deleteReturn = "{ deleted: true; id: string }";
  const softDeleteReturn = "{ soft_deleted: true; id: string }";

  if (fnName.startsWith("delete")) {
    return {
      name: fnName,
      params: [{ name: "id", optional: false, type: "string" }],
      returnType: deleteReturn,
    };
  }
  if (fnName === "softDeleteInteraction") {
    return {
      name: fnName,
      params: [{ name: "id", optional: false, type: "string" }],
      returnType: softDeleteReturn,
    };
  }

  if (fnName.startsWith("list")) {
    const rowMatch = typesText.match(new RegExp(`export (?:type|interface) (\\w+Row)\\b`));
    const row = rowMatch?.[1] ?? "unknown";
    return {
      name: fnName,
      params: [],
      returnType: `${row}[]`,
    };
  }

  if (fnName.startsWith("get")) {
    const detailMatch = typesText.match(
      new RegExp(`export (?:type|interface) (${cap.replace(/^Get/, "")}Detail)\\b`),
    );
    const rowMatch = typesText.match(
      new RegExp(`export (?:type|interface) (${cap.replace(/^Get/, "")}Row)\\b`),
    );
    const type = detailMatch?.[1] ?? rowMatch?.[1] ?? "unknown";
    return {
      name: fnName,
      params: [{ name: "id", optional: false, type: "string" }],
      returnType: type,
    };
  }

  if (fnName.startsWith("create")) {
    const req = `Create${cap.replace(/^Create/, "")}Request`;
    const row = cap.replace(/^Create/, "") + "Row";
    const hasReq = typesText.includes(req);
    const hasRow = typesText.includes(row);
    return {
      name: fnName,
      params: hasReq
        ? [{ name: "input", optional: false, type: req }]
        : [],
      returnType: hasRow ? row : "unknown",
    };
  }

  if (fnName.startsWith("update")) {
    const req = `Update${cap.replace(/^Update/, "")}Request`;
    const row = cap.replace(/^Update/, "") + "Row";
    const hasReq = typesText.includes(req);
    const hasRow = typesText.includes(row);
    return {
      name: fnName,
      params: hasReq
        ? [{ name: "input", optional: false, type: req }]
        : [],
      returnType: hasRow ? row : "unknown",
    };
  }

  if (fnName.startsWith("upsert")) {
    const req = `${cap}Request`;
    const row = cap.replace(/^Upsert/, "") + "Row";
    return {
      name: fnName,
      params: [{ name: "input", optional: false, type: req }],
      returnType: row,
    };
  }

  return { name: fnName, params: [], returnType: "unknown" };
}

function collectTypeImports(folder, fns) {
  const typesPath = path.join(root, folder, "types.ts");
  if (!fs.existsSync(typesPath)) return [];

  const typesText = fs.readFileSync(typesPath, "utf8");
  const exported = new Set();
  const re = /^export (?:type|interface) (\w+)/gm;
  let m;
  while ((m = re.exec(typesText)) !== null) exported.add(m[1]);

  const used = new Set();
  for (const fn of fns) {
    if (exported.has(fn.returnType)) used.add(fn.returnType);
    const retInner = fn.returnType.match(/^(\w+)\[\]$/);
    if (retInner && exported.has(retInner[1])) used.add(retInner[1]);
    const nullRet = fn.returnType.match(/^(\w+) \| null$/);
    if (nullRet && exported.has(nullRet[1])) used.add(nullRet[1]);
    for (const p of fn.params) {
      if (exported.has(p.type)) used.add(p.type);
    }
  }
  return [...used].sort();
}

for (const [folder, module] of Object.entries(MODULE_MAP)) {
  const indexPath = path.join(root, folder, "index.ts");
  const servicePath = path.join(root, folder, "service.ts");
  if (!fs.existsSync(indexPath)) continue;

  const fnNames = extractSignaturesFromIndex(indexPath);
  const existingText = fs.existsSync(servicePath)
    ? fs.readFileSync(servicePath, "utf8")
    : "";

  const fns = [];
  for (const fnName of fnNames) {
    const sigLine = existingText
      .split("\n")
      .find((l) => l.startsWith(`export async function ${fnName}(`));
    let parsed = null;
    if (sigLine) {
      const head = sigLine.replace(/\{\s*$/, "").trim();
      parsed = parseSignature(head);
    }
    fns.push(parsed ?? inferSignature(fnName, folder));
  }

  const typeImports = collectTypeImports(folder, fns);
  const importBlock =
    typeImports.length > 0
      ? `import type {\n  ${typeImports.join(",\n  ")},\n} from "./types.ts";`
      : "";

  const header = [
    `import { type AuthContext, requireTenant } from "../shared/auth.ts";`,
    `import { callModuleApiAuth } from "../shared/edge-rpc.ts";`,
    importBlock,
    "",
    "function tid(auth: AuthContext): string {",
    "  return requireTenant(auth);",
    "}",
    "",
  ]
    .filter(Boolean)
    .join("\n");

  const body = fns.map((fn) => generateFn(module, fn)).join("\n\n");
  fs.writeFileSync(servicePath, `${header}${body}\n`);
  console.log(`${folder}: ${fns.length} functions`);
}
