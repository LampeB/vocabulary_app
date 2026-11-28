import { handleSeedAudioPublish } from "../seed-audio-publish/handler.ts";

function expect(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

type StorageReply = { status: number; body?: object } | Error;

class PublisherServer {
  presence: StorageReply = { status: 200 };
  infoCalls = 0;
  uploads = 0;
  manifests = 0;
  rendered: string[] = [];
  nextPresence: (() => StorageReply) | undefined;

  fetch: typeof fetch = async (target, init) => {
    const url = new URL(String(target));
    const method = init?.method ?? "GET";
    if (url.pathname === "/auth/v1/admin/users") {
      return Response.json({ users: [] });
    }
    if (url.pathname.startsWith("/storage/v1/object/info/vocab-audio/")) {
      this.infoCalls++;
      const reply = this.nextPresence?.() ?? this.presence;
      if (reply instanceof Error) throw reply;
      return Response.json(reply.body ?? {}, { status: reply.status });
    }
    if (url.hostname === "api.elevenlabs.io") {
      this.rendered.push(JSON.parse(String(init?.body)).text);
      return new Response(new Uint8Array([1, 2, 3]), {
        headers: { "Content-Type": "audio/mpeg" },
      });
    }
    if (
      url.pathname.startsWith("/storage/v1/object/vocab-audio/") &&
      method === "POST"
    ) {
      expect(
        new Headers(init?.headers).get("x-upsert") === "false",
        "Publisher upload must remain immutable",
      );
      this.uploads++;
      return Response.json({ Key: url.pathname });
    }
    if (url.pathname === "/rest/v1/published_audio_assets") {
      this.manifests++;
      return new Response(null, { status: 201 });
    }
    throw new Error(`Unexpected publisher request: ${method} ${url}`);
  };
}

async function withPublisher(
  run: (server: PublisherServer) => Promise<void>,
) {
  const values = {
    SUPABASE_URL: "https://supabase.invalid",
    SUPABASE_ANON_KEY: "fixture-public",
    SUPABASE_SERVICE_ROLE_KEY: "sb_secret_fixture",
    ELEVENLABS_API_KEY: "fixture-provider",
  };
  const previous = Object.keys(values).map((key) =>
    [key, Deno.env.get(key)] as const
  );
  const fetch = globalThis.fetch;
  const server = new PublisherServer();
  for (const [key, value] of Object.entries(values)) Deno.env.set(key, value);
  globalThis.fetch = server.fetch;
  try {
    await run(server);
  } finally {
    globalThis.fetch = fetch;
    for (const [key, value] of previous) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

async function publish(texts = ["bonjour"]) {
  const response = await handleSeedAudioPublish(
    new Request("https://edge.invalid", {
      method: "POST",
      headers: { apikey: "sb_secret_fixture" },
      body: JSON.stringify({
        items: texts.map((text) => ({ text, lang: "fr" })),
      }),
    }),
  );
  expect(response.status === 200, "Expected publisher batch result");
  return await response.json();
}

for (
  const [label, presence] of [
    ["Storage 503", { status: 503 }],
    ["unqualified 404", { status: 404 }],
    ["different Storage error", {
      status: 404,
      body: { code: "AccessDenied" },
    }],
    ["transport failure", new TypeError("Storage unavailable")],
  ] as const
) {
  Deno.test(`seed publisher never renders on ${label}`, () =>
    withPublisher(async (server) => {
      server.presence = presence;
      const result = await publish();
      expect(
        server.infoCalls > 0,
        "Production Storage metadata path was not read",
      );
      expect(
        result.failed.length === 1,
        "Unknown presence was reported as ready",
      );
      expect(
        result.generated === 0 && result.existing === 0 &&
          server.rendered.length === 0 && server.uploads === 0 &&
          server.manifests === 0,
        "Unknown Storage presence reached paid rendering or publication",
      );
    }));
}

Deno.test("seed publisher republishes an existing object's manifest without rendering", () =>
  withPublisher(async (server) => {
    const result = await publish();
    expect(
      result.existing === 1 && result.failed.length === 0,
      "Existing object lost",
    );
    expect(
      server.manifests === 1 && server.uploads === 0 &&
        server.rendered.length === 0,
      "Existing immutable audio was regenerated",
    );
  }));

for (const status of [404, 400]) {
  Deno.test(`seed publisher renders only confirmed NoSuchKey (${status})`, () =>
    withPublisher(async (server) => {
      server.presence = {
        status,
        body: { code: "NoSuchKey", statusCode: "404" },
      };
      const result = await publish();
      expect(
        result.generated === 1 && result.failed.length === 0,
        "Confirmed miss failed",
      );
      expect(
        server.rendered.join() === "bonjour" && server.uploads === 1 &&
          server.manifests === 1,
        "Confirmed miss did not render and publish exactly one immutable object",
      );
    }));
}

Deno.test("an uncertain item does not prevent a separate confirmed miss from publishing", () =>
  withPublisher(async (server) => {
    server.nextPresence = () =>
      server.infoCalls === 1
        ? { status: 503 }
        : { status: 404, body: { code: "NoSuchKey" } };
    const result = await publish(["bonjour", "merci"]);
    expect(
      result.failed.length === 1 && result.generated === 1,
      "Batch results lost",
    );
    expect(
      server.rendered.join() === "merci",
      "Unknown item triggered paid work",
    );
  }));
