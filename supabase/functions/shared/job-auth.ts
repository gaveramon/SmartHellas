import { UnauthorizedError } from "./errors.ts";
import { config } from "./config.ts";

/**
 * Authenticate platform job invocations.
 * Accepts service-role Bearer token or X-Job-Secret header.
 */
export function requireJobAuth(req: Request): void {
  const jobSecret = config.jobSecret();
  const headerSecret = req.headers.get("X-Job-Secret");

  if (jobSecret && headerSecret === jobSecret) {
    return;
  }

  const authHeader = req.headers.get("Authorization");
  if (authHeader?.startsWith("Bearer ")) {
    const token = authHeader.slice(7).trim();
    if (token === config.supabaseServiceRoleKey()) {
      return;
    }
  }

  throw new UnauthorizedError("Invalid job credentials");
}
