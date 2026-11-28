import { handleAudioProvision } from "./handler.ts";

Deno.serve((req) => handleAudioProvision(req));
