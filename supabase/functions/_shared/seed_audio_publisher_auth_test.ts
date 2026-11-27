import { canPublishSeedAudio } from "../seed-audio-publish/authorization.ts";

const projectUrl = "https://supabase.invalid";
const publicKey = "sb_publishable_fixture";
const secretKey = "sb_secret_fixture";
const serviceJwt = "Bearer header.service.signature";
const userJwt = "Bearer header.user.signature";

for (
  const [label, request, expectedHeaders, status, allowed] of [
    [
      "modern service key",
      { apikey: secretKey },
      { apikey: secretKey },
      200,
      true,
    ],
    [
      "modern service key with a bearer token",
      { apikey: secretKey, Authorization: userJwt },
      { apikey: secretKey },
      200,
      true,
    ],
    [
      "legacy service role",
      { apikey: "header.service.signature", Authorization: serviceJwt },
      { apikey: publicKey, Authorization: serviceJwt },
      200,
      true,
    ],
    ["publishable key", { apikey: publicKey }, null, 401, false],
    [
      "signed-in user",
      { apikey: publicKey, Authorization: userJwt },
      { apikey: publicKey, Authorization: userJwt },
      403,
      false,
    ],
    [
      "unrecognized secret key",
      { apikey: "sb_secret_invalid" },
      { apikey: "sb_secret_invalid" },
      401,
      false,
    ],
  ] as const
) {
  Deno.test(`seed audio publisher checks ${label}`, async () => {
    const originalFetch = globalThis.fetch;
    const calls: Array<[string, RequestInit | undefined]> = [];
    globalThis.fetch = (url, init) => {
      calls.push([String(url), init]);
      return Promise.resolve(new Response(null, { status }));
    };
    try {
      if (
        await canPublishSeedAudio(
          new Headers(request),
          projectUrl,
          publicKey,
        ) !== allowed
      ) {
        throw new Error("Unexpected publisher authorization decision");
      }
      if (calls.length !== Number(expectedHeaders !== null)) {
        throw new Error("Unexpected number of Auth requests");
      }
      if (expectedHeaders !== null) {
        const [url, init] = calls[0];
        if (
          url !== `${projectUrl}/auth/v1/admin/users?page=1&per_page=1` ||
          init?.redirect !== "error" ||
          JSON.stringify([...new Headers(init.headers)]) !==
            JSON.stringify([...new Headers(expectedHeaders)])
        ) {
          throw new Error("Unexpected destination or credential sent to Auth");
        }
      }
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
}
