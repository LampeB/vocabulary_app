import { acquireProviderPermit } from "../_shared/provider_gate.ts";
import {
  decodeSpeechAudio,
  readSpeechRequest,
} from "../_shared/speech_audio.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// 30 seconds of mono 16 kHz PCM once base64-encoded.
const maxAudioBase64Chars = 1_280_128;
const languageCodes: Record<string, string> = {
  fr: "fra",
  ko: "kor",
  en: "eng",
};

const invalidRequest = () =>
  Response.json(
    { error: "Invalid transcription request" },
    { status: 400, headers: corsHeaders },
  );

export async function handleTranscription(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return Response.json(
      { error: "Method not allowed" },
      { status: 405, headers: corsHeaders },
    );
  }
  let body: Record<string, unknown>;
  try {
    body = await readSpeechRequest(req);
  } catch {
    return invalidRequest();
  }
  const permit = await acquireProviderPermit(req, "cloud_stt");
  const quota = permit.status;
  if (quota !== "allowed") {
    return Response.json(
      {
        error: quota === "limited"
          ? "Speech limit reached"
          : "Speech service unavailable",
      },
      {
        status: quota === "limited"
          ? 429
          : quota === "unauthorized"
          ? 401
          : 503,
        headers: corsHeaders,
      },
    );
  }
  let providerInFlight = false;
  try {
    const elevenLabsApiKey = Deno.env.get("ELEVENLABS_API_KEY");
    if (!elevenLabsApiKey) {
      return Response.json(
        { error: "Speech service is not configured" },
        { status: 503, headers: corsHeaders },
      );
    }

    const { audio_base64, audio_format, language, expected_word } = body;
    if (typeof audio_base64 !== "string" || audio_base64.length === 0) {
      return Response.json(
        { error: "Missing audio" },
        { status: 400, headers: corsHeaders },
      );
    }
    if (audio_base64.length > maxAudioBase64Chars) {
      return Response.json(
        { error: "Audio clip is too large" },
        { status: 413, headers: corsHeaders },
      );
    }
    const languageCode = typeof language === "string"
      ? languageCodes[language]
      : undefined;
    if (!languageCode) {
      return Response.json(
        { error: "Unsupported language" },
        { status: 400, headers: corsHeaders },
      );
    }

    const rawPcm = audio_format === "pcm_s16le_16";
    const binary = decodeSpeechAudio(audio_base64, rawPcm);
    const formData = new FormData();
    formData.append(
      "file",
      new Blob([binary.slice().buffer], {
        type: rawPcm ? "audio/pcm" : "audio/wav",
      }),
      rawPcm ? "clip.pcm" : "clip.wav",
    );
    formData.append("model_id", "scribe_v2");
    formData.append("language_code", languageCode);
    if (rawPcm) formData.append("file_format", "pcm_s16le_16");
    formData.append("tag_audio_events", "false");
    // Scribe's keyterm prompt is contextual rather than an unconditional
    // replacement: ideal for a known vocabulary answer in a quiz.
    if (typeof expected_word === "string" && expected_word.trim()) {
      formData.append("keyterms", expected_word.trim());
    }

    providerInFlight = true;
    const response = await fetch(
      "https://api.elevenlabs.io/v1/speech-to-text",
      {
        method: "POST",
        headers: { "xi-api-key": elevenLabsApiKey },
        body: formData,
        signal: AbortSignal.timeout(60_000),
      },
    );
    const responseBody = await response.text();
    providerInFlight = false;
    if (!response.ok) {
      // Provider details can contain subscription information; never relay it.
      return Response.json(
        { error: "Speech transcription failed" },
        { status: 502, headers: corsHeaders },
      );
    }
    const data = JSON.parse(responseBody);
    return Response.json(
      { text: typeof data.text === "string" ? data.text.trim() : "" },
      { headers: corsHeaders },
    );
  } catch {
    return invalidRequest();
  } finally {
    if (!providerInFlight) await permit.release();
  }
}
