import { config } from "./config.ts";
import { ExternalApiError } from "./errors.ts";

export interface MailPayload {
  to: string;
  subject: string;
  html?: string;
  text?: string;
}

/**
 * Send email via configured provider.
 * Template selection and send rules are defined in SQL; this only dispatches.
 */
export async function sendMail(payload: MailPayload): Promise<void> {
  const provider = config.mailProvider();

  if (provider === "supabase") {
    // Supabase Auth / custom SMTP — use Resend-compatible HTTP as fallback
    const apiKey = config.mailApiKey();
    if (!apiKey) {
      console.warn(
        JSON.stringify({
          level: "warn",
          message: "Mail API key missing — logging email instead",
          to: payload.to,
          subject: payload.subject,
        }),
      );
      return;
    }

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: config.mailFrom(),
        to: payload.to,
        subject: payload.subject,
        html: payload.html,
        text: payload.text,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new ExternalApiError("Failed to send email", {
        provider: "resend",
        detail: error,
      });
    }
    return;
  }

  throw new ExternalApiError(`Unsupported mail provider: ${provider}`);
}
