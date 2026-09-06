/**
 * Standard error types for Edge Functions.
 * Business rule violations from SQL are surfaced as SqlBusinessError.
 */

export type ErrorCode =
  | "UNAUTHORIZED"
  | "FORBIDDEN"
  | "NOT_FOUND"
  | "VALIDATION_ERROR"
  | "CONFLICT"
  | "RATE_LIMITED"
  | "EXTERNAL_API_ERROR"
  | "INTERNAL_ERROR"
  | "SQL_BUSINESS_ERROR";

export class AppError extends Error {
  readonly code: ErrorCode;
  readonly status: number;
  readonly details?: Record<string, unknown>;

  constructor(
    code: ErrorCode,
    message: string,
    status: number,
    details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = "AppError";
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = "Authentication required") {
    super("UNAUTHORIZED", message, 401);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = "Insufficient permissions") {
    super("FORBIDDEN", message, 403);
  }
}

export class ValidationError extends AppError {
  constructor(message: string, details?: Record<string, unknown>) {
    super("VALIDATION_ERROR", message, 400, details);
  }
}

export class NotFoundError extends AppError {
  constructor(message = "Resource not found") {
    super("NOT_FOUND", message, 404);
  }
}

export class SqlBusinessError extends AppError {
  constructor(message: string, details?: Record<string, unknown>) {
    super("SQL_BUSINESS_ERROR", message, 422, details);
  }
}

export class ExternalApiError extends AppError {
  constructor(message: string, details?: Record<string, unknown>) {
    super("EXTERNAL_API_ERROR", message, 502, details);
  }
}

/** Map unknown errors to AppError for consistent responses. */
export function normalizeError(error: unknown): AppError {
  if (error instanceof AppError) {
    return error;
  }

  if (error instanceof Error) {
    const pgCode = (error as { code?: string }).code;
    if (pgCode === "P0001" || pgCode === "23505" || pgCode === "23503") {
      return new SqlBusinessError(error.message, { pgCode });
    }
    return new AppError("INTERNAL_ERROR", error.message, 500);
  }

  return new AppError("INTERNAL_ERROR", "An unexpected error occurred", 500);
}
