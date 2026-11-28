import { createClient } from "npm:@supabase/supabase-js@2.119.2";
import { storageObjectExists } from "../_shared/storage_presence.ts";
import {
  audioPathForUser,
  boundedJson,
  boundedText,
} from "../_shared/request_limits.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const bucket = "vocab-audio";
const seedVersion = "v1";
const audioWorkTimeoutMs = 60_000;
const voiceByLanguage: Record<string, { id: string; label: string }> = {
  fr: { id: "XB0fDUnXU5powFXDhCwa", label: "Charlotte" },
  en: { id: "21m00Tcm4TlvDq8ikWAM", label: "Rachel" },
  ko: { id: "MF3mGyEYCl7XYWbV9V6O", label: "Elli" },
};

function response(body: unknown, status = 200) {
  return Response.json(body, { status, headers: cors });
}

async function hash(text: string, lang: string) {
  const bytes = new TextEncoder().encode(`${seedVersion}|${lang}|${text}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function handleAudioProvision(
  req: Request,
  workDeadline = () => AbortSignal.timeout(audioWorkTimeoutMs),
) {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") {
    return response({ error: "Method not allowed" }, 405);
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return response({ error: "Server is not configured" }, 503);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return response({ error: "Authentication required" }, 401);

  const client = (key: string, deadline?: AbortSignal) =>
    createClient(supabaseUrl, key, {
      db: { retry: false },
      global: {
        fetch: (input, init) => {
          const limit = deadline ?? AbortSignal.timeout(10_000);
          const signal = init?.signal
            ? AbortSignal.any([limit, init.signal])
            : limit;
          signal.throwIfAborted();
          return fetch(input, { ...init, signal });
        },
      },
    });
  const auth = client(anonKey);
  const { data: authData, error: authError } = await auth.auth.getUser(token);
  const user = authData.user;
  if (authError || !user) return response({ error: "Invalid session" }, 401);

  let variantId: string;
  try {
    variantId = (await boundedJson(req, 1_024)).variant_id as string;
  } catch (_) {
    return response({ error: "Invalid JSON" }, 400);
  }
  if (typeof variantId !== "string" || variantId.length < 20) {
    return response({ error: "Invalid variant_id" }, 400);
  }

  const admin = client(serviceRoleKey);
  const { data: variant, error: variantError } = await admin
    .from("word_variants")
    .select(
      "id, word, lang_code, concept:concepts!inner(list:vocabulary_lists!inner())",
    )
    .eq("id", variantId)
    .eq("owner_id", user.id)
    .eq("is_deleted", false)
    .eq("concept.list.owner_id", user.id)
    .not("concept.is_deleted", "is", true)
    .not("concept.list.is_deleted", "is", true)
    .maybeSingle();
  if (variantError || !variant) {
    return response({ error: "Variant not found" }, 404);
  }

  const lang = variant.lang_code as string;
  const text = variant.word as string;
  if (!boundedText(text, 256) || !boundedText(lang, 8)) {
    return response({ error: "Invalid or oversized vocabulary text" }, 400);
  }
  const textHash = await hash(text, lang);
  const voice = voiceByLanguage[lang] ?? voiceByLanguage.fr;
  const objectExists = (db: typeof admin, path: string) =>
    storageObjectExists(db, bucket, path);
  const unavailable = () => response({ error: "Audio unavailable" }, 503);
  const attach = async (db: typeof admin, path: string) => {
    const { data, error } = await db.from("word_variants")
      .update({
        audio_path: path,
        audio_hash: textHash,
        audio_voice_id: voice.label,
      })
      .eq("id", variant.id)
      .eq("owner_id", user.id)
      .eq("word", text)
      .eq("lang_code", lang)
      .eq("is_deleted", false)
      .select("id, audio_path, is_deleted")
      .maybeSingle();
    if (error) return unavailable();
    // A concurrent parent deletion can tombstone the matched row in the
    // database trigger. Verify the actual returned row before claiming ready.
    if (
      !data || data.id !== variant.id || data.is_deleted ||
      data.audio_path !== path
    ) {
      return response({ status: "stale", error: "Variant changed" }, 409);
    }
    return response({
      audio_path: path,
      status: "ready",
      word: text,
      lang_code: lang,
    });
  };

  // A client-controlled origin is never permission to publish shared audio.
  // Only seed-audio-publish can write seed/. Existing published assets may be
  // reused by content hash; private edits always render below users/<owner>/.
  const publishedPath = `seed/${seedVersion}/${lang}/${textHash}.mp3`;
  const { data: published, error: manifestError } = await admin.from(
    "published_audio_assets",
  )
    .select("path").eq("path", publishedPath).maybeSingle();
  if (manifestError) return unavailable();
  if (published) {
    const found = await objectExists(admin, publishedPath);
    if (found === null) return unavailable();
    if (found) return await attach(admin, publishedPath);
  }
  const audioPath = audioPathForUser(user.id, variant.id, textHash);

  const existing = await objectExists(admin, audioPath);
  if (existing === null) return unavailable();
  if (existing) return await attach(admin, audioPath);

  // Include lease acquisition in the 60s budget. Every subsequent fetch and
  // response body is cancelled before the database lease can expire at 90s.
  const deadline = workDeadline();
  const leasedAdmin = client(serviceRoleKey, deadline);
  const { data: lease, error: leaseError } = await leasedAdmin.rpc(
    "acquire_audio_generation",
    {
      p_user_id: user.id,
      p_path: audioPath,
    },
  );
  if (leaseError) return response({ error: "Audio unavailable" }, 503);
  if (!lease) {
    return response({ error: "Audio generation already in progress" }, 429);
  }
  let paidWorkPending = false;
  try {
    // Recheck after acquisition: another request may have completed between
    // this request's first cache check and acquiring the now-released lease.
    const cachedAfterLock = await objectExists(leasedAdmin, audioPath);
    if (cachedAfterLock === null) return unavailable();
    if (cachedAfterLock) return await attach(leasedAdmin, audioPath);
    const elevenLabsKey = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
    if (!elevenLabsKey) return response({ error: "TTS unavailable" }, 503);
    const { data: quota, error: quotaError } = await leasedAdmin.rpc(
      "consume_provider_quota",
      { p_user_id: user.id, p_metric: "audio_provision" },
    );
    if (quotaError || typeof quota?.allowed !== "boolean") return unavailable();
    if (!quota.allowed) {
      return response({ error: "Daily audio limit reached" }, 429);
    }

    deadline.throwIfAborted();
    paidWorkPending = true;
    const tts = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voice.id}?output_format=mp3_22050_32`,
      {
        method: "POST",
        signal: deadline,
        headers: {
          "xi-api-key": elevenLabsKey,
          "Content-Type": "application/json",
          Accept: "audio/mpeg",
        },
        body: JSON.stringify({
          text,
          model_id: "eleven_multilingual_v2",
          voice_settings: {
            stability: 0.5,
            similarity_boost: 0.8,
            style: 0,
            use_speaker_boost: true,
          },
        }),
      },
    );
    if (!tts.ok) return response({ error: "TTS generation failed" }, 502);

    const { error: uploadError } = await leasedAdmin.storage.from(bucket)
      .upload(
        audioPath,
        new Uint8Array(await tts.arrayBuffer()),
        { contentType: "audio/mpeg", cacheControl: "31536000", upsert: false },
      );
    if (deadline.aborted) return unavailable();
    // A concurrent request may have won the immutable upload race; either way,
    // the object now exists and the variant can safely reference it.
    if (uploadError && !/already exists/i.test(uploadError.message)) {
      return response({ error: "Audio storage failed" }, 502);
    }
    paidWorkPending = false;

    return await attach(leasedAdmin, audioPath);
  } catch (_) {
    return deadline.aborted
      ? unavailable()
      : response({ error: "Audio unavailable" }, 502);
  } finally {
    // Transport cancellation cannot confirm a remote write or render stopped.
    // Leave the token in place until it expires if paid work is uncertain.
    if (!deadline.aborted && !paidWorkPending) {
      await leasedAdmin.rpc("release_audio_generation", {
        p_path: audioPath,
        p_token: lease,
      });
    }
  }
}
