-- Swifly tables. Column names match DatabaseService read methods exactly.
-- Run in Supabase SQL editor. Add Row Level Security policies before launch.

create table if not exists profiles (
  id uuid primary key references auth.users on delete cascade,
  handle text unique not null,            -- '@yourhandle'
  name text not null,
  followers_count int not null default 0,
  following_count int not null default 0
);

create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid references profiles(id) on delete cascade,
  text text not null default '',
  audience text not null default 'Everyone',   -- Everyone | Followers
  tagged_handles text[] not null default '{}',
  likes int not null default 0,
  saves int not null default 0,
  shares int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references posts(id) on delete cascade,
  parent_id uuid references comments(id) on delete cascade,  -- null = top level
  author_id uuid references profiles(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now()
);

create table if not exists follows (
  follower uuid references profiles(id) on delete cascade,
  followee uuid references profiles(id) on delete cascade,
  primary key (follower, followee)
);

create table if not exists post_likes (user_id uuid, post_id uuid, primary key (user_id, post_id));
create table if not exists post_saves (user_id uuid, post_id uuid, primary key (user_id, post_id));

create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  type text not null,   -- like comment reply save follow message storyReact tag storyReply
  actor_handle text not null,
  actor_name text not null,
  post_id uuid, comment_id uuid, emoji text, preview text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  sender uuid references profiles(id) on delete cascade,
  recipient uuid references profiles(id) on delete cascade,
  text text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists notes (
  user_id uuid primary key references profiles(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now()   -- expires after 24h in the app
);

create table if not exists profile_fields (
  user_id uuid references profiles(id) on delete cascade,
  key text not null, value text not null,
  audience text not null default 'everyone',      -- onlyMe | followers | everyone
  primary key (user_id, key)
);

create table if not exists trending_tags (tag text primary key, uses int not null default 0);
