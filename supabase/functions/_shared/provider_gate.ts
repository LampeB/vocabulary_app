export type GateResult = "allowed" | "unauthorized" | "limited" | "unavailable";
type Metric =
  | "translate"
  | "suggest"
  | "grammar_exercises"
  | "audio_provision"
  | "cloud_stt";

interface ProviderPermit {
  status: GateResult;
  release: () => Promise<void>;
}

/** Authenticate first; only the Edge Function can invoke the fixed quota policy.
 * Speech leases are shared between both providers. Expiry recovers from crashes.
 * The 90s lease exceeds the 60s provider fetch timeout.
 */
export async function acquireProviderPermit(
  req: Request,
  metric: Metric,
): Promise<ProviderPermit> {
  const noop = async () => {};
  const authorization = req.headers.get("Authorization");
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
  const serverKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!authorization || !/^Bearer\s+\S+$/i.test(authorization)) {
    return { status: "unauthorized", release: noop };
  }
  if (!url || !publicKey || !serverKey) {
    return { status: "unavailable", release: noop };
  }
  try {
    const userResponse = await fetch(`${url}/auth/v1/user`, {
      headers: { apikey: publicKey, Authorization: authorization },
      signal: AbortSignal.timeout(10_000),
    });
    if (!userResponse.ok) return { status: "unauthorized", release: noop };
    const user = await userResponse.json();
    if (typeof user.id !== "string" || !user.id) {
      return { status: "unauthorized", release: noop };
    }
    const headers = {
      apikey: serverKey,
      Authorization: `Bearer ${serverKey}`,
      "Content-Type": "application/json",
    };
    const quota = await fetch(`${url}/rest/v1/rpc/consume_provider_quota`, {
      method: "POST",
      headers,
      body: JSON.stringify({ p_user_id: user.id, p_metric: metric }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!quota.ok) return { status: "unavailable", release: noop };
    const permit = await quota.json();
    if (permit.allowed !== true) return { status: "limited", release: noop };
    return {
      status: "allowed",
      release: metric !== "cloud_stt" ? noop : async () => {
        try {
          await fetch(`${url}/rest/v1/rpc/release_provider_speech`, {
            method: "POST",
            headers,
            body: JSON.stringify({ p_user_id: user.id, p_token: permit.lease }),
            signal: AbortSignal.timeout(10_000),
          });
        } catch { /* The lease expires after a failed release. */ }
      },
    };
  } catch {
    return { status: "unavailable", release: noop };
  }
}

export async function authorizeAndConsume(
  req: Request,
  metric: Exclude<Metric, "cloud_stt">,
): Promise<GateResult> {
  return (await acquireProviderPermit(req, metric)).status;
}
