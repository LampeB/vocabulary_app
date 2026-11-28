import { handleTranscription as elevenLabs } from "../elevenlabs-stt-proxy/handler.ts";
import { handleTranscription as openAi } from "../whisper-proxy/handler.ts";

// Mono 16 kHz PCM16 WAVE containing one silent sample.
const audio =
  "UklGRiYAAABXQVZFZm10IBAAAAABAAEAgD4AAAB9AAACABAAZGF0YQIAAAAAAA==";
const request = (expected_word: unknown) =>
  new Request("https://edge.invalid", {
    method: "POST",
    headers: { Authorization: "Bearer user-session" },
    body: JSON.stringify({
      audio_base64: audio,
      language: "ko",
      expected_word,
    }),
  });

const names = [
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "OPENAI_API_KEY",
  "ELEVENLABS_API_KEY",
];

for (
  const [label, handler, field] of [
    ["OpenAI", openAi, "prompt"],
    ["ElevenLabs", elevenLabs, "keyterms"],
  ] as const
) {
  Deno.test(`${label} validates the hint before acquiring a speech permit`, async () => {
    const existing = names.map((name) => Deno.env.get(name));
    names.forEach((name) => Deno.env.set(name, "configured"));
    Deno.env.set("SUPABASE_URL", "https://supabase.invalid");
    const originalFetch = globalThis.fetch;
    const calls: string[] = [];
    const limit = "안".repeat(256);
    globalThis.fetch = (url, init) => {
      const address = new URL(String(url));
      calls.push(address.pathname);
      if (address.pathname === "/auth/v1/user") {
        return Promise.resolve(Response.json({ id: "fixture-user" }));
      }
      if (address.pathname.endsWith("/consume_provider_quota")) {
        return Promise.resolve(
          Response.json({ allowed: true, lease: "fixture-lease" }),
        );
      }
      if (address.pathname.endsWith("/release_provider_speech")) {
        return Promise.resolve(new Response(null, { status: 204 }));
      }
      const prompt = (init?.body as FormData).get(field);
      if (typeof prompt !== "string" || !prompt.includes(limit)) {
        throw new Error("Valid hint lost before provider request");
      }
      return Promise.resolve(Response.json({ text: "안" }));
    };
    try {
      for (const invalid of [limit + "안", " " + limit, { text: "안" }]) {
        const response = await handler(request(invalid));
        if (response.status !== 400 || calls.length !== 0) {
          throw new Error("Malformed hint reached Auth, quota, or provider");
        }
      }
      const accepted = await handler(request(limit));
      if (
        accepted.status !== 200 || (await accepted.json()).text !== "안" ||
        calls.length !== 4 || !calls[1].endsWith("/consume_provider_quota") ||
        !calls[3].endsWith("/release_provider_speech")
      ) {
        throw new Error(
          "Maximum-length hint did not complete the permitted flow",
        );
      }
    } finally {
      globalThis.fetch = originalFetch;
      names.forEach((name, index) => {
        const previous = existing[index];
        if (previous === undefined) Deno.env.delete(name);
        else Deno.env.set(name, previous);
      });
    }
  });

  Deno.test(`${label} holds the shared speech lease only for an uncertain provider result`, async () => {
    const existing = names.map((name) => Deno.env.get(name));
    names.forEach((name) => Deno.env.set(name, "configured"));
    Deno.env.set("SUPABASE_URL", "https://supabase.invalid");
    const originalFetch = globalThis.fetch;
    const alternative = handler === openAi ? elevenLabs : openAi;
    let leaseHeld = false;
    let providerCalls = 0;
    let releases = 0;
    const releasesSoFar = () => releases;
    let providerOutcome = "timeout";
    globalThis.fetch = (url, init) => {
      const address = new URL(String(url));
      if (address.pathname === "/auth/v1/user") {
        return Promise.resolve(Response.json({ id: "fixture-user" }));
      }
      if (address.pathname.endsWith("/consume_provider_quota")) {
        if (leaseHeld) {
          return Promise.resolve(Response.json({ allowed: false }));
        }
        leaseHeld = true;
        return Promise.resolve(
          Response.json({ allowed: true, lease: "fixture-lease" }),
        );
      }
      if (address.pathname.endsWith("/release_provider_speech")) {
        if (JSON.parse(String(init?.body)).p_token !== "fixture-lease") {
          throw new Error("Invalid lease release");
        }
        releases++;
        leaseHeld = false;
        return Promise.resolve(new Response(null, { status: 204 }));
      }
      providerCalls++;
      if (providerOutcome === "timeout") {
        return Promise.reject(
          new DOMException("Upload timed out", "TimeoutError"),
        );
      }
      if (providerOutcome === "interrupted") {
        return Promise.resolve(
          new Response(
            new ReadableStream({
              start(controller) {
                controller.error(
                  new Error("Disconnected while reading response"),
                );
              },
            }),
          ),
        );
      }
      return Promise.resolve(
        providerOutcome === "error"
          ? Response.json({ error: "provider fixture" }, { status: 502 })
          : Response.json({ text: "안" }),
      );
    };
    try {
      for (const outcome of ["timeout", "interrupted"]) {
        providerOutcome = outcome;
        const callsBefore = providerCalls;
        await handler(request("안"));
        const retry = await alternative(request("안"));
        if (
          retry.status !== 429 || providerCalls !== callsBefore + 1 ||
          releasesSoFar() !== 0
        ) {
          throw new Error(
            "An uncertain provider result freed the shared lease",
          );
        }
        leaseHeld = false; // Simulate the SQL lease's expiry without sleeping.
      }
      providerOutcome = "error";
      const providerError = await handler(request("안"));
      providerOutcome = "success";
      const completed = await alternative(request("안"));
      if (
        providerError.status !== 502 || completed.status !== 200 ||
        releasesSoFar() !== 2
      ) {
        throw new Error(
          "A complete provider response did not release the shared lease",
        );
      }
      const key = handler === openAi ? "OPENAI_API_KEY" : "ELEVENLABS_API_KEY";
      Deno.env.delete(key);
      const callsBefore = providerCalls;
      if (
        (await handler(request("안"))).status !== 503 ||
        providerCalls !== callsBefore || releasesSoFar() !== 3
      ) {
        throw new Error("A pre-provider stop did not release the shared lease");
      }
    } finally {
      globalThis.fetch = originalFetch;
      names.forEach((name, index) => {
        const previous = existing[index];
        if (previous === undefined) Deno.env.delete(name);
        else Deno.env.set(name, previous);
      });
    }
  });
}
