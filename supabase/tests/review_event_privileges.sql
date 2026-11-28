-- Exercise effective grants, including the bootstrap's Supabase-style defaults.
DO $$
DECLARE operation text;
BEGIN
  FOREACH operation IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE'] LOOP
    IF NOT has_table_privilege('authenticated','public.review_events',operation) THEN
      RAISE EXCEPTION 'Review events lost the authenticated % privilege', operation;
    END IF;
  END LOOP;
  IF has_table_privilege('authenticated','public.review_events','TRUNCATE,REFERENCES,TRIGGER')
    OR has_table_privilege('anon','public.review_events','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN
    RAISE EXCEPTION 'Review events retained unintended client privileges';
  END IF;
END $$;
