-- =====================================================================
--  SWIFLY: COMPLETE DATABASE
--  Supabase dashboard -> SQL Editor -> New query -> paste this WHOLE file -> Run.
--  Safe to run again. Creates every table, trigger, policy, function,
--  realtime channel and the avatar storage bucket the app uses.
--  Replaces the old schema.sql + auth_setup.sql (do not run those any more).
-- =====================================================================

-- ---------- 1. PROFILES (one row per account, made by a trigger) ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null,
  display_name text not null default '',
  avatar_url text,
  followers_count int not null default 0,
  following_count int not null default 0,
  created_at timestamptz not null default now()
);
alter table public.profiles add column if not exists avatar_url text;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  uname text := lower(coalesce(nullif(new.raw_user_meta_data->>'username', ''), split_part(new.email, '@', 1)));
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    uname,
    coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), uname)
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- 2. POSTS, COMMENTS, LIKES, SAVES ----------
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  text text not null default '' check (char_length(text) <= 5000),
  audience text not null default 'Everyone' check (audience in ('Everyone', 'Followers')),
  tagged_handles text[] not null default '{}',
  likes int not null default 0,
  saves int not null default 0,
  shares int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  parent_id uuid references public.comments(id) on delete cascade,   -- null = top level comment
  author_id uuid not null references public.profiles(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 2000),
  created_at timestamptz not null default now()
);

create table if not exists public.post_likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table if not exists public.post_saves (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

-- ---------- 3. FOLLOWS ----------
create table if not exists public.follows (
  follower uuid not null references public.profiles(id) on delete cascade,
  followee uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower, followee),
  check (follower <> followee)
);

-- ---------- 4. NOTIFICATIONS (written by triggers only) ----------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,   -- like | comment | reply | save | follow | message | storyReact | tag | storyReply
  actor_name text not null default '',
  actor_handle text not null default '',
  post_id uuid,
  comment_id uuid,
  emoji text,
  preview text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- 5. DIRECT MESSAGES ----------
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender uuid not null references public.profiles(id) on delete cascade,
  recipient uuid not null references public.profiles(id) on delete cascade,
  text text not null default '' check (char_length(text) <= 5000),
  reply_to_id uuid references public.messages(id) on delete set null,
  post_id uuid references public.posts(id) on delete set null,
  created_at timestamptz not null default now(),
  check (sender <> recipient)
);

-- ---------- 6. NOTES (shown for 24 hours, the app hides older ones) ----------
create table if not exists public.notes (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 60),
  created_at timestamptz not null default now()
);

-- ---------- 7. PROFILE FIELDS (work, school, city, bio ... one row per field) ----------
create table if not exists public.profile_fields (
  user_id uuid not null references public.profiles(id) on delete cascade,
  key text not null,
  value text not null,
  audience text not null default 'everyone' check (audience in ('onlyMe', 'followers', 'everyone')),
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

-- ---------- 8. TRENDING HASHTAGS + SHARED PROFILE SUGGESTIONS ----------
create table if not exists public.trending_tags (
  tag text primary key,
  uses int not null default 0
);

create table if not exists public.profile_suggestions (
  category text not null,
  title text not null,
  subtitle text not null default '',
  uses int not null default 1,
  primary key (category, title)
);
create index if not exists profile_suggestions_rank on public.profile_suggestions (category, uses desc);

-- ---------- 9. LOGIN CODES (used only by the email-code-auth Edge Function) ----------
create table if not exists public.email_login_codes (
  email text primary key,
  code_hash text not null,
  purpose text not null check (purpose in ('signup', 'password_reset')),
  user_metadata jsonb not null default '{}'::jsonb,
  expires_at timestamptz not null,
  attempts int not null default 0,
  last_sent_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- ---------- Upgrade: add any column an older version of the schema did not have ----------
alter table public.posts add column if not exists audience text not null default 'Everyone';
alter table public.posts add column if not exists tagged_handles text[] not null default '{}';
alter table public.comments add column if not exists parent_id uuid references public.comments(id) on delete cascade;
alter table public.post_likes add column if not exists created_at timestamptz not null default now();
alter table public.post_saves add column if not exists created_at timestamptz not null default now();
alter table public.follows add column if not exists created_at timestamptz not null default now();
alter table public.messages add column if not exists reply_to_id uuid references public.messages(id) on delete set null;
alter table public.messages add column if not exists post_id uuid references public.posts(id) on delete set null;
alter table public.profile_fields add column if not exists updated_at timestamptz not null default now();
alter table public.profile_fields add column if not exists audience text not null default 'everyone';
alter table public.notifications add column if not exists actor_name text not null default '';
alter table public.notifications add column if not exists actor_handle text not null default '';

-- =====================================================================
--  ROW LEVEL SECURITY: turn it on for every table
-- =====================================================================
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_saves enable row level security;
alter table public.follows enable row level security;
alter table public.notifications enable row level security;
alter table public.messages enable row level security;
alter table public.notes enable row level security;
alter table public.profile_fields enable row level security;
alter table public.trending_tags enable row level security;
alter table public.profile_suggestions enable row level security;
alter table public.email_login_codes enable row level security;
revoke all on public.email_login_codes from anon, authenticated;

-- ---------- profiles: everyone signed in can read; you edit only your name and photo ----------
drop policy if exists "profiles readable" on public.profiles;
create policy "profiles readable" on public.profiles for select to authenticated using (true);
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);
revoke update on public.profiles from anon, authenticated;
grant update (display_name, avatar_url) on public.profiles to authenticated;

-- ---------- posts: Everyone posts are public; Followers posts need a follow ----------
drop policy if exists "posts visible" on public.posts;
create policy "posts visible" on public.posts for select to authenticated using (
  audience = 'Everyone'
  or author_id = auth.uid()
  or exists (select 1 from public.follows f where f.follower = auth.uid() and f.followee = posts.author_id)
);
drop policy if exists "posts insert own" on public.posts;
create policy "posts insert own" on public.posts for insert to authenticated with check (author_id = auth.uid());
drop policy if exists "posts delete own" on public.posts;
create policy "posts delete own" on public.posts for delete to authenticated using (author_id = auth.uid());

-- ---------- comments: you can read comments on posts you can see ----------
drop policy if exists "comments visible" on public.comments;
create policy "comments visible" on public.comments for select to authenticated using (
  exists (select 1 from public.posts p where p.id = comments.post_id)
);
drop policy if exists "comments insert own" on public.comments;
create policy "comments insert own" on public.comments for insert to authenticated with check (
  author_id = auth.uid() and exists (select 1 from public.posts p where p.id = comments.post_id)
);
drop policy if exists "comments delete own" on public.comments;
create policy "comments delete own" on public.comments for delete to authenticated using (author_id = auth.uid());

-- ---------- likes: counts are public, you change only your own ----------
drop policy if exists "likes read" on public.post_likes;
create policy "likes read" on public.post_likes for select to authenticated using (true);
drop policy if exists "likes insert own" on public.post_likes;
create policy "likes insert own" on public.post_likes for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "likes delete own" on public.post_likes;
create policy "likes delete own" on public.post_likes for delete to authenticated using (user_id = auth.uid());

-- ---------- saves: private. You see your saves, and the author sees who saved (for the notification) ----------
drop policy if exists "saves read" on public.post_saves;
create policy "saves read" on public.post_saves for select to authenticated using (
  user_id = auth.uid()
  or exists (select 1 from public.posts p where p.id = post_saves.post_id and p.author_id = auth.uid())
);
drop policy if exists "saves insert own" on public.post_saves;
create policy "saves insert own" on public.post_saves for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "saves delete own" on public.post_saves;
create policy "saves delete own" on public.post_saves for delete to authenticated using (user_id = auth.uid());

-- ---------- follows ----------
drop policy if exists "follows read" on public.follows;
create policy "follows read" on public.follows for select to authenticated using (true);
drop policy if exists "follows insert own" on public.follows;
create policy "follows insert own" on public.follows for insert to authenticated with check (follower = auth.uid());
drop policy if exists "follows delete own" on public.follows;
create policy "follows delete own" on public.follows for delete to authenticated using (follower = auth.uid());

-- ---------- notifications: you see and update only your own ----------
drop policy if exists "notifications read own" on public.notifications;
create policy "notifications read own" on public.notifications for select to authenticated using (user_id = auth.uid());
drop policy if exists "notifications update own" on public.notifications;
create policy "notifications update own" on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "notifications delete own" on public.notifications;
create policy "notifications delete own" on public.notifications for delete to authenticated using (user_id = auth.uid());

-- ---------- messages: only the two people in the chat ----------
drop policy if exists "messages read" on public.messages;
create policy "messages read" on public.messages for select to authenticated
  using (sender = auth.uid() or recipient = auth.uid());
drop policy if exists "messages insert own" on public.messages;
create policy "messages insert own" on public.messages for insert to authenticated with check (sender = auth.uid());
drop policy if exists "messages delete own" on public.messages;
create policy "messages delete own" on public.messages for delete to authenticated using (sender = auth.uid());

-- ---------- notes: you manage yours; people who follow you can read it ----------
drop policy if exists "notes own all" on public.notes;
create policy "notes own all" on public.notes for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "notes followers read" on public.notes;
create policy "notes followers read" on public.notes for select to authenticated using (
  exists (select 1 from public.follows f where f.follower = auth.uid() and f.followee = notes.user_id)
);

-- ---------- profile fields: onlyMe = you, followers = your followers, everyone = all ----------
drop policy if exists "profile fields own all" on public.profile_fields;
create policy "profile fields own all" on public.profile_fields for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "profile fields public read" on public.profile_fields;
create policy "profile fields public read" on public.profile_fields for select to authenticated using (
  audience = 'everyone'
  or (audience = 'followers' and exists (
        select 1 from public.follows f where f.follower = auth.uid() and f.followee = profile_fields.user_id))
);

-- ---------- trending tags and suggestions: readable by everyone signed in (written by functions) ----------
drop policy if exists "trending read" on public.trending_tags;
create policy "trending read" on public.trending_tags for select to authenticated using (true);
drop policy if exists "suggestions read" on public.profile_suggestions;
create policy "suggestions read" on public.profile_suggestions for select to authenticated using (true);

-- =====================================================================
--  TRIGGERS: counts and notifications are kept by the database itself
-- =====================================================================

-- Helper: create one notification for [p_user] from [p_actor]. Nothing for yourself.
create or replace function public.swifly_notify(
  p_user uuid, p_actor uuid, p_type text,
  p_post uuid, p_comment uuid, p_emoji text, p_preview text
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_name text;
  v_handle text;
begin
  if p_user is null or p_actor is null or p_user = p_actor then
    return;
  end if;
  select coalesce(nullif(display_name, ''), username), '@' || username
    into v_name, v_handle
    from public.profiles where id = p_actor;
  if v_handle is null then
    return;
  end if;
  insert into public.notifications (user_id, type, actor_name, actor_handle, post_id, comment_id, emoji, preview)
  values (p_user, p_type, coalesce(v_name, ''), v_handle, p_post, p_comment, p_emoji, p_preview);
end $$;

-- Likes
create or replace function public.swifly_on_like() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_author uuid;
begin
  if tg_op = 'INSERT' then
    update public.posts set likes = likes + 1 where id = new.post_id;
    select author_id into v_author from public.posts where id = new.post_id;
    perform public.swifly_notify(v_author, new.user_id, 'like', new.post_id, null, null, null);
  else
    update public.posts set likes = greatest(likes - 1, 0) where id = old.post_id;
  end if;
  return null;
end $$;

drop trigger if exists post_likes_count on public.post_likes;
create trigger post_likes_count
  after insert or delete on public.post_likes
  for each row execute function public.swifly_on_like();

-- Saves
create or replace function public.swifly_on_save() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_author uuid;
begin
  if tg_op = 'INSERT' then
    update public.posts set saves = saves + 1 where id = new.post_id;
    select author_id into v_author from public.posts where id = new.post_id;
    perform public.swifly_notify(v_author, new.user_id, 'save', new.post_id, null, null, null);
  else
    update public.posts set saves = greatest(saves - 1, 0) where id = old.post_id;
  end if;
  return null;
end $$;

drop trigger if exists post_saves_count on public.post_saves;
create trigger post_saves_count
  after insert or delete on public.post_saves
  for each row execute function public.swifly_on_save();

-- Comments and replies
create or replace function public.swifly_on_comment() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_target uuid;
begin
  if new.parent_id is null then
    select author_id into v_target from public.posts where id = new.post_id;
    perform public.swifly_notify(v_target, new.author_id, 'comment', new.post_id, new.id, null, left(new.text, 120));
  else
    select author_id into v_target from public.comments where id = new.parent_id;
    perform public.swifly_notify(v_target, new.author_id, 'reply', new.post_id, new.id, null, left(new.text, 120));
  end if;
  return new;
end $$;

drop trigger if exists comments_notify on public.comments;
create trigger comments_notify
  after insert on public.comments
  for each row execute function public.swifly_on_comment();

-- Follows (follower counts + notification)
create or replace function public.swifly_on_follow() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.profiles set followers_count = followers_count + 1 where id = new.followee;
    update public.profiles set following_count = following_count + 1 where id = new.follower;
    perform public.swifly_notify(new.followee, new.follower, 'follow', null, null, null, null);
  else
    update public.profiles set followers_count = greatest(followers_count - 1, 0) where id = old.followee;
    update public.profiles set following_count = greatest(following_count - 1, 0) where id = old.follower;
  end if;
  return null;
end $$;

drop trigger if exists follows_counts on public.follows;
create trigger follows_counts
  after insert or delete on public.follows
  for each row execute function public.swifly_on_follow();

-- New post: tag notifications + trending hashtags
create or replace function public.swifly_on_post() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  h text;
  v_user uuid;
begin
  for h in select distinct t from unnest(new.tagged_handles) as t loop
    select id into v_user from public.profiles where username = lower(ltrim(h, '@'));
    perform public.swifly_notify(v_user, new.author_id, 'tag', new.id, null, null, null);
  end loop;

  for h in select distinct lower(m[1]) from regexp_matches(new.text, '#([[:alnum:]_]+)', 'g') as m loop
    insert into public.trending_tags (tag, uses) values (h, 1)
    on conflict (tag) do update set uses = public.trending_tags.uses + 1;
  end loop;
  return new;
end $$;

drop trigger if exists posts_after_insert on public.posts;
create trigger posts_after_insert
  after insert on public.posts
  for each row execute function public.swifly_on_post();

-- New message: notify the recipient
create or replace function public.swifly_on_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.swifly_notify(new.recipient, new.sender, 'message', null, null, null, left(new.text, 120));
  return new;
end $$;

drop trigger if exists messages_notify on public.messages;
create trigger messages_notify
  after insert on public.messages
  for each row execute function public.swifly_on_message();

-- =====================================================================
--  FUNCTIONS CALLED BY THE APP (RPC)
-- =====================================================================

-- Shares: how many people a post was sent to (from the share sheet).
create or replace function public.increment_post_shares(p_post_id uuid, p_count int)
returns void language sql security definer set search_path = public as $$
  update public.posts
     set shares = shares + least(greatest(p_count, 0), 50)
   where id = p_post_id
     and auth.uid() is not null
     and (
       audience = 'Everyone'
       or author_id = auth.uid()
       or exists (select 1 from public.follows f where f.follower = auth.uid() and f.followee = posts.author_id)
     );
$$;

-- Suggestions: search what other people typed for a field (company, school, hobby ...).
create or replace function public.search_profile_suggestions(p_category text, p_query text, p_limit int default 6)
returns table(title text, subtitle text)
language sql stable security definer set search_path = public as $$
  select s.title, s.subtitle
    from public.profile_suggestions s
   where s.category = p_category
     and s.title ilike (replace(replace(p_query, '%', '\%'), '_', '\_') || '%')
   order by s.uses desc, s.title
   limit p_limit;
$$;

-- Suggestions: count one use so popular values rise for everyone.
create or replace function public.record_profile_suggestion(p_category text, p_value text)
returns void language sql security definer set search_path = public as $$
  insert into public.profile_suggestions (category, title, subtitle, uses)
  select p_category, trim(p_value), '', 1
   where auth.uid() is not null and length(trim(p_value)) between 1 and 60
  on conflict (category, title) do update set uses = public.profile_suggestions.uses + 1;
$$;

revoke all on function public.increment_post_shares(uuid, int) from public, anon;
grant execute on function public.increment_post_shares(uuid, int) to authenticated;
revoke all on function public.search_profile_suggestions(text, text, int) from public, anon;
grant execute on function public.search_profile_suggestions(text, text, int) to authenticated;
revoke all on function public.record_profile_suggestion(text, text) from public, anon;
grant execute on function public.record_profile_suggestion(text, text) to authenticated;

-- =====================================================================
--  MEDIA AND STORIES (photos and videos in posts, 24-hour stories)
-- =====================================================================

-- ---------- POST MEDIA: photos and videos attached to a post (up to 10) ----------
create table if not exists public.post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  position int not null default 0 check (position between 0 and 9),
  kind text not null check (kind in ('photo', 'video')),
  storage_path text not null,            -- path inside the 'post-media' bucket
  thumb_path text,                       -- path of the small preview image
  width int not null default 0,
  height int not null default 0,
  duration_ms int not null default 0,
  engine text not null default '',       -- which processor made it (php-gd, php, cpp-fallback)
  created_at timestamptz not null default now(),
  unique (post_id, position)
);

-- ---------- STORIES: one editor document per story, gone after 24 hours ----------
create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  bg_color bigint,                       -- ARGB colour, e.g. 4280119260
  photo_path text,                       -- path inside the 'stories' bucket
  photo_scale double precision not null default 1,
  photo_dx double precision not null default 0,     -- fraction of the story width
  photo_dy double precision not null default 0,     -- fraction of the story height
  photo_rotation double precision not null default 0,
  layers jsonb not null default '[]'::jsonb,        -- text, sticker and place layers
  place text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);
create index if not exists stories_author_time on public.stories (author_id, created_at desc);

-- ---------- STORY REACTIONS (emoji taps) ----------
create table if not exists public.story_reactions (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.stories(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now()
);

-- ---------- STORY REPLIES (a message sent about a story) ----------
create table if not exists public.story_replies (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.stories(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 1000),
  created_at timestamptz not null default now()
);

-- ---------- RLS ----------
alter table public.post_media enable row level security;
alter table public.stories enable row level security;
alter table public.story_reactions enable row level security;
alter table public.story_replies enable row level security;

-- Photos and videos follow the visibility of their post.
drop policy if exists "post media visible" on public.post_media;
create policy "post media visible" on public.post_media for select to authenticated using (
  exists (select 1 from public.posts p where p.id = post_media.post_id)
);
drop policy if exists "post media insert own" on public.post_media;
create policy "post media insert own" on public.post_media for insert to authenticated with check (
  exists (select 1 from public.posts p where p.id = post_media.post_id and p.author_id = auth.uid())
);
drop policy if exists "post media delete own" on public.post_media;
create policy "post media delete own" on public.post_media for delete to authenticated using (
  exists (select 1 from public.posts p where p.id = post_media.post_id and p.author_id = auth.uid())
);

-- A story is seen by its author and by people who follow the author, until it expires.
drop policy if exists "stories visible" on public.stories;
create policy "stories visible" on public.stories for select to authenticated using (
  author_id = auth.uid()
  or (expires_at > now() and exists (
        select 1 from public.follows f where f.follower = auth.uid() and f.followee = stories.author_id))
);
drop policy if exists "stories insert own" on public.stories;
create policy "stories insert own" on public.stories for insert to authenticated with check (author_id = auth.uid());
drop policy if exists "stories update own" on public.stories;
create policy "stories update own" on public.stories for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());
drop policy if exists "stories delete own" on public.stories;
create policy "stories delete own" on public.stories for delete to authenticated using (author_id = auth.uid());

-- Reactions and replies: you can react to or reply to a story you can see.
-- The author sees all reactions and replies on their story; others see their own.
drop policy if exists "story reactions read" on public.story_reactions;
create policy "story reactions read" on public.story_reactions for select to authenticated using (
  user_id = auth.uid()
  or exists (select 1 from public.stories s where s.id = story_reactions.story_id and s.author_id = auth.uid())
);
drop policy if exists "story reactions insert own" on public.story_reactions;
create policy "story reactions insert own" on public.story_reactions for insert to authenticated with check (
  user_id = auth.uid() and exists (select 1 from public.stories s where s.id = story_reactions.story_id)
);
drop policy if exists "story reactions delete own" on public.story_reactions;
create policy "story reactions delete own" on public.story_reactions for delete to authenticated using (user_id = auth.uid());

drop policy if exists "story replies read" on public.story_replies;
create policy "story replies read" on public.story_replies for select to authenticated using (
  user_id = auth.uid()
  or exists (select 1 from public.stories s where s.id = story_replies.story_id and s.author_id = auth.uid())
);
drop policy if exists "story replies insert own" on public.story_replies;
create policy "story replies insert own" on public.story_replies for insert to authenticated with check (
  user_id = auth.uid() and exists (select 1 from public.stories s where s.id = story_replies.story_id)
);
drop policy if exists "story replies delete own" on public.story_replies;
create policy "story replies delete own" on public.story_replies for delete to authenticated using (user_id = auth.uid());

-- ---------- TRIGGERS: tell the story author about reactions and replies ----------
create or replace function public.swifly_on_story_reaction() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_author uuid;
begin
  select author_id into v_author from public.stories where id = new.story_id;
  perform public.swifly_notify(v_author, new.user_id, 'storyReact', null, null, new.emoji, null);
  return new;
end $$;

drop trigger if exists story_reactions_notify on public.story_reactions;
create trigger story_reactions_notify
  after insert on public.story_reactions
  for each row execute function public.swifly_on_story_reaction();

create or replace function public.swifly_on_story_reply() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_author uuid;
begin
  select author_id into v_author from public.stories where id = new.story_id;
  perform public.swifly_notify(v_author, new.user_id, 'storyReply', null, null, null, left(new.text, 120));
  return new;
end $$;

drop trigger if exists story_replies_notify on public.story_replies;
create trigger story_replies_notify
  after insert on public.story_replies
  for each row execute function public.swifly_on_story_reply();

-- ---------- LIVE UPDATES for the new tables ----------
do $$
declare t text;
begin
  foreach t in array array['post_media', 'stories', 'story_reactions', 'story_replies'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ---------- STORAGE: post photos/videos and story photos (public read, own folder to write) ----------
insert into storage.buckets (id, name, public) values ('post-media', 'post-media', true)
on conflict (id) do update set public = true;
insert into storage.buckets (id, name, public) values ('stories', 'stories', true)
on conflict (id) do update set public = true;

drop policy if exists "post-media public read" on storage.objects;
create policy "post-media public read" on storage.objects for select using (bucket_id = 'post-media');
drop policy if exists "post-media own insert" on storage.objects;
create policy "post-media own insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'post-media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "post-media own delete" on storage.objects;
create policy "post-media own delete" on storage.objects for delete to authenticated
  using (bucket_id = 'post-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "stories public read" on storage.objects;
create policy "stories public read" on storage.objects for select using (bucket_id = 'stories');
drop policy if exists "stories own insert" on storage.objects;
create policy "stories own insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'stories' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "stories own delete" on storage.objects;
create policy "stories own delete" on storage.objects for delete to authenticated
  using (bucket_id = 'stories' and (storage.foldername(name))[1] = auth.uid()::text);

-- =====================================================================
--  LIVE UPDATES: the app listens to these tables (Supabase Realtime)
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array['posts', 'comments', 'post_likes', 'post_saves', 'follows',
                           'messages', 'notes', 'notifications'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- Deleted rows must say which person they were about (follows, notes).
alter table public.follows replica identity full;
alter table public.notes replica identity full;

-- =====================================================================
--  STORAGE: profile pictures (public read, you can only write your own folder)
-- =====================================================================
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

drop policy if exists "avatars public read" on storage.objects;
create policy "avatars public read" on storage.objects for select using (bucket_id = 'avatars');

drop policy if exists "avatars own insert" on storage.objects;
create policy "avatars own insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatars own update" on storage.objects;
create policy "avatars own update" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

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
