// ============================================================
// SMARTHELLAS
// GENERIC OAUTH CALLBACK EDGE FUNCTION
//
// Architecture:
//
//   OAUTH PROVIDER
//          |
//          | code + state
//          v
//   EDGE FUNCTION
//          |
//          v
//   007 INTEGRATION ENGINE
//          |
//          +--> integrations_exchange_oauth_tokens()
//          |         |
//          |         +--> OAuth state
//          |         +--> OAuth config
//          |         +--> Vault client credentials
//          |         +--> provider token endpoint
//          |         +--> Vault token storage
//          |
//          +--> integrations_complete_oauth()
//                    |
//                    +--> consume OAuth state
//                    +--> tenant_integrations
//                    +--> audit
//
// SSOT:
//
// integration_oauth_states  = OAuth transaction
// integration_oauth_configs = OAuth protocol configuration
// integration_providers     = provider capability
// tenant_integrations       = active tenant integration
// Vault                     = OAuth credentials/tokens
//
// IMPORTANT:
//
// This function is orchestration only.
//
// It MUST NOT:
// - accept tenant_id from caller
// - accept provider_code from caller
// - accept redirect_uri from caller
// - perform provider-specific OAuth logic
// - contain client secrets
// - store tokens in PostgreSQL
// - expose tokens to the browser
// - create devices
// - modify device state
// - process telemetry
//
// ============================================================


import {
  createClient,
} from "https://esm.sh/@supabase/supabase-js@2";


// ============================================================
// 1. SUPABASE CONFIGURATION
// ============================================================

const SUPABASE_URL =
  Deno.env.get("SUPABASE_URL");

const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get(
    "SUPABASE_SERVICE_ROLE_KEY"
  );


if (
  !SUPABASE_URL ||
  !SUPABASE_SERVICE_ROLE_KEY
) {

  throw new Error(
    "Missing Supabase environment configuration"
  );
}


// ============================================================
// 2. SUPABASE CLIENT
//
// Service role is required because the callback is a
// provider-to-server callback and does not carry the
// customer's Supabase session.
//
// Authorization is therefore performed by the OAuth
// transaction state stored in 007.
// ============================================================

const supabase =
  createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    }
  );


// ============================================================
// 3. HTTP RESPONSE HELPERS
// ============================================================

function htmlResponse(
  title: string,
  message: string,
  status = 200
): Response {

  const escapedTitle =
    escapeHtml(title);

  const escapedMessage =
    escapeHtml(message);


  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta
        name="viewport"
        content="width=device-width, initial-scale=1.0"
    >
    <title>${escapedTitle}</title>
</head>

<body>

    <main>

        <h1>${escapedTitle}</h1>

        <p>${escapedMessage}</p>

    </main>

</body>
</html>
`;


  return new Response(
    html,
    {
      status,

      headers: {
        "Content-Type":
          "text/html; charset=utf-8",

        "Cache-Control":
          "no-store, no-cache, must-revalidate",

        "Pragma":
          "no-cache",
      },
    }
  );
}


// ============================================================
// 4. HTML ESCAPING
// ============================================================

function escapeHtml(
  value: string
): string {

  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}


// ============================================================
// 5. OAUTH ERROR RESPONSE
// ============================================================

function oauthFailureResponse(
  message: string,
  status = 400
): Response {

  return htmlResponse(
    "OAuth connection failed",
    message,
    status
  );
}


// ============================================================
// 6. MAIN CALLBACK
// ============================================================

Deno.serve(
  async (
    req: Request
  ): Promise<Response> => {

    try {

      // ======================================================
      // 6A. METHOD
      // ======================================================

      if (
        req.method !== "GET"
      ) {

        return oauthFailureResponse(
          "Method not allowed.",
          405
        );
      }


      // ======================================================
      // 6B. READ CALLBACK PARAMETERS
      //
      // The provider supplies:
      //
      //   code
      //   state
      //
      // No tenant_id.
      // No provider_code.
      // No redirect_uri.
      // ======================================================

      const url =
        new URL(req.url);


      const code =
        url.searchParams.get(
          "code"
        );


      const state =
        url.searchParams.get(
          "state"
        );


      const providerError =
        url.searchParams.get(
          "error"
        );


      const providerErrorDescription =
        url.searchParams.get(
          "error_description"
        );


      // ======================================================
      // 6C. PROVIDER DECLINED / DENIED AUTHORIZATION
      // ======================================================

      if (
        providerError
      ) {

        console.error(
          "OAuth provider returned authorization error",
          {
            error:
              providerError,

            description:
              providerErrorDescription,
          }
        );


        return oauthFailureResponse(
          "The authorization was cancelled or rejected.",
          400
        );
      }


      // ======================================================
      // 6D. REQUIRED CODE
      // ======================================================

      if (
        !code ||
        code.trim() === ""
      ) {

        return oauthFailureResponse(
          "Authorization code is missing.",
          400
        );
      }


      // ======================================================
      // 6E. REQUIRED STATE
      // ======================================================

      if (
        !state ||
        state.trim() === ""
      ) {

        return oauthFailureResponse(
          "OAuth state is missing.",
          400
        );
      }


      const normalizedState =
        state.trim();


      // ======================================================
      // 7. TOKEN EXCHANGE
      //
      // IMPORTANT:
      //
      // Only code + state cross the Edge Function boundary.
      //
      // 007 resolves:
      //
      // state
      //   ↓
      // tenant
      // provider
      // redirect_uri
      // PKCE verifier
      // OAuth configuration
      // client credentials
      //
      // The token response is stored in Vault.
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
              normalizedState,
          }
        );


      if (
        exchangeError
      ) {

        console.error(
          "OAuth token exchange failed",
          {
            message:
              exchangeError.message,
          }
        );


        return oauthFailureResponse(
          "The authorization could not be completed.",
          400
        );
      }


      // ======================================================
      // 8. VALIDATE EXCHANGE RESULT
      //
      // The RPC returns only a Vault reference.
      // Never expose it to the browser.
      // ======================================================

      if (
        typeof credentialsRef !== "string" ||
        credentialsRef.trim() === ""
      ) {

        console.error(
          "OAuth token exchange returned no valid credentials reference"
        );


        return oauthFailureResponse(
          "The authorization could not be completed.",
          500
        );
      }


      // ======================================================
      // 9. COMPLETE OAUTH
      //
      // IMPORTANT:
      //
      // integrations_complete_oauth() must resolve:
      //
      //   tenant_id
      //   provider_code
      //
      // from integration_oauth_states.
      //
      // The callback does NOT supply them.
      // ======================================================

      const {
        data: completion,
        error: completionError,
      } =
        await supabase.rpc(
          "integrations_complete_oauth",
          {
            p_credentials_ref:
              credentialsRef,

            p_state_token:
              normalizedState,
          }
        );


      if (
        completionError
      ) {

        console.error(
          "OAuth completion failed",
          {
            message:
              completionError.message,
          }
        );


        return oauthFailureResponse(
          "Authorization was received, but the integration could not be completed.",
          500
        );
      }


      // ======================================================
      // 10. VALIDATE COMPLETION
      // ======================================================

      if (
        !completion
      ) {

        console.error(
          "OAuth completion returned no result"
        );


        return oauthFailureResponse(
          "The integration could not be completed.",
          500
        );
      }


      // ======================================================
      // 11. AUDIT / LOGGING
      //
      // Do NOT log:
      //
      // - authorization code
      // - access token
      // - refresh token
      // - client secret
      // - credentials_ref
      // - PKCE verifier
      //
      // integrations_complete_oauth() already owns the
      // domain-level OAuth completion audit.
      // ======================================================

      console.info(
        "OAuth callback completed successfully"
      );


      // ======================================================
      // 12. SUCCESS
      //
      // Do NOT return:
      //
      // - completion object
      // - tenant_id
      // - provider_code
      // - credentials_ref
      // - access_token
      // - refresh_token
      //
      // The browser only needs to know that the operation
      // succeeded.
      // ======================================================

      return htmlResponse(
        "OAuth connection successful",
        "The integration has been connected successfully."
      );


    } catch (error) {

      // ======================================================
      // 13. UNEXPECTED ERROR
      // ======================================================

      console.error(
        "Unexpected OAuth callback error",
        {
          message:
            error instanceof Error
              ? error.message
              : String(error),
        }
      );


      return oauthFailureResponse(
        "An unexpected error occurred while completing the connection.",
        500
      );
    }
  }
);