import { ForbiddenError, UnauthorizedError, SqlBusinessError } from "./errors.ts";
import { callPublicRpc, callPublicVoid } from "./database.ts";
import { createUserClient, type DatabaseClient } from "./supabase.ts";export interface AuthContext {
  accessToken: string;
  userId: string;
  email: string | null;
  tenantId: string | null;
  client: DatabaseClient;
}

export interface TenantMembership {
  tenant_id: string;
  role: string;
  is_active: boolean;
  tenant_status: string;
  tenant_name?: string;
}

/** Extract Bearer token from Authorization header. */
export function extractBearerToken(req: Request): string {
  const header = req.headers.get("Authorization");
  if (!header?.startsWith("Bearer ")) {
    throw new UnauthorizedError("Missing or invalid Authorization header");
  }
  const token = header.slice(7).trim();
  if (!token) {
    throw new UnauthorizedError("Empty bearer token");
  }
  return token;
}

/** Validate JWT and return authenticated user context. */
export async function requireAuth(req: Request): Promise<AuthContext> {
  const accessToken = extractBearerToken(req);
  const client = createUserClient(accessToken);

  const { data, error } = await client.auth.getUser(accessToken);
  if (error || !data.user) {
    throw new UnauthorizedError(error?.message ?? "Invalid or expired token");
  }

  const tenantId =
    (data.user.app_metadata?.tenant_id as string | undefined) ?? null;

  return {
    accessToken,
    userId: data.user.id,
    email: data.user.email ?? null,
    tenantId,
    client,
  };
}

/** Require active tenant in JWT app_metadata.tenant_id. */
export function requireTenant(auth: AuthContext): string {
  if (!auth.tenantId) {
    throw new ForbiddenError(
      "No active tenant. Call auth/switch-tenant before tenant-scoped operations.",
    );
  }
  return auth.tenantId;
}

/** Verify tenant access via public.has_tenant_access (SQL SSOT). */
export async function verifyTenantAccess(
  auth: AuthContext,
  tenantId: string,
): Promise<void> {
  const allowed = await callPublicRpc<boolean>(
    auth.client,
    "has_tenant_access",
    { p_public_tenant_id: tenantId },
  );
  if (!allowed) {
    throw new ForbiddenError("No access to the requested tenant");
  }
}

/** @deprecated Enforced inside SQL module_api via edge_require_manager. Do not call from Edge handlers. */
export async function requireManager(auth: AuthContext): Promise<void> {
  try {
    await callPublicVoid(auth.client, "edge_require_manager");
  } catch (error) {
    if (error instanceof SqlBusinessError) {
      throw new ForbiddenError(error.message);
    }
    throw error;
  }
}

/** @deprecated Enforced inside SQL module_api via edge_require_admin. Do not call from Edge handlers. */
export async function requireAdmin(auth: AuthContext): Promise<void> {
  try {
    await callPublicVoid(auth.client, "edge_require_admin");
  } catch (error) {
    if (error instanceof SqlBusinessError) {
      throw new ForbiddenError(error.message);
    }
    throw error;
  }
}

/** Resolve active tenant from JWT app_metadata.tenant_id (SQL SSOT via switch-tenant). */
export async function resolveTenantId(
  _req: Request,
  auth: AuthContext,
): Promise<string> {
  const tenantId = requireTenant(auth);
  await verifyTenantAccess(auth, tenantId);
  return tenantId;
}
