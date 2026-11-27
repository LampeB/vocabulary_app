export async function canPublishSeedAudio(
  headers: Headers,
  supabaseUrl: string,
  anonKey: string,
): Promise<boolean> {
  const apiKey = headers.get("apikey");
  const authorization = headers.get("Authorization");
  // Supabase's gateway resolves modern API keys from apikey. For a legacy
  // credential, Auth verifies the bearer JWT and requires the service role.
  // Either way, authenticate the credential supplied by the caller.
  let credentials: HeadersInit;
  if (apiKey?.startsWith("sb_secret_")) {
    credentials = { apikey: apiKey };
  } else if (
    authorization && /^Bearer [\w-]+\.[\w-]+\.[\w-]+$/i.test(authorization)
  ) {
    credentials = { apikey: anonKey, Authorization: authorization };
  } else {
    return false;
  }

  try {
    const response = await fetch(
      `${supabaseUrl}/auth/v1/admin/users?page=1&per_page=1`,
      {
        signal: AbortSignal.timeout(10_000),
        redirect: "error",
        headers: credentials,
      },
    );
    await response.body?.cancel();
    return response.ok;
  } catch {
    return false;
  }
}
