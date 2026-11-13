
-- =====================================================================
--  DONE. Next: deploy the two Edge Functions and set their secrets (see AUTH_SETUP.md).
-- =====================================================================

-- =====================================================================
--  CHECK: run this query by itself in the SQL Editor AFTER the file above.
--  It must return NO rows. Each row it does return is missing: run the
--  whole schema.sql file again (it is safe to run again).
-- =====================================================================
select 'table ' || v.name as missing
from (values
  ('public.profiles'), ('public.posts'), ('public.comments'), ('public.post_likes'),
  ('public.post_saves'), ('public.follows'), ('public.notifications'), ('public.messages'),
  ('public.notes'), ('public.profile_fields'), ('public.trending_tags'),
  ('public.profile_suggestions'), ('public.email_login_codes'), ('public.post_media'),
  ('public.stories'), ('public.story_reactions'), ('public.story_replies')
) as v(name)
where to_regclass(v.name) is null
union all
select 'function ' || v.name
from (values
  ('public.swifly_notify'), ('public.search_profile_suggestions'),
  ('public.record_profile_suggestion'), ('public.increment_post_shares')
) as v(name)
where to_regproc(v.name) is null
union all
select 'storage bucket ' || v.name
from (values ('avatars'), ('post-media'), ('stories')) as v(name)
where not exists (select 1 from storage.buckets b where b.id = v.name);
