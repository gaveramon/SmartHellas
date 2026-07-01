import { config } from "./config.ts";
import { ExternalApiError } from "./errors.ts";

export interface SmsPayload {
  to: string;
  body: string;
}

/**
 * Dispatch SMS via configured provider.
 * Opt-in rules and content templates are enforced in SQL before enqueue.
 */
export async function sendSms(payload: SmsPayload): Promise<void> {
  const provider = config.smsProvider();
  const apiKey = config.smsApiKey();

  if (!provider || !apiKey) {
    console.warn(
      JSON.stringify({
        level: "warn",
        message: "SMS not configured — logging message instead",
        to: payload.to,
      }),
    );
    return;
  }

  if (provider === "twilio") {
    const accountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
    if (!accountSid) {
      throw new ExternalApiError("TWILIO_ACCOUNT_SID not configured");
    }

    const from = config.smsFrom();
    const response = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${btoa(`${accountSid}:${apiKey}`)}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          To: payload.to,
          From: from ?? "",
          Body: payload.body,
        }),
      },
    );

    if (!response.ok) {
      const detail = await response.text();
      throw new ExternalApiError("Failed to send SMS", {
        provider: "twilio",
        detail,
      });
    }
    return;
  }

  throw new ExternalApiError(`Unsupported SMS provider: ${provider}`);
}
