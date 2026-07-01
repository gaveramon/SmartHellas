import { ValidationError } from "./errors.ts";

export interface ParseJsonBodyOptions {
  /** Return this value when Content-Length is 0. */
  allowEmpty?: boolean;
  emptyValue?: unknown;
}

/** Parse JSON request body; malformed JSON becomes ValidationError (400). */
export async function parseJsonBody(
  req: Request,
  options?: ParseJsonBodyOptions,
): Promise<unknown> {
  if (options?.allowEmpty && req.headers.get("Content-Length") === "0") {
    return options.emptyValue ?? {};
  }

  try {
    return await req.json();
  } catch (error) {
    if (error instanceof SyntaxError) {
      throw new ValidationError("Request body must be valid JSON");
    }
    throw error;
  }
}
