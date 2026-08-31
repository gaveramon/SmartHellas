// ============================================================
// SMARTHELLAS
// GENERIC INBOUND WEBHOOK EDGE FUNCTION
//
// Architecture:
//
//   EXTERNAL PROVIDER
//          |
//          v
//   EDGE FUNCTION
//          |
//          v
//   000 PLATFORM
//   external_webhooks
//          |
//          | tenant_id
//          v
//   007 INTEGRATION ENGINE
//   provider identity resolution
//          |
//          | device_id
//          v
//   006 DEVICE TELEMETRY
//   device_telemetry_raw
//
// SSOT:
//
// 000 = platform / external webhook boundary
// 004 = device/domain SSOT
// 006 = raw telemetry SSOT
// 007 = provider/device integration identity
//
// IMPORTANT:
//
// This function is orchestration only.
//
// It MUST NOT:
// - create devices
// - modify device domain state
// - interpret telemetry
// - calculate metrics
// - calculate energy usage
// - execute automations
// - apply business rules
// - modify normalized telemetry
//
// ============================================================


import { createClient } from "https://esm.sh/@supabase/supabase-js@2";


// ============================================================
// 1. SUPABASE CLIENT
// ============================================================

const SUPABASE_URL =
  Deno.env.get("SUPABASE_URL");

const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");


if (
  !SUPABASE_URL ||
  !SUPABASE_SERVICE_ROLE_KEY
) {
  throw new Error(
    "Missing Supabase environment configuration"
  );
}


const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY
);


// ============================================================
// 2. TYPES
// ============================================================


type JsonObject =
  Record<string, unknown>;


type ProviderWebhookContext = {

  providerCode: string;

  externalEventId: string;

  eventType: string | null;

  externalAccountId: string | null;

  externalDeviceId: string | null;

  observedAt: string | null;

  payload: JsonObject;
};


type ProviderDeviceIdentity = {

  externalId: string;

  hardwareId: string;

  metadata?: JsonObject;
};


type ProviderIdentityResolverContext = {

  tenantId: string;

  providerCode: string;

  externalId: string;

  accessToken: string | null;
};


interface ProviderAdapter {

  verifyWebhook(
    req: Request
  ): Promise<boolean>;

  parseWebhook(
    payload: JsonObject
  ): ProviderWebhookContext;

  resolveDeviceIdentity(
    context: ProviderIdentityResolverContext
  ): Promise<ProviderDeviceIdentity>;
}


// ============================================================
// 3. HTTP ERROR
// ============================================================


class HttpError extends Error {

  status: number;

  constructor(
    status: number,
    message: string
  ) {

    super(message);

    this.status = status;
  }
}


// ============================================================
// 4. GENERIC JSON RESPONSE
// ============================================================


function jsonResponse(
  body: JsonObject,
  status = 200
): Response {

  return new Response(
    JSON.stringify(body),
    {
      status,

      headers: {
        "Content-Type":
          "application/json",
      },
    }
  );
}


// ============================================================
// 5. GENERIC VALUE HELPERS
// ============================================================


function asString(
  value: unknown
): string | null {

  if (
    typeof value !== "string"
  ) {
    return null;
  }

  const trimmed =
    value.trim();

  return trimmed === ""
    ? null
    : trimmed;
}


function asRecord(
  value: unknown
): JsonObject {

  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value)
  ) {
    throw new HttpError(
      400,
      "Webhook payload must be a JSON object"
    );
  }

  return value as JsonObject;
}


// ============================================================
// 6. PROVIDER REGISTRY
//
// The generic handler knows only ProviderAdapter.
//
// Provider-specific implementation lives below.
// ============================================================


const providerAdapters:
  Record<string, ProviderAdapter> = {};


// ============================================================
// 7. AQARA ADAPTER
// ============================================================


class AqaraAdapter
  implements ProviderAdapter {


  // ==========================================================
  // 7A. AQARA WEBHOOK AUTHENTICATION
  // ==========================================================

  async verifyWebhook(
    req: Request
  ): Promise<boolean> {

    const appkey =
      req.headers.get("appkey");

    const nonce =
      req.headers.get("nonce");

    const time =
      req.headers.get("time");

    const receivedSign =
      req.headers.get("sign");


    if (
      !appkey ||
      !nonce ||
      !time ||
      !receivedSign
    ) {
      return false;
    }


    const configuredAppKey =
      Deno.env.get(
        "AQARA_APP_KEY"
      );


    if (
      !configuredAppKey ||
      appkey !== configuredAppKey
    ) {
      return false;
    }


    return verifyAqaraSignature(
      appkey,
      nonce,
      time,
      receivedSign
    );
  }


  // ==========================================================
  // 7B. AQARA WEBHOOK PARSER
  //
  // Only extracts identity/event metadata.
  //
  // It does NOT interpret telemetry.
  // ==========================================================

  parseWebhook(
    payload: JsonObject
  ): ProviderWebhookContext {


    const externalAccountId =
      asString(
        payload["openId"]
      );


    const externalEventId =
      asString(
        payload["msgId"]
      ) ??
      crypto.randomUUID();


    const eventType =
      asString(
        payload["msgType"]
      ) ??
      asString(
        payload["eventType"]
      );


    const externalDeviceId =
      extractAqaraExternalDeviceId(
        payload
      );


    const observedAt =
      extractProviderTimestamp(
        payload
      );


    return {

      providerCode:
        "aqara",

      externalEventId,

      eventType,

      externalAccountId,

      externalDeviceId,

      observedAt,

      payload,
    };
  }


  // ==========================================================
  // 7C. AQARA DEVICE IDENTITY RESOLUTION
  //
  // did
  //  ↓
  // Aqara device detail API
  //  ↓
  // did + mac
  //
  // mac becomes the stable provider hardware identity.
  // ==========================================================

  async resolveDeviceIdentity(
    context: ProviderIdentityResolverContext
  ): Promise<ProviderDeviceIdentity> {


    if (
      !context.externalId
    ) {
      throw new Error(
        "Aqara external device ID is required"
      );
    }


    if (
      !context.accessToken
    ) {
      throw new Error(
        "Aqara access token is required for device identity resolution"
      );
    }


    const detail =
      await queryAqaraDeviceDetail(
        context.accessToken,
        context.externalId
      );


    const externalId =
      asString(
        detail["did"]
      );


    const hardwareId =
      asString(
        detail["mac"]
      );


    if (!externalId) {

      throw new Error(
        "Aqara device detail response contains no did"
      );
    }


    if (!hardwareId) {

      throw new Error(
        "Aqara device detail response contains no mac"
      );
    }


    return {

      externalId,

      hardwareId,

      metadata: {

        parentDid:
          detail["parentDid"] ?? null,

        model:
          detail["model"] ?? null,

        modelName:
          detail["modelName"] ?? null,

        firmwareVersion:
          detail["firmwareVersion"] ?? null,
      },
    };
  }
}


// ============================================================
// 8. REGISTER AQARA
// ============================================================


providerAdapters["aqara"] =
  new AqaraAdapter();


// ============================================================
// 9. AQARA SIGNATURE
// ============================================================


async function verifyAqaraSignature(
  appkey: string,
  nonce: string,
  time: string,
  receivedSign: string
): Promise<boolean> {


  const params = [

    ["appkey", appkey],

    ["nonce", nonce],

    ["time", time],

  ].sort(
    ([a], [b]) =>
      a.localeCompare(b)
  );


  const signString =
    params
      .map(
        ([key, value]) =>
          `${key}=${value}`
      )
      .join("&")
      .toLowerCase();


  const expectedSign =
    await md5(
      signString
    );


  return (
    expectedSign.toLowerCase() ===
    receivedSign.toLowerCase()
  );
}


// ============================================================
// 10. MD5
// ============================================================


async function md5(
  input: string
): Promise<string> {

  const buffer =
    await crypto.subtle.digest(
      "MD5",
      new TextEncoder().encode(
        input
      )
    );


  return Array
    .from(
      new Uint8Array(buffer)
    )
    .map(
      byte =>
        byte
          .toString(16)
          .padStart(2, "0")
    )
    .join("");
}


// ============================================================
// 11. AQARA DEVICE ID EXTRACTION
// ============================================================


function extractAqaraExternalDeviceId(
  payload: JsonObject
): string | null {


  const directCandidates = [

    payload["did"],

    payload["deviceId"],

    payload["deviceDid"],

  ];


  for (
    const candidate
    of directCandidates
  ) {

    const value =
      asString(candidate);

    if (value) {
      return value;
    }
  }


  const device =
    payload["device"];


  if (
    typeof device === "object" &&
    device !== null &&
    !Array.isArray(device)
  ) {

    const deviceRecord =
      device as JsonObject;


    const nestedCandidates = [

      deviceRecord["did"],

      deviceRecord["deviceId"],

    ];


    for (
      const candidate
      of nestedCandidates
    ) {

      const value =
        asString(candidate);

      if (value) {
        return value;
      }
    }
  }


  return null;
}


// ============================================================
// 12. PROVIDER TIMESTAMP EXTRACTION
//
// Generic metadata extraction only.
//
// No semantic interpretation.
// ============================================================


function extractProviderTimestamp(
  payload: JsonObject
): string | null {


  const candidates = [

    payload["timestamp"],

    payload["time"],

    payload["eventTime"],

    payload["createTime"],

    payload["occurredAt"],

  ];


  for (
    const candidate
    of candidates
  ) {


    if (
      typeof candidate === "number"
    ) {

      const milliseconds =
        candidate < 10_000_000_000
          ? candidate * 1000
          : candidate;


      const date =
        new Date(
          milliseconds
        );


      if (
        !Number.isNaN(
          date.getTime()
        )
      ) {

        return date.toISOString();
      }
    }


    if (
      typeof candidate === "string" &&
      candidate.trim() !== ""
    ) {

      const date =
        new Date(candidate);


      if (
        !Number.isNaN(
          date.getTime()
        )
      ) {

        return date.toISOString();
      }
    }
  }


  return null;
}


// ============================================================
// 13. 000 — STORE EXTERNAL WEBHOOK
//
// 000 owns the inbound external webhook boundary.
//
// IMPORTANT:
// The database function must return BOTH:
//
//   webhook_id
//   tenant_id
//
// so that the Edge Function does not duplicate
// tenant-resolution logic.
// ============================================================


type WebhookIngestionResult = {

  webhookId: string;

  tenantId: string;
};


async function storeExternalWebhook(
  context: ProviderWebhookContext
): Promise<WebhookIngestionResult> {


  const {
    data,
    error,
  } =
    await supabase.rpc(
      "ingest_external_webhook",
      {

        p_source:
          context.providerCode,

        p_external_event_id:
          context.externalEventId,

        p_event_type:
          context.eventType,

        p_payload:
          context.payload,

        p_tenant_id:
          null,

        p_external_account_id:
          context.externalAccountId,
      }
    );


  if (error) {

    throw new Error(
      `External webhook ingestion failed: ${error.message}`
    );
  }


  if (!data) {

    throw new Error(
      "External webhook ingestion returned no result"
    );
  }


  /*
   * Expected RPC result:
   *
   * {
   *   webhook_id: "...",
   *   tenant_id: "..."
   * }
   */


  const result =
    asRecord(data);


  const webhookId =
    asString(
      result["webhook_id"]
    );


  const tenantId =
    asString(
      result["tenant_id"]
    );


  if (!webhookId) {

    throw new Error(
      "Webhook ingestion returned no webhook_id"
    );
  }


  if (!tenantId) {

    throw new Error(
      "Webhook ingestion returned no tenant_id"
    );
  }


  return {

    webhookId,

    tenantId,
  };
}


// ============================================================
// 14. 007 — LOOKUP CURRENT EXTERNAL DEVICE ID
//
// First resolution attempt.
//
// If the current Aqara did is already mapped,
// no Aqara API call is necessary.
// ============================================================


async function resolveDeviceByExternalId(
  tenantId: string,
  providerCode: string,
  externalId: string
): Promise<string | null> {


  const {
    data,
    error,
  } =
    await supabase.rpc(
      "resolve_provider_device_by_external_id",
      {

        p_tenant_id:
          tenantId,

        p_provider_code:
          providerCode,

        p_external_id:
          externalId,
      }
    );


  if (error) {

    throw new Error(
      `Provider device lookup failed: ${error.message}`
    );
  }


  if (
    data === null ||
    data === undefined
  ) {

    return null;
  }


  return String(data);
}


// ============================================================
// 15. PROVIDER ACCESS TOKEN
//
// IMPORTANT:
//
// The token must come from the authorized Aqara account
// belonging to this tenant.
//
// This function does NOT invent or store authorization.
//
// The exact SSOT table/function for OAuth credentials must
// be connected to this function according to 007.
//
// ============================================================


async function getProviderAccessToken(
  tenantId: string,
  providerCode: string
): Promise<string | null> {


  const {
    data,
    error,
  } =
    await supabase.rpc(
      "get_provider_access_token",
      {

        p_tenant_id:
          tenantId,

        p_provider_code:
          providerCode,
      }
    );


  if (error) {

    throw new Error(
      `Provider authorization lookup failed: ${error.message}`
    );
  }


  if (
    data === null ||
    data === undefined
  ) {

    return null;
  }


  return String(data);
}


// ============================================================
// 16. 007 — RESOLVE / RECONCILE DEVICE
//
// Current did unknown?
//
// Then:
//
//   did
//    ↓
//   provider adapter
//    ↓
//   hardware_id
//    ↓
//   device_integration_map
//    ↓
//   device_id
//
// 004 remains device SSOT.
// ============================================================


async function resolveWebhookDevice(
  context: ProviderWebhookContext,
  tenantId: string
): Promise<string> {


  if (
    !context.externalDeviceId
  ) {

    throw new Error(
      `Webhook contains no external device ID for provider ${context.providerCode}`
    );
  }


  // ==========================================================
  // FIRST:
  // Try current provider external ID.
  // ==========================================================

  const existingDeviceId =
    await resolveDeviceByExternalId(
      tenantId,

      context.providerCode,

      context.externalDeviceId
    );


  if (
    existingDeviceId
  ) {

    return existingDeviceId;
  }


  // ==========================================================
  // CURRENT DID UNKNOWN
  //
  // Ask provider adapter for stable identity.
  // ==========================================================


  const adapter =
    providerAdapters[
      context.providerCode
    ];


  if (!adapter) {

    throw new Error(
      `No provider adapter registered for ${context.providerCode}`
    );
  }


  const accessToken =
    await getProviderAccessToken(
      tenantId,
      context.providerCode
    );


  const identity =
    await adapter.resolveDeviceIdentity(
      {

        tenantId,

        providerCode:
          context.providerCode,

        externalId:
          context.externalDeviceId,

        accessToken,
      }
    );


  // ==========================================================
  // GENERIC 007 RECONCILIATION
  // ==========================================================

  const {
    data,
    error,
  } =
    await supabase.rpc(
      "resolve_or_reconcile_provider_device",
      {

        p_tenant_id:
          tenantId,

        p_provider_code:
          context.providerCode,

        p_external_id:
          identity.externalId,

        p_hardware_id:
          identity.hardwareId,
      }
    );


  if (error) {

    throw new Error(
      `Provider device reconciliation failed: ${error.message}`
    );
  }


  if (!data) {

    throw new Error(
      "Provider device reconciliation returned no device_id"
    );
  }


  return String(data);
}


// ============================================================
// 17. 006 — RAW TELEMETRY INGESTION
//
// 006 owns the raw telemetry storage boundary.
//
// The payload is passed unchanged.
//
// No interpretation occurs here.
// ============================================================


async function ingestRawTelemetry(
  context: ProviderWebhookContext,
  tenantId: string,
  deviceId: string
): Promise<string> {


  const {
    data,
    error,
  } =
    await supabase.rpc(
      "ingest_raw_device_telemetry",
      {

        p_tenant_id:
          tenantId,

        p_device_id:
          deviceId,

        p_source:
          context.providerCode,

        p_provider_event_id:
          context.externalEventId,

        p_observed_at:
          context.observedAt,

        p_raw_payload:
          context.payload,
      }
    );


  if (error) {

    throw new Error(
      `Raw telemetry ingestion failed: ${error.message}`
    );
  }


  if (!data) {

    throw new Error(
      "Raw telemetry ingestion returned no telemetry ID"
    );
  }


  return String(data);
}


// ============================================================
// 18. MAIN WEBHOOK HANDLER
// ============================================================


Deno.serve(
  async (
    req: Request
  ): Promise<Response> => {


    try {


      // ======================================================
      // HTTP METHOD
      // ======================================================

      if (
        req.method !== "POST"
      ) {

        throw new HttpError(
          405,
          "Method Not Allowed"
        );
      }


      // ======================================================
      // PROVIDER
      //
      // Current deployment endpoint is Aqara.
      //
      // The handler itself remains provider-agnostic.
      // ======================================================

      const providerCode =
        "aqara";


      const adapter =
        providerAdapters[
          providerCode
        ];


      if (!adapter) {

        throw new HttpError(
          500,
          `No provider adapter registered for ${providerCode}`
        );
      }


      // ======================================================
      // PROVIDER AUTHENTICATION
      // ======================================================

      const validWebhook =
        await adapter.verifyWebhook(
          req
        );


      if (!validWebhook) {

        throw new HttpError(
          401,
          "Invalid provider webhook authentication"
        );
      }


      // ======================================================
      // READ ORIGINAL JSON
      // ======================================================

      const body =
        await req.json();


      const payload =
        asRecord(body);


      // ======================================================
      // PARSE PROVIDER METADATA
      //
      // Payload remains untouched.
      // ======================================================

      const context =
        adapter.parseWebhook(
          payload
        );


      // ======================================================
      // 000
      //
      // STORE EXTERNAL WEBHOOK
      //
      // This also resolves the tenant.
      // ======================================================

      const webhook =
        await storeExternalWebhook(
          context
        );


      // ======================================================
      // 007
      //
      // RESOLVE SMARTHELLAS DEVICE
      // ======================================================

      const deviceId =
        await resolveWebhookDevice(
          context,

          webhook.tenantId
        );


      // ======================================================
      // 006
      //
      // STORE RAW TELEMETRY
      //
      // The original provider payload is stored unchanged.
      // ======================================================

      const telemetryId =
        await ingestRawTelemetry(
          context,

          webhook.tenantId,

          deviceId
        );


      // ======================================================
      // SUCCESS
      // ======================================================

      return jsonResponse(
        {

          code: 0,

          message:
            "Success",

          result: {

            webhook_id:
              webhook.webhookId,

            tenant_id:
              webhook.tenantId,

            provider:
              context.providerCode,

            external_event_id:
              context.externalEventId,

            external_device_id:
              context.externalDeviceId,

            device_id:
              deviceId,

            telemetry_id:
              telemetryId,
          },
        },

        200
      );


    } catch (error) {


      console.error(
        "SmartHellas webhook processing error:",
        error
      );


      if (
        error instanceof HttpError
      ) {

        return jsonResponse(
          {

            code:
              error.status,

            message:
              error.message,

          },

          error.status
        );
      }


      return jsonResponse(
        {

          code: 500,

          message:
            "Internal server error",

        },

        500
      );
    }
  }
);