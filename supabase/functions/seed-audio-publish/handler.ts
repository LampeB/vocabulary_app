import { createAudioClient } from "../_shared/audio_client.ts";
import { boundedJson, boundedText } from "../_shared/request_limits.ts";
import { storageObjectExists } from "../_shared/storage_presence.ts";
import { canPublishSeedAudio } from "./authorization.ts";

// This endpoint is a publishing tool, never an app endpoint. It accepts only
// Supabase's server key, so the ElevenLabs key remains solely in Supabase
// secrets and is never copied to a developer workstation or mobile client.
const bucket = "vocab-audio";
const seedVersion = "v1";
const voiceByLanguage: Record<string, string> = {
  fr: "XB0fDUnXU5powFXDhCwa",
  en: "21m00Tcm4TlvDq8ikWAM",
  ko: "MF3mGyEYCl7XYWbV9V6O",
};

function json(body: unknown, status = 200) {
  return Response.json(body, { status });
}

async function contentHash(text: string, lang: string) {
  const bytes = new TextEncoder().encode(`${seedVersion}|${lang}|${text}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function handleSeedAudioPublish(
  req: Request,
  workDeadline = () => AbortSignal.timeout(60_000),
) {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const elevenLabsKey = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !elevenLabsKey) {
    return json({ error: "Server is not configured" }, 503);
  }
  if (!await canPublishSeedAudio(req.headers, supabaseUrl, anonKey)) {
    return json({ error: "Forbidden" }, 403);
  }

  let items: Array<{ text: string; lang: string }>;
  try {
    items = (await boundedJson(req)).items as Array<
      { text: string; lang: string }
    >;
  } catch (_) {
    return json({ error: "Invalid JSON" }, 400);
  }
  if (!Array.isArray(items) || items.length === 0 || items.length > 25) {
    return json({ error: "items must contain 1 to 25 entries" }, 400);
  }

  const admin = createAudioClient(supabaseUrl, serviceRoleKey);
  const attest = async (client: typeof admin, path: string) => {
    const { error } = await client.from("published_audio_assets").upsert({
      path,
    });
    if (error) throw error;
  };
  var generated = 0;
  var existing = 0;
  const failed: string[] = [];
  for (const item of items) {
    if (!boundedText(item?.text, 256) || !voiceByLanguage[item.lang]) {
      failed.push("invalid item");
      continue;
    }
    const hash = await contentHash(item.text, item.lang);
    const path = `seed/${seedVersion}/${item.lang}/${hash}.mp3`;
    const present = await storageObjectExists(admin, bucket, path);
    if (present === null) {
      failed.push(`${item.lang}:storage`);
      continue;
    }
    if (present) {
      try {
        await attest(admin, path);
        existing++;
      } catch (_) {
        failed.push(`${item.lang}:manifest`);
      }
      continue;
    }
    // The same 60s work budget covers acquisition, recheck and publication.
    // The SQL lease lasts 90s, including uncertain/cancelled paid work.
    const deadline = workDeadline();
    const leasedAdmin = createAudioClient(
      supabaseUrl,
      serviceRoleKey,
      deadline,
    );
    let lease: string | undefined;
    let paidWorkPending = false;
    try {
      const { data, error } = await leasedAdmin.rpc(
        "acquire_seed_audio_generation",
        { p_path: path },
      );
      if (error || typeof data !== "string" || !data) {
        failed.push(`${item.lang}:busy`);
        continue;
      }
      lease = data;
      const presentAfterLock = await storageObjectExists(
        leasedAdmin,
        bucket,
        path,
      );
      if (presentAfterLock === null) {
        failed.push(`${item.lang}:storage`);
        continue;
      }
      if (presentAfterLock) {
        await attest(leasedAdmin, path);
        existing++;
        continue;
      }
      deadline.throwIfAborted();
      paidWorkPending = true;
      const voiceId = voiceByLanguage[item.lang];
      const tts = await fetch(
        `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}?output_format=mp3_22050_32`,
        {
          method: "POST",
          signal: deadline,
          headers: {
            "xi-api-key": elevenLabsKey,
            "Content-Type": "application/json",
            Accept: "audio/mpeg",
          },
          body: JSON.stringify({
            text: item.text,
            model_id: "eleven_multilingual_v2",
          }),
        },
      );
      if (!tts.ok) throw new Error(`TTS ${tts.status}`);
      const { error: uploadError } = await leasedAdmin.storage.from(bucket)
        .upload(
          path,
          new Uint8Array(await tts.arrayBuffer()),
          {
            contentType: "audio/mpeg",
            cacheControl: "31536000",
            upsert: false,
          },
        );
      deadline.throwIfAborted();
      if (uploadError && !/already exists/i.test(uploadError.message)) {
        throw uploadError;
      }
      paidWorkPending = false;
      await attest(leasedAdmin, path);
      if (uploadError) existing++;
      else generated++;
    } catch (_) {
      failed.push(`${item.lang}:${item.text}`);
    } finally {
      if (lease && !deadline.aborted && !paidWorkPending) {
        // A failed release is safe: the token expires, and a retry first sees
        // the immutable object. Never release an uncertain render/upload.
        try {
          await leasedAdmin.rpc("release_audio_generation", {
            p_path: path,
            p_token: lease,
          });
        } catch (_) { /* leave expiry to release ownership */ }
      }
    }
  }
  return json({ generated, existing, failed });
}
