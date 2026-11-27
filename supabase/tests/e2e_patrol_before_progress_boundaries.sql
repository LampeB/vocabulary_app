-- Check the RPC the current Patrol client reads, on a disposable 016 or 017 schema.
BEGIN;
SET LOCAL ROLE anon;
DO $$ BEGIN
  IF public.e2e_patrol_contract() IS DISTINCT FROM 'write-order-v1' THEN
    RAISE EXCEPTION 'Expected the previous Patrol contract before migration 018';
  END IF;
END $$;
ROLLBACK;
