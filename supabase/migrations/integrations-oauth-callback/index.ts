// ============================================================
// SMARTHELLAS
// GENERIC OAUTH CALLBACK EDGE FUNCTION
//
// Responsibility:
// - Receive OAuth authorization callback
// - Validate presence of code + state
// - Delegate token exchange to 007
// - Delegate OAuth completion to 007
// - Return only non-secret completion information
//
// Architecture:
//
//   OAUTH PROVIDER
//        |
//        | code + state
//        v
//   integrations-oauth-callback
//        |
//        v
//   007 integrations_exchange_oauth_tokens()
//        |
//        v
//      VAULT
//        |
//        v
//   007 integrations_complete_oauth()
//        |
//        v
//   tenant_integrations
//
// SSOT:
//
// 007 = OAuth transaction + integration lifecycle
// Vault = OAuth credentials / tokens
// tenant_integrations = tenant integration SSOT
//
// MUST NOT:
// - accept tenant_id
// - accept provider_code
// - accept credentials_ref
// - accept client credentials
// - inspect OAuth tokens
// - store OAuth tokens
// - contain provider-specific branches
// - resolve tenant independently
// ============================================================


// ============================================================
// 1. SUPABASE CONFIGURATION
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";


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


const supabase =
  createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY
  );


// ============================================================
// 2. TYPES
// ============================================================

type JsonObject =
  Record<string, unknown>;


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

    this.status =
      status;
  }
}


// ============================================================
// 4. JSON RESPONSE
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
// 5. VALUE HELPERS
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


// ============================================================
// 6. CALLBACK RESULT
// ============================================================

type OAuthCompletionResult = {

  id: string;

  tenant_id: string;

  provider_code: string;

  is_enabled: boolean;
};


// ============================================================
// 7. MAIN HANDLER
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
        req.method !== "GET"
      ) {

        throw new HttpError(
          405,
          "Method Not Allowed"
        );
      }


      // ======================================================
      // CALLBACK PARAMETERS
      //
      // The provider returns:
      //
      //   ?code=...
      //   &state=...
      //
      // We deliberately accept ONLY these OAuth transaction
      // parameters.
      // ======================================================

      const url =
        new URL(
          req.url
        );


      const code =
        asString(
          url.searchParams.get(
            "code"
          )
        );


      const stateToken =
        asString(
          url.searchParams.get(
            "state"
          )
        );


      // ======================================================
      // PROVIDER ERROR
      //
      // OAuth providers can return:
      //
      //   ?error=access_denied
      //   &state=...
      //
      // Do not attempt token exchange in that case.
      // ======================================================

      const oauthError =
        asString(
          url.searchParams.get(
            "error"
          )
        );


      const oauthErrorDescription =
        asString(
          url.searchParams.get(
            "error_description"
          )
        );


      if (
        oauthError
      ) {

        console.warn(
          "OAuth provider returned an error:",
          {
            error:
              oauthError,

            description:
              oauthErrorDescription,
          }
        );


        throw new HttpError(
          400,
          oauthErrorDescription
            ? `OAuth authorization failed: ${oauthErrorDescription}`
            : `OAuth authorization failed: ${oauthError}`
        );
      }


      // ======================================================
      // INPUT VALIDATION
      // ======================================================

      if (!code) {

        throw new HttpError(
          400,
          "OAuth authorization code is required"
        );
      }


      if (!stateToken) {

        throw new HttpError(
          400,
          "OAuth state is required"
        );
      }


      // ======================================================
      // 007 — TOKEN EXCHANGE
      //
      // IMPORTANT:
      //
      // The Edge Function does NOT provide:
      //
      // - tenant_id
      // - provider_code
      // - redirect_uri
      // - client_id
      // - client_secret
      //
      // 007 resolves all of these from SSOT/Vault.
      // ======================================================

      const {
        data:
          credentialsRef,
        error:
          exchangeError,
      } =
        await supabase.rpc(
          "integrations_exchange_oauth_tokens",
          {
            p_code:
              code,

            p_state_token:
              stateToken,
          }
        );


      if (
        exchangeError
      ) {

        console.error(
          "OAuth token exchange failed:",
          exchangeError
        );


        throw new HttpError(
          400,
          "OAuth token exchange failed"
        );
      }


      if (
        !credentialsRef ||
        typeof credentialsRef !== "string"
      ) {

        throw new HttpError(
          500,
          "OAuth token exchange returned no credentials reference"
        );
      }


      // ======================================================
      // 007 — COMPLETE OAUTH
      //
      // IMPORTANT:
      //
      // Only state_token is supplied.
      //
      // integrations_complete_oauth() resolves:
      //
      //   tenant_id
      //   provider_code
      //   credentials_ref
      //
      // from the authoritative transaction / Vault.
      // ======================================================

      const {
        data:
          completion,
        error:
          completionError,
      } =
        await supabase.rpc(
          "integrations_complete_oauth",
          {
            p_state_token:
              stateToken,
          }
        );


      if (
        completionError
      ) {

        console.error(
          "OAuth completion failed:",
          completionError
        );


        throw new HttpError(
          500,
          "OAuth completion failed"
        );
      }


      if (
        !completion ||
        typeof completion !== "object"
      ) {

        throw new HttpError(
          500,
          "OAuth completion returned no result"
        );
      }


      const result =
        completion as OAuthCompletionResult;


      // ======================================================
      // SECURITY CHECK
      //
      // credentials_ref is intentionally NOT returned.
      //
      // The callback only exposes non-secret integration
      // metadata.
      // ======================================================

      return jsonResponse(
        {

          success:
            true,

          integration: {

            id:
              result.id,

            tenant_id:
              result.tenant_id,

            provider_code:
              result.provider_code,

            is_enabled:
              result.is_enabled,
          },

        },
        200
      );


    } catch (
      error
    ) {

      console.error(
        "SmartHellas OAuth callback error:",
        error
      );


      if (
        error instanceof HttpError
      ) {

        return jsonResponse(
          {

            success:
              false,

            error:
              error.message,

          },
          error.status
        );
      }


      return jsonResponse(
        {

          success:
            false,

          error:
            "Internal server error",

        },
        500
      );
    }
  }
);