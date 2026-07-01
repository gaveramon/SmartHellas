import { AppError, normalizeError } from "./errors.ts";

export { parseJsonBody, type ParseJsonBodyOptions } from "./request.ts";

export interface ApiSuccess<T> {
  success: true;
  data: T;
  meta?: Record<string, unknown>;
}

export interface ApiFailure {
  success: false;
  error: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
}

export type ApiResponse<T> = ApiSuccess<T> | ApiFailure;

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-tenant-id",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
};

export function jsonResponse<T>(
  body: ApiResponse<T>,
  status = 200,
  extraHeaders?: Record<string, string>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}

export function success<T>(
  data: T,
  meta?: Record<string, unknown>,
  status = 200,
): Response {
  return jsonResponse<T>({ success: true, data, meta }, status);
}

export function failure(error: AppError): Response {
  return jsonResponse({
    success: false,
    error: {
      code: error.code,
      message: error.message,
      details: error.details,
    },
  }, error.status);
}

export function handleCors(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  return null;
}

export function withErrorHandling(
  handler: (req: Request) => Promise<Response>,
): (req: Request) => Promise<Response> {
  return async (req: Request) => {
    const cors = handleCors(req);
    if (cors) return cors;

    try {
      return await handler(req);
    } catch (error) {
      const appError = normalizeError(error);
      return failure(appError);
    }
  };
}
