import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
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

const elevenLabsApiKey = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
// 30 seconds of mono 16 kHz PCM once base64-encoded.
const maxAudioBase64Chars = 1_280_128;
const languageCodes: Record<string, string> = {
  fr: "fra",
  ko: "kor",
  en: "eng",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return Response.json(
      { error: "Method not allowed" },
      { status: 405, headers: corsHeaders },
    );
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
  try {
    if (!elevenLabsApiKey) {
      return Response.json(
        { error: "Speech service is not configured" },
        { status: 503, headers: corsHeaders },
      );
    }

    const { audio_base64, audio_format, language, expected_word } =
      await readSpeechRequest(req);
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

    const response = await fetch(
      "https://api.elevenlabs.io/v1/speech-to-text",
      {
        method: "POST",
        headers: { "xi-api-key": elevenLabsApiKey },
        body: formData,
        signal: AbortSignal.timeout(60_000),
      },
    );
    if (!response.ok) {
      // Provider details can contain subscription information; never relay it.
      return Response.json(
        { error: "Speech transcription failed" },
        { status: 502, headers: corsHeaders },
      );
    }
    const data = await response.json();
    return Response.json(
      { text: typeof data.text === "string" ? data.text.trim() : "" },
      { headers: corsHeaders },
    );
  } catch (_) {
    return Response.json(
      { error: "Invalid transcription request" },
      { status: 400, headers: corsHeaders },
    );
  } finally {
    await permit.release();
  }
});
