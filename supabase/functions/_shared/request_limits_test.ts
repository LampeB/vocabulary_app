import {
  audioPathForUser,
  boundedJson,
  boundedText,
} from "./request_limits.ts";

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}
Deno.test("bounded body rejects chunks exceeding limit before parsing", async () => {
  let cancelled = false;
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new TextEncoder().encode("x".repeat(65)));
    },
    cancel() {
      cancelled = true;
    },
  });
  let rejected = false;
  try {
    await boundedJson(
      new Request("https://test.invalid", { method: "POST", body: stream }),
      64,
    );
  } catch {
    rejected = true;
  }
  assert(
    rejected && cancelled,
    "oversized upload must be rejected and cancelled",
  );
});
Deno.test("bounded fields protect billed text and accept valid object", async () => {
  assert(!boundedText("x".repeat(257), 256), "unbounded paid text admitted");
  assert(!boundedText({}, 256), "non-text paid input admitted");
  assert(boundedText("안녕하세요", 256), "valid text refused");
  const body = await boundedJson(
    new Request("https://test.invalid", {
      method: "POST",
      body: JSON.stringify({ word: "hello" }),
    }),
  );
  assert(body.word === "hello", "valid object rejected");
});
Deno.test("edited starter content renders only under the private user namespace", () => {
  const path = audioPathForUser("owner-a", "variant-a", "content-hash");
  assert(
    path === "users/owner-a/variant-a/content-hash.mp3",
    "private namespace changed",
  );
  assert(
    !path.startsWith("seed/"),
    "private edited content entered public seed namespace",
  );
});
