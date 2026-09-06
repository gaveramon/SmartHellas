import { config } from "./config.ts";
import { ExternalApiError } from "./errors.ts";

const AQARA_API = "https://open-cn.aqara.com/v3.0/open/api";

export interface AqaraRequestOptions {
  appId: string;
  appKey: string;
  accessToken?: string;
}

/** Build signed Aqara Open API request. Device orchestration only — rules in SQL. */
export async function aqaraRequest<T>(
  intent: string,
  payload: Record<string, unknown>,
  options?: Partial<AqaraRequestOptions>,
): Promise<T> {
  const appId = options?.appId ?? config.aqaraAppId();
  const appKey = options?.appKey ?? config.aqaraAppKey();

  if (!appId || !appKey) {
    throw new ExternalApiError("Aqara credentials not configured");
  }

  const time = String(Math.floor(Date.now() / 1000));
  const body = JSON.stringify({ intent, ...payload });
  const sign = await aqaraSign(appKey, time, body);

  const response = await fetch(AQARA_API, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Appid: appId,
      Time: time,
      Sign: sign,
      ...(options?.accessToken ? { Accesstoken: options.accessToken } : {}),
    },
    body,
  });

  const data = await response.json();
  if (!response.ok || data.code !== 0) {
    throw new ExternalApiError(
      data.message ?? "Aqara API request failed",
      { provider: "aqara", code: data.code },
    );
  }
  return data as T;
}

async function aqaraSign(
  appKey: string,
  time: string,
  body: string,
): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(appKey),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(time + body),
  );
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
