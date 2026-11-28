import {
  StorageApiError,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.119.2";

/** Only Storage's explicit object-missing response permits paid generation. */
export async function storageObjectExists(
  client: SupabaseClient,
  bucket: string,
  path: string,
): Promise<boolean | null> {
  try {
    const { error } = await client.storage.from(bucket).info(path);
    if (!error) return true;
    if (
      error instanceof StorageApiError && error.code === "NoSuchKey" &&
      (error.status === 404 ||
        (error.status === 400 && error.statusCode === "404"))
    ) return false;
  } catch (_) {
    // A transport failure leaves presence unknown, never absent.
  }
  return null;
}
