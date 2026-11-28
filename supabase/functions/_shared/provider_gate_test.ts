import { acquireProviderPermit } from "./provider_gate.ts";

const originalFetch = globalThis.fetch;
const envNames = [
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
];
const req = () =>
  new Request("https://example.invalid", {
    headers: { Authorization: "Bearer user-session" },
  });
function assert(condition: unknown) {
  if (!condition) throw new Error("Assertion failed");
}

Deno.test("provider gate authenticates user and uses only server RPC credentials", async () => {
  const previous = envNames.map((name) => Deno.env.get(name));
  envNames.forEach((name, i) =>
    Deno.env.set(name, ["https://local.invalid", "public", "server-secret"][i])
  );
  const requests: { url: string; init?: RequestInit }[] = [];
  globalThis.fetch = async (url, init) => {
    requests.push({ url: String(url), init });
    if (String(url).endsWith("/user")) {
      return Response.json({ id: "auth-user" });
    }
    if (String(url).endsWith("/consume_provider_quota")) {
      return Response.json({ allowed: true, lease: "lease-token" });
    }
    return new Response(null, { status: 204 });
  };
  try {
    const permit = await acquireProviderPermit(req(), "cloud_stt");
    assert(permit.status === "allowed");
    assert(
      new Headers(requests[0].init?.headers).get("Authorization") ===
        "Bearer user-session",
    );
    assert(
      new Headers(requests[1].init?.headers).get("Authorization") ===
        "Bearer server-secret",
    );
    assert(
      requests[1].init?.body ===
        JSON.stringify({ p_user_id: "auth-user", p_metric: "cloud_stt" }),
    );
    await permit.release();
    assert(
      requests[2].init?.body ===
        JSON.stringify({ p_user_id: "auth-user", p_token: "lease-token" }),
    );
  } finally {
    globalThis.fetch = originalFetch;
    envNames.forEach((name, i) =>
      previous[i] === undefined
        ? Deno.env.delete(name)
        : Deno.env.set(name, previous[i]!)
    );
  }
});

Deno.test("provider gate fails closed on unavailable Auth", async () => {
  const previous = envNames.map((name) => Deno.env.get(name));
  envNames.forEach((name) => Deno.env.set(name, "configured"));
  globalThis.fetch = () => Promise.reject(new Error("offline"));
  try {
    const permit = await acquireProviderPermit(req(), "translate");
    assert(permit.status === "unavailable");
    await permit.release();
    assert(
      (await acquireProviderPermit(
        new Request("https://example.invalid"),
        "suggest",
      )).status === "unauthorized",
    );
  } finally {
    globalThis.fetch = originalFetch;
    envNames.forEach((name, i) =>
      previous[i] === undefined
        ? Deno.env.delete(name)
        : Deno.env.set(name, previous[i]!)
    );
  }
});
