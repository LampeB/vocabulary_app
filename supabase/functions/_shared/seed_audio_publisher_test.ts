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
  objects = new Set<string>();
  activeLeases = new Map<string, string>();
  leaseCalls = 0;
  releases = 0;
  beforeAcquire = (_path: string): void => {};
  synthesize = (
    _text: string,
    _signal?: AbortSignal | null,
  ): Promise<Response> =>
    Promise.resolve(new Response(new Uint8Array([1, 2, 3])));
  nextPresence: (() => StorageReply) | undefined;

  fetch: typeof fetch = async (target, init) => {
    const url = new URL(String(target));
    const method = init?.method ?? "GET";
    if (url.pathname === "/auth/v1/admin/users") {
      return Response.json({ users: [] });
    }
    if (url.pathname.startsWith("/storage/v1/object/info/vocab-audio/")) {
      this.infoCalls++;
      const path = url.pathname.split("/info/vocab-audio/")[1];
      const reply = this.nextPresence?.() ??
        (this.objects.has(path) ? { status: 200 } : this.presence);
      if (reply instanceof Error) throw reply;
      return Response.json(reply.body ?? {}, { status: reply.status });
    }
    if (url.hostname === "api.elevenlabs.io") {
      const text = JSON.parse(String(init?.body)).text;
      this.rendered.push(text);
      return await this.synthesize(text, init?.signal);
    }
    if (url.pathname === "/rest/v1/rpc/acquire_seed_audio_generation") {
      const { p_path } = JSON.parse(String(init?.body));
      this.leaseCalls++;
      this.beforeAcquire(p_path);
      if (this.activeLeases.has(p_path)) return Response.json(null);
      const token = `seed-lease-${this.leaseCalls}`;
      this.activeLeases.set(p_path, token);
      return Response.json(token);
    }
    if (url.pathname === "/rest/v1/rpc/release_audio_generation") {
      const { p_path, p_token } = JSON.parse(String(init?.body));
      expect(
        this.activeLeases.get(p_path) === p_token,
        "Wrong lease owner released",
      );
      this.activeLeases.delete(p_path);
      this.releases++;
      return Response.json(null);
    }
    if (
      url.pathname.startsWith("/storage/v1/object/vocab-audio/") &&
      method === "POST"
    ) {
      expect(
        new Headers(init?.headers).get("x-upsert") === "false",
        "Publisher upload must remain immutable",
      );
      const path = url.pathname.split("/object/vocab-audio/")[1];
      if (this.objects.has(path)) {
        return Response.json({ message: "The resource already exists" }, {
          status: 409,
        });
      }
      this.objects.add(path);
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

async function publish(texts = ["bonjour"], deadline?: () => AbortSignal) {
  const response = await handleSeedAudioPublish(
    new Request("https://edge.invalid", {
      method: "POST",
      headers: { apikey: "sb_secret_fixture" },
      body: JSON.stringify({
        items: texts.map((text) => ({ text, lang: "fr" })),
      }),
    }),
    deadline,
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

Deno.test("concurrent requests for the same catalog clip render once", () =>
  withPublisher(async (server) => {
    // The existing French starter-greetings entry, not a new catalog fixture.
    const text = "bonjour";
    server.presence = { status: 404, body: { code: "NoSuchKey" } };
    const started = Promise.withResolvers<void>();
    const finish = Promise.withResolvers<void>();
    server.synthesize = async () => {
      started.resolve();
      await finish.promise;
      return new Response(new Uint8Array([1, 2, 3]));
    };
    const first = publish([text]);
    await started.promise;
    const competing = await publish([text]);
    expect(
      competing.generated === 0 && competing.failed.length === 1,
      "Competing render reported success",
    );
    expect(server.rendered.length === 1, "Two concurrent paid renders");
    finish.resolve();
    const completed = await first;
    expect(
      completed.generated === 1 && completed.failed.length === 0,
      "Owner did not publish",
    );
    const retry = await publish([text]);
    expect(
      retry.existing === 1 && retry.generated === 0,
      "Retry counters lost existing object",
    );
    expect(
      server.rendered.length === 1 && server.uploads === 1 &&
        server.activeLeases.size === 0,
      "Ownership or immutable object leaked",
    );
  }));

Deno.test("duplicate items in a batch share the immutable publication", () =>
  withPublisher(async (server) => {
    server.presence = { status: 404, body: { code: "NoSuchKey" } };
    const result = await publish(["bonjour", "bonjour"]);
    expect(
      result.generated === 1 && result.existing === 1,
      "Duplicate counters are inconsistent",
    );
    expect(
      server.rendered.length === 1 && server.uploads === 1,
      "Duplicate batch charged twice",
    );
  }));

Deno.test("presence is rechecked under the acquired lease before rendering", () =>
  withPublisher(async (server) => {
    server.presence = { status: 404, body: { code: "NoSuchKey" } };
    server.beforeAcquire = (path) => {
      server.objects.add(path);
    };
    const result = await publish();
    expect(
      result.existing === 1 && result.generated === 0,
      "Completed racing publication was missed",
    );
    expect(
      server.rendered.length === 0 && server.releases === 1,
      "Cache recheck charged or leaked ownership",
    );
  }));

Deno.test("an uncertain cache recheck releases ownership without paid work", () =>
  withPublisher(async (server) => {
    server.nextPresence = () =>
      server.infoCalls === 1
        ? { status: 404, body: { code: "NoSuchKey" } }
        : { status: 503 };
    const result = await publish();
    expect(
      result.failed.length === 1 && server.rendered.length === 0,
      "Uncertain cache reached provider",
    );
    expect(
      server.activeLeases.size === 0 && server.releases === 1,
      "Safe pre-render failure retained lease",
    );
  }));

Deno.test("a cancelled paid render keeps ownership against an immediate retry", () =>
  withPublisher(async (server) => {
    server.presence = { status: 404, body: { code: "NoSuchKey" } };
    const started = Promise.withResolvers<void>();
    const cancelled = new AbortController();
    server.synthesize = (_text, signal) =>
      new Promise((_resolve, reject) => {
        signal?.addEventListener("abort", () => reject(signal.reason), {
          once: true,
        });
        started.resolve();
      });
    const first = publish(["bonjour"], () => cancelled.signal);
    await started.promise;
    cancelled.abort(new DOMException("Work deadline expired", "TimeoutError"));
    const result = await first;
    expect(
      result.failed.length === 1 && server.activeLeases.size === 1 &&
        server.releases === 0,
      "Uncertain paid work released lease",
    );
    const retry = await publish();
    expect(
      retry.generated === 0 && retry.failed.length === 1,
      "Retry bypassed uncertain ownership",
    );
    expect(
      server.rendered.length === 1 && server.uploads === 0,
      "Uncertain retry charged again",
    );
  }));
