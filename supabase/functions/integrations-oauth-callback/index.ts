// ============================================================
// SMARTHELLAS
// GENERIC OAUTH CALLBACK EDGE FUNCTION
//
// Responsibility:
// - Receive OAuth authorization callback
// - Validate code + state
// - Delegate token exchange to 007
// - Delegate OAuth completion to 007
// - Return only non-secret completion information
//
// SSOT:
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

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";


// ============================================================
// 1. SUPABASE CONFIGURATION
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

type OAuthCompletionResult = {
  id: string;
  tenant_id: string;
  provider_code: string;
  is_enabled: boolean;
};


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
// 5. VALUE HELPER
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
// 6. MAIN HANDLER
// ============================================================

Deno.serve(
  async (
    req: Request
  ): Promise<Response> => {

    try {

      // ======================================================
      // 6A. HTTP METHOD
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
      // 6B. CALLBACK PARAMETERS
      //
      // OAuth callback is intentionally limited to:
      //
      //   code
      //   state
      //
      // Tenant/provider context is resolved from state
      // inside 007.
      // ======================================================

      const url =
        new URL(req.url);

      const code =
        asString(
          url.searchParams.get("code")
        );

      const stateToken =
        asString(
          url.searchParams.get("state")
        );


      // ======================================================
      // 6C. PROVIDER ERROR
      //
      // Do not attempt token exchange when the provider
      // rejected the authorization request.
      // ======================================================

      const oauthError =
        asString(
          url.searchParams.get("error")
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
      // 6D. INPUT VALIDATION
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
      // 7. TOKEN EXCHANGE
      //
      // 007 resolves:
      //
      // - tenant_id
      // - provider_code
      // - redirect_uri
      // - OAuth configuration
      // - client credentials
      // - PKCE verifier
      //
      // Tokens are stored directly in Vault.
      //
      // The callback never receives or inspects the token
      // payload.
      // ======================================================

      const {
        data: credentialsRef,
        error: exchangeError,
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


      // The database function returns only the Vault
      // reference. The callback does not use or expose it.
      //
      // Keep this validation so a broken exchange cannot
      // silently continue into completion.

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
      // 8. COMPLETE OAUTH
      //
      // ONLY state_token crosses the API boundary.
      //
      // integrations_complete_oauth() derives:
      //
      // - tenant_id
      // - provider_code
      // - credentials_ref
      //
      // from authoritative SSOT sources.
      // ======================================================

      const {
        data: completion,
        error: completionError,
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
      // 9. SECURITY VALIDATION
      //
      // Never expose:
      //
      // - access_token
      // - refresh_token
      // - client_secret
      // - credentials_ref
      // - PKCE verifier
      //
      // Only integration metadata is returned.
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