import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req) => {
    if (req.method !== "POST") {
        return new Response(
            JSON.stringify({
                error: "method_not_allowed"
            }),
            {
                status: 405,
                headers: {
                    "content-type": "application/json"
                }
            }
        );
    }

    const authHeader = req.headers.get("Authorization");

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return new Response(
            JSON.stringify({
                error: "missing_authorization"
            }),
            {
                status: 401,
                headers: {
                    "content-type": "application/json"
                }
            }
        );
    }

    return new Response(
        JSON.stringify({
            status: "ok",
            service: "supabase-edge-function",
            timestamp: new Date().toISOString()
        }),
        {
            status: 200,
            headers: {
                "content-type": "application/json"
            }
        }
    );
});