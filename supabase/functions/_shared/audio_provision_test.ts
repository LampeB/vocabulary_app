import { handleAudioProvision } from "../audio-provision/handler.ts";

const owner = "10000000-0000-4000-8000-000000000001";
const variantId = "20000000-0000-4000-8000-000000000001";
const projectUrl = "https://supabase.invalid";
const request = () =>
  new Request("https://edge.invalid", {
    method: "POST",
    headers: { Authorization: "Bearer fixture-session" },
    body: JSON.stringify({ variant_id: variantId }),
  });

function expect(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

class AudioServer {
  word = "premier";
  lang = "fr";
  attached: string | null = null;
  published = false;
  parentDeletedDuringUpdate = false;
  quotaCalls = 0;
  storageCalls = 0;
  ambiguousMissingAt = 0;
  readonly signals: Array<
    { path: string; signal: AbortSignal | null | undefined }
  > = [];
  readonly ttsCalls: string[] = [];
  readonly leases: string[] = [];
  readonly activeLeases = new Map<string, string>();
  readonly released: string[] = [];
  readonly uploads = new Map<string, string>();
  storageStatus = (_path: string): number => 404;
  beforeAttach = () => {};
  beforeUpload = (_signal?: AbortSignal | null): Promise<void> =>
    Promise.resolve();
  synthesize = (word: string): Promise<Response> =>
    Promise.resolve(new Response(word));

  fetch: typeof fetch = async (target, init) => {
    const url = new URL(String(target));
    const method = init?.method ?? "GET";
    const path = url.pathname;
    this.signals.push({ path, signal: init?.signal });
    if (url.hostname === "api.elevenlabs.io") {
      const { text } = JSON.parse(String(init?.body));
      this.ttsCalls.push(text);
      return await this.synthesize(text);
    }
    if (path === "/auth/v1/user") return Response.json({ id: owner });
    if (path === "/rest/v1/word_variants" && method === "GET") {
      return Response.json([{
        id: variantId,
        word: this.word,
        lang_code: this.lang,
        is_deleted: false,
        concept: {
          is_deleted: false,
          list: { owner_id: owner, is_deleted: false },
        },
      }]);
    }
    if (path === "/rest/v1/word_variants" && method === "PATCH") {
      this.beforeAttach();
      const { searchParams } = url;
      expect(
        searchParams.get("id") === `eq.${variantId}`,
        "Update lost variant filter",
      );
      expect(
        searchParams.get("is_deleted") === "eq.false",
        "Update lost active-row filter",
      );
      if (
        searchParams.get("word") !== `eq.${this.word}` ||
        searchParams.get("lang_code") !== `eq.${this.lang}`
      ) {
        return Response.json([]);
      }
      if (!this.parentDeletedDuringUpdate) {
        this.attached = JSON.parse(String(init?.body)).audio_path;
      }
      return Response.json([{
        id: variantId,
        audio_path: this.attached,
        is_deleted: this.parentDeletedDuringUpdate,
      }]);
    }
    if (path === "/rest/v1/published_audio_assets") {
      return Response.json(this.published ? [{ path: "published" }] : []);
    }
    const infoPrefix = "/storage/v1/object/info/vocab-audio/";
    if (path.startsWith(infoPrefix)) {
      this.storageCalls++;
      if (this.storageCalls === this.ambiguousMissingAt) {
        return Response.json({}, { status: 404 });
      }
      const status = this.storageStatus(path.slice(infoPrefix.length));
      if (status === 404) {
        return Response.json({ code: "NoSuchKey" }, { status });
      }
      if (status === 400) {
        return Response.json({ code: "NoSuchKey", statusCode: "404" }, {
          status,
        });
      }
      return Response.json({}, { status });
    }
    const uploadPrefix = "/storage/v1/object/vocab-audio/";
    if (path.startsWith(uploadPrefix) && method === "POST") {
      await this.beforeUpload(init?.signal);
      this.uploads.set(
        path.slice(uploadPrefix.length),
        new TextDecoder().decode(init?.body as Uint8Array),
      );
      return Response.json({ Id: "fixture-object", Key: path });
    }
    if (path === "/rest/v1/rpc/acquire_audio_generation") {
      const { p_path } = JSON.parse(String(init?.body));
      if (this.activeLeases.has(p_path)) return Response.json(null);
      this.leases.push(p_path);
      const token = `lease-${this.leases.length}`;
      this.activeLeases.set(p_path, token);
      return Response.json(token);
    }
    if (path === "/rest/v1/rpc/release_audio_generation") {
      const { p_path, p_token } = JSON.parse(String(init?.body));
      expect(
        this.activeLeases.get(p_path) === p_token,
        "Lease release lost token",
      );
      this.activeLeases.delete(p_path);
      this.released.push(p_path);
      return Response.json(true);
    }
    if (path === "/rest/v1/rpc/consume_provider_quota") {
      const input = JSON.parse(String(init?.body));
      expect(
        input.p_user_id === owner && input.p_metric === "audio_provision",
        "Invalid audio quota identity or metric",
      );
      this.quotaCalls++;
      return Response.json({ allowed: true });
    }
    throw new Error(`Unexpected ${method} ${url}`);
  };
}

async function withAudioServer(test: (server: AudioServer) => Promise<void>) {
  const env = {
    SUPABASE_URL: projectUrl,
    SUPABASE_ANON_KEY: "fixture-public",
    SUPABASE_SERVICE_ROLE_KEY: "fixture-admin",
    ELEVENLABS_API_KEY: "fixture-provider",
  };
  const previous = Object.keys(env).map((name) =>
    [name, Deno.env.get(name)] as const
  );
  const originalFetch = globalThis.fetch;
  const server = new AudioServer();
  globalThis.fetch = server.fetch;
  for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
  try {
    await test(server);
  } finally {
    globalThis.fetch = originalFetch;
    for (const [key, value] of previous) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

Deno.test("an older generation finishing last cannot replace the current clip", () =>
  withAudioServer(async (server) => {
    const started = Promise.withResolvers<void>();
    const finish = Promise.withResolvers<Response>();
    server.synthesize = (word) => {
      if (word !== "premier") return Promise.resolve(new Response(word));
      started.resolve();
      return finish.promise;
    };

    const old = handleAudioProvision(request());
    await Promise.race([
      started.promise,
      old.then(() => {
        throw new Error("Original clip did not reach the provider");
      }),
    ]);
    server.word = "새 단어";
    server.lang = "ko";

    try {
      const newer = await handleAudioProvision(request());
      const ready = await newer.json();
      expect(
        newer.status === 200 && ready.status === "ready",
        "Current clip was not ready",
      );
      expect(
        ready.word === server.word && ready.lang_code === server.lang,
        "Missing content in ready response",
      );
      expect(
        server.uploads.get(ready.audio_path) === server.word,
        "Current clip was not uploaded",
      );
      expect(
        server.attached === ready.audio_path,
        "Current clip was not attached",
      );
      finish.resolve(new Response("premier"));
      const stale = await old;
      const body = await stale.json();
      expect(
        stale.status === 409 && body.status === "stale" && !body.audio_path,
        "Original generation reported ready",
      );
      expect(
        server.attached === ready.audio_path,
        "A stale clip replaced the current one",
      );
      expect(
        server.leases.length === 2 && new Set(server.leases).size === 2,
        "Expected independent leases",
      );
      expect(
        server.released.length === 2 && server.released[0] === ready.audio_path,
        "Leases were not released in completion order",
      );
    } finally {
      finish.resolve(new Response("premier"));
      await old;
    }
  }));

for (const source of ["published", "private", "after lease"] as const) {
  Deno.test(`attachment rejects a stale ${source} cache hit`, () =>
    withAudioServer(async (server) => {
      server.published = source === "published";
      server.storageStatus = () =>
        source === "after lease" && server.storageCalls === 1 ? 404 : 200;
      server.beforeAttach = () => server.lang = "en";
      const result = await handleAudioProvision(request());
      expect(
        result.status === 409 && !(await result.json()).audio_path,
        "Cache hit returned stale audio",
      );
      expect(
        server.attached === null && server.ttsCalls.length === 0,
        "Cache hit changed the variant or regenerated audio",
      );
    }));
}

Deno.test("an update tombstoned by its parent does not report ready", () =>
  withAudioServer(async (server) => {
    server.storageStatus = () => 200;
    server.parentDeletedDuringUpdate = true;
    const result = await handleAudioProvision(request());
    expect(
      result.status === 409 && !(await result.json()).audio_path,
      "Tombstoned row returned ready audio",
    );
  }));

for (const source of ["published", "private", "after lease"] as const) {
  Deno.test(`a ${source} Storage outage cannot generate audio or debit quota`, () =>
    withAudioServer(async (server) => {
      server.published = source === "published";
      server.storageStatus = () =>
        source === "after lease" && server.storageCalls === 1 ? 404 : 503;
      const result = await handleAudioProvision(request());
      expect(result.status === 503, "A Storage outage did not fail closed");
      expect(
        server.quotaCalls === 0 && server.ttsCalls.length === 0,
        "A Storage outage reached quota or TTS",
      );
      expect(
        server.released.length === Number(source === "after lease"),
        "An acquired lease was left open",
      );
    }));
}

for (const attempt of [1, 2] as const) {
  Deno.test(`an empty HTTP 404 on cache check ${attempt} cannot debit quota or render`, () =>
    withAudioServer(async (server) => {
      server.ambiguousMissingAt = attempt;
      const result = await handleAudioProvision(request());
      expect(
        result.status === 503,
        "An unqualified 404 was mistaken for a missing clip",
      );
      expect(
        server.storageCalls === attempt && server.quotaCalls === 0 &&
          server.ttsCalls.length === 0,
        "Ambiguous Storage response reached quota or TTS",
      );
      expect(
        server.released.length === attempt - 1,
        "Lease was not released after a confirmed pre-provider stop",
      );
    }));
}

Deno.test("Storage's wrapped NoSuchKey triggers generation", () =>
  withAudioServer(async (server) => {
    server.storageStatus = () => 400;
    const result = await handleAudioProvision(request());
    expect(result.status === 200, "Wrapped object-missing error was rejected");
    expect(
      server.quotaCalls === 1 && server.ttsCalls.length === 1,
      "Confirmed absence did not generate one clip",
    );
  }));

Deno.test("same-clip retries cannot reach the provider during an unconfirmed timed-out upload", () =>
  withAudioServer(async (server) => {
    const deadline = new AbortController();
    const uploadStarted = Promise.withResolvers<void>();
    server.beforeUpload = (signal) => {
      expect(
        signal === deadline.signal,
        "Storage upload did not receive the lease deadline",
      );
      uploadStarted.resolve();
      return new Promise((_, reject) =>
        signal.addEventListener("abort", () => reject(signal.reason), {
          once: true,
        })
      );
    };
    const first = handleAudioProvision(request(), () => deadline.signal);
    try {
      await Promise.race([
        uploadStarted.promise,
        first.then(() => {
          throw new Error(
            "First request did not reach the blocked Storage upload",
          );
        }),
      ]);
      const firstSignals = server.signals;
      const leased = firstSignals.slice(
        firstSignals.findIndex(({ path }) =>
          path.endsWith("/acquire_audio_generation")
        ),
      );
      expect(
        leased.length === 5 &&
          leased.every(({ signal }) => signal === deadline.signal),
        "Acquire, Storage recheck, quota, provider and upload must share one deadline",
      );
      expect(
        (await handleAudioProvision(request())).status === 429,
        "Overlapping request took the active lease",
      );
      deadline.abort();
      expect(
        (await first).status === 503,
        "Timed-out upload did not return an unavailable response",
      );
      expect(
        (await handleAudioProvision(request())).status === 429,
        "Timeout released an unconfirmed render for retry",
      );
      expect(
        server.ttsCalls.length === 1 && server.quotaCalls === 1,
        "Competing requests reached quota or TTS",
      );
      expect(
        server.released.length === 0 && server.uploads.size === 0,
        "Unconfirmed upload released the lease or wrote an object",
      );
    } finally {
      deadline.abort();
      await first;
    }
  }));
