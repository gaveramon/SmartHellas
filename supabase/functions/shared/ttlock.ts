import { config } from "./config.ts";
import { ExternalApiError } from "./errors.ts";

const TTLOCK_API = "https://api.sciener.com/v2";

export interface TtlockTokenResponse {
  access_token: string;
  expires_in: number;
}

/** Obtain TTLock access token — orchestration only; credential storage is in SQL. */
export async function ttlockGetToken(
  username: string,
  password: string,
): Promise<TtlockTokenResponse> {
  const clientId = config.ttlockClientId();
  const clientSecret = config.ttlockClientSecret();
  if (!clientId || !clientSecret) {
    throw new ExternalApiError("TTLock credentials not configured");
  }

  const body = new URLSearchParams({
    clientId,
    clientSecret,
    username,
    password,
    date: String(Date.now()),
  });

  const response = await fetch(`${TTLOCK_API}/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  const data = await response.json();
  if (!response.ok || data.errcode) {
    throw new ExternalApiError(
      data.errmsg ?? data.description ?? "TTLock token request failed",
      { provider: "ttlock", errcode: data.errcode },
    );
  }
  return data as TtlockTokenResponse;
}

/** Forward lock command to TTLock API. Business rules for when to lock/unlock live in SQL. */
export async function ttlockRequest<T>(
  accessToken: string,
  path: string,
  params: Record<string, string | number | boolean> = {},
): Promise<T> {
  const clientId = config.ttlockClientId();
  if (!clientId) {
    throw new ExternalApiError("TTLock client ID not configured");
  }

  const query = new URLSearchParams({
    clientId,
    accessToken,
    date: String(Date.now()),
    ...Object.fromEntries(
      Object.entries(params).map(([k, v]) => [k, String(v)]),
    ),
  });

  const response = await fetch(`${TTLOCK_API}${path}?${query}`, {
    method: "POST",
  });

  const data = await response.json();
  if (!response.ok || data.errcode) {
    throw new ExternalApiError(
      data.errmsg ?? "TTLock API request failed",
      { provider: "ttlock", errcode: data.errcode },
    );
  }
  return data as T;
}
