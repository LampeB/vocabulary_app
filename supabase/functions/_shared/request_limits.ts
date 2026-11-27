/** Read a bounded body before parsing or constructing a billed prompt. */
export async function boundedJson(
  req: Request,
  limit = 32_768,
): Promise<Record<string, unknown>> {
  const reader = req.body?.getReader();
  if (!reader) throw new Error("invalid_body");
  const chunks: Uint8Array[] = [];
  let length = 0;
  let expired = false;
  const timer = setTimeout(() => {
    expired = true;
    reader.cancel("upload_timeout");
  }, 5_000);
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (expired) throw new Error("upload_timeout");
      if (done) break;
      length += value.length;
      if (length > limit) {
        await reader.cancel("body_too_large");
        throw new Error("body_too_large");
      }
      chunks.push(value);
    }
  } finally {
    clearTimeout(timer);
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  const body = JSON.parse(new TextDecoder().decode(bytes));
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new Error("invalid_body");
  }
  return body;
}

export function boundedText(
  value: unknown,
  max: number,
  required = true,
): value is string {
  return typeof value === "string" && value.length <= max &&
    (!required || value.trim().length > 0);
}

export const audioPathForUser = (
  userId: string,
  variantId: string,
  hash: string,
) => `users/${userId}/${variantId}/${hash}.mp3`;
