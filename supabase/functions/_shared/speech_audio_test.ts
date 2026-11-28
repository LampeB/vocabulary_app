import { decodeSpeechAudio, readSpeechRequest } from "./speech_audio.ts";

function assert(condition: unknown) {
  if (!condition) throw new Error("Assertion failed");
}
function base64(bytes: Uint8Array) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary);
}
function wav(seconds: number, rate = 16000) {
  const data = new Uint8Array(44 + seconds * rate * 2);
  const view = new DataView(data.buffer);
  const text = (offset: number, value: string) =>
    data.set(new TextEncoder().encode(value), offset);
  text(0, "RIFF");
  view.setUint32(4, data.length - 8, true);
  text(8, "WAVE");
  text(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, rate, true);
  view.setUint32(28, rate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  text(36, "data");
  view.setUint32(40, data.length - 44, true);
  return data;
}
function rejects(bytes: Uint8Array, raw = false) {
  let rejected = false;
  try {
    decodeSpeechAudio(base64(bytes), raw);
  } catch {
    rejected = true;
  }
  assert(rejected);
}
Deno.test("speech accepts actual mobile WAV and raw PCM captures", () => {
  assert(decodeSpeechAudio(base64(wav(30))).length === 960044);
  assert(
    decodeSpeechAudio(base64(new Uint8Array(960000)), true).length === 960000,
  );
});
Deno.test("speech rejects long, low-rate, truncated and compressed captures", () => {
  rejects(wav(31));
  rejects(wav(60, 8000));
  rejects(wav(1).slice(0, -1));
  const compressed = wav(1);
  new DataView(compressed.buffer).setUint16(20, 3, true);
  rejects(compressed);
  rejects(new Uint8Array(960002), true);
  rejects(new Uint8Array(1), true);
});

Deno.test("speech bounds the request body before decoding audio", async () => {
  const valid = new Request("https://example.invalid", {
    method: "POST",
    body: JSON.stringify({ audio_base64: "AA==" }),
  });
  assert((await readSpeechRequest(valid)).audio_base64 === "AA==");
  let rejected = false;
  try {
    await readSpeechRequest(
      new Request("https://example.invalid", {
        method: "POST",
        body: "x".repeat(1_290_001),
      }),
    );
  } catch {
    rejected = true;
  }
  assert(rejected);
});
