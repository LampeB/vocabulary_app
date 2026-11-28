import { handleSeedAudioPublish } from "./handler.ts";

Deno.serve((req) => handleSeedAudioPublish(req));
