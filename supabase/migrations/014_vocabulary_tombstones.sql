-- A stale outbound snapshot must never revive an already deleted row.
CREATE FUNCTION public.keep_vocabulary_tombstone()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF OLD.is_deleted THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER vocabulary_lists_keep_tombstone
BEFORE UPDATE ON public.vocabulary_lists
FOR EACH ROW EXECUTE FUNCTION public.keep_vocabulary_tombstone();

-- Lock parents until the write commits. Lock from the nearest parent outward
-- so an edit and a concurrent deletion agree on which one happened first.
CREATE FUNCTION public.guard_vocabulary_child_tombstone()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  parent_list_id uuid;
  parent_concept_deleted boolean;
  parent_list_deleted boolean;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.is_deleted THEN
      RETURN OLD;
    END IF;
    -- A synced content ID belongs to its original parent.
    IF TG_TABLE_NAME = 'concepts' THEN
      NEW.list_id := OLD.list_id;
    ELSE
      NEW.concept_id := OLD.concept_id;
    END IF;
  END IF;

  IF TG_TABLE_NAME = 'concepts' THEN
    parent_list_id := NEW.list_id;
  ELSE
    SELECT c.list_id, c.is_deleted INTO parent_list_id, parent_concept_deleted
    FROM public.concepts AS c WHERE c.id = NEW.concept_id FOR SHARE;
  END IF;

  SELECT l.is_deleted INTO parent_list_deleted
  FROM public.vocabulary_lists AS l WHERE l.id = parent_list_id FOR SHARE;

  IF parent_concept_deleted OR parent_list_deleted THEN
    IF TG_OP = 'UPDATE' THEN
      NEW := OLD;
    END IF;
    NEW.is_deleted := true;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER concepts_guard_tombstone
BEFORE INSERT OR UPDATE ON public.concepts
FOR EACH ROW EXECUTE FUNCTION public.guard_vocabulary_child_tombstone();

CREATE TRIGGER word_variants_guard_tombstone
BEFORE INSERT OR UPDATE ON public.word_variants
FOR EACH ROW EXECUTE FUNCTION public.guard_vocabulary_child_tombstone();

REVOKE ALL ON FUNCTION public.keep_vocabulary_tombstone() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.guard_vocabulary_child_tombstone() FROM PUBLIC;
