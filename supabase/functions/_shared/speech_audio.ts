import { boundedText } from "./request_limits.ts";

// The mobile capture contract is mono 16 kHz PCM16, either raw or RIFF/WAVE.
// A byte limit alone permits low-rate or compressed files lasting hours.
export async function readSpeechRequest(
  req: Request,
): Promise<Record<string, unknown>> {
  // Bound uploads before inference so a slow body cannot outlive the lease.
  const reader = req.body?.getReader();
  if (!reader) throw new Error("Missing request body");
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error("Body read timed out")), 5_000);
  });
  const parts: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const chunk = await Promise.race([reader.read(), timeout]);
      if (chunk.done) break;
      size += chunk.value.byteLength;
      if (size > 1_290_000) throw new Error("Request body too large");
      parts.push(chunk.value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const part of parts) {
      bytes.set(part, offset);
      offset += part.length;
    }
    const body = JSON.parse(new TextDecoder().decode(bytes));
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new Error("Invalid request body");
    }
    if (
      body.expected_word != null && !boundedText(body.expected_word, 256, false)
    ) {
      throw new Error("Invalid expected word");
    }
    return body;
  } finally {
    clearTimeout(timer);
    void reader.cancel().catch(() => {});
  }
}

export function decodeSpeechAudio(base64: unknown, rawPcm = false): Uint8Array {
  if (
    typeof base64 !== "string" || base64.length === 0 ||
    base64.length > 1_280_128
  ) {
    throw new Error("Audio capture is missing or too large");
  }
  const bytes = Uint8Array.from(atob(base64), (value) => value.charCodeAt(0));
  const maxBytes = 30 * 16_000 * 2;
  if (rawPcm) {
    if (
      bytes.length === 0 || bytes.length % 2 !== 0 || bytes.length > maxBytes
    ) {
      throw new Error("Invalid PCM capture");
    }
    return bytes;
  }
  const view = new DataView(bytes.buffer);
  const id = (offset: number) =>
    String.fromCharCode(...bytes.subarray(offset, offset + 4));
  if (
    bytes.length < 44 || id(0) !== "RIFF" || id(8) !== "WAVE" ||
    view.getUint32(4, true) + 8 !== bytes.length
  ) throw new Error("Invalid WAV capture");
  let format = false;
  let dataBytes = 0;
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const length = view.getUint32(offset + 4, true);
    const next = offset + 8 + length + (length % 2);
    if (next > bytes.length) throw new Error("Truncated WAV capture");
    if (id(offset) === "fmt ") {
      if (
        format || length < 16 || view.getUint16(offset + 8, true) !== 1 ||
        view.getUint16(offset + 10, true) !== 1 ||
        view.getUint32(offset + 12, true) !== 16_000 ||
        view.getUint32(offset + 16, true) !== 32_000 ||
        view.getUint16(offset + 20, true) !== 2 ||
        view.getUint16(offset + 22, true) !== 16
      ) throw new Error("WAV must be 16 kHz mono PCM16");
      format = true;
    } else if (id(offset) === "data") {
      if (length % 2 !== 0) throw new Error("Invalid PCM payload");
      dataBytes += length;
    }
    offset = next;
  }
  if (!format || dataBytes === 0 || dataBytes > maxBytes) {
    throw new Error("WAV exceeds 30 seconds");
  }
  return bytes;
}
