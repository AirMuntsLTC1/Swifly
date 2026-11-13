-- Run AFTER schema.sql. Sets up custom email-code sign in.

-- 1. One row per email waiting for a code. Only the Edge Function (service role)
--    can touch it: RLS is on and there are no policies on purpose.
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
alter table public.email_login_codes enable row level security;
revoke all on public.email_login_codes from anon, authenticated;

-- 2. Create the profile automatically when the function creates the user.
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

-- 3. Profiles: everyone signed in can read, you can only edit your own.
alter table public.profiles enable row level security;
drop policy if exists "profiles readable" on public.profiles;
create policy "profiles readable" on public.profiles for select to authenticated using (true);
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles for update to authenticated using (auth.uid() = id);
