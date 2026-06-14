import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const ELEVENLABS_API_KEY = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
const ELEVENLABS_MODEL = "eleven_multilingual_v2";

const VOICE_MAP: Record<string, string> = {
  Charlotte: "XB0fDUnXU5powFXDhCwa",
  Elli: "MF3mGyEYCl7XYWbV9V6O",
  Rachel: "21m00Tcm4TlvDq8ikWAM",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  try {
    const { text, voice_id, lang_code } = await req.json();
    if (!text) {
      return Response.json({ error: "Missing text" }, { status: 400 });
    }

    const voiceId = VOICE_MAP[voice_id] ?? VOICE_MAP["Charlotte"];

    const ttsRes = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
      {
        method: "POST",
        headers: {
          "xi-api-key": ELEVENLABS_API_KEY,
          "Content-Type": "application/json",
          Accept: "audio/mpeg",
        },
        body: JSON.stringify({
          text,
          model_id: ELEVENLABS_MODEL,
          voice_settings: {
            stability: 0.5,
            similarity_boost: 0.8,
            style: 0.0,
            use_speaker_boost: true,
          },
        }),
      }
    );

    if (!ttsRes.ok) {
      return Response.json(
        { error: "ElevenLabs error" },
        { status: ttsRes.status }
      );
    }

    const audioBytes = await ttsRes.arrayBuffer();

    return new Response(audioBytes, {
      headers: {
        "Content-Type": "audio/mpeg",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (e) {
    return Response.json(
      { error: String(e) },
      {
        status: 500,
        headers: { "Access-Control-Allow-Origin": "*" },
      }
    );
  }
});
