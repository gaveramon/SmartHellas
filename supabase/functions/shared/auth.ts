import { ForbiddenError, UnauthorizedError, SqlBusinessError } from "./errors.ts";

import { callPublicRpc, callPublicVoid } from "./database.ts";

import { createUserClient, type DatabaseClient } from "./supabase.ts";

export interface AuthContext {

  accessToken: string;

  userId: string;

  email: string | null;

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



  return {

    accessToken,

    userId: data.user.id,

    email: data.user.email ?? null,

    client,

  };

}



/** Normalize authenticated user id — single Edge identity field. */

export function getUserId(auth: { userId?: string; user?: { id?: string } }): string {

  const userId = auth.userId ?? auth.user?.id;

  if (!userId) {

    throw new UnauthorizedError("authentication required");

  }

  return userId;

}



async function resolve_active_tenant(userId: string, client: DatabaseClient): Promise<string | null> {

  return await callPublicRpc<string | null>(

    client,

    "resolve_active_tenant",

    { p_user_id: userId },

  );

}



/** Require active tenant via REV21 sole authority (resolve_active_tenant). */

export async function requireTenant(auth: AuthContext): Promise<string> {

  const userId = getUserId(auth);

  const tenantId = await resolve_active_tenant(userId, auth.client);

  if (!tenantId) {

    throw new Error("NO_ACTIVE_TENANT");

  }

  return tenantId;

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



/** @deprecated Use requireTenant(auth) — sole REV21 tenant resolution path. */

export async function resolveTenantId(

  _req: Request,

  auth: AuthContext,

): Promise<string> {

  return await requireTenant(auth);

}


