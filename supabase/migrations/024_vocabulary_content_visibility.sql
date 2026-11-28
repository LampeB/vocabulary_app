BEGIN;

-- Shared reads inherit the visible, active parent in the same owner namespace.
-- The existing owner policies still expose the owner's tombstones for sync.
ALTER POLICY concepts_public_read ON public.concepts RENAME TO concepts_shared_read;
ALTER POLICY concepts_shared_read ON public.concepts
  USING (is_deleted IS NOT TRUE AND EXISTS (
    SELECT 1 FROM public.vocabulary_lists l
    WHERE l.owner_id = concepts.owner_id AND l.id = concepts.list_id
      AND l.is_deleted IS NOT TRUE
  ));

-- Concept RLS already checks the list for non-owners.
ALTER POLICY variants_public_read ON public.word_variants RENAME TO variants_shared_read;
ALTER POLICY variants_shared_read ON public.word_variants
  USING (is_deleted IS NOT TRUE AND EXISTS (
    SELECT 1 FROM public.concepts c
    WHERE c.owner_id = word_variants.owner_id AND c.id = word_variants.concept_id
      AND c.is_deleted IS NOT TRUE
  ));

COMMIT;
