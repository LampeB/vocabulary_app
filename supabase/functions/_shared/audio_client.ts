import { createClient } from "npm:@supabase/supabase-js@2.119.2";

/** Bound all HTTP phases, including RPC, Storage and their response bodies. */
export function createAudioClient(
  url: string,
  key: string,
  deadline?: AbortSignal,
) {
  return createClient(url, key, {
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
}
