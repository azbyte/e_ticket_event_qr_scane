-- Apply once in the Supabase SQL editor before starting the backend with
-- SEED_DEMO_ACCOUNTS=true. Existing tables and event data are preserved.
alter table public.profiles add column if not exists username text;
alter table public.profiles alter column password_hash drop not null;
alter table public.profiles add column if not exists disabled_at timestamptz;
create table if not exists public.revoked_tokens (
  token_hash text primary key,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists revoked_tokens_expires_at_idx on public.revoked_tokens(expires_at);
create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username)) where username is not null;

create table if not exists public.event_members (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'staff' check (role = 'staff'),
  created_at timestamptz not null default now(),
  constraint event_members_event_user_unique unique (event_id, user_id)
);

create index if not exists events_created_by_idx on public.events(created_by);
create index if not exists event_members_user_id_idx on public.event_members(user_id);

alter table public.profiles enable row level security;
alter table public.events enable row level security;
alter table public.event_members enable row level security;
alter table public.revoked_tokens enable row level security;

-- All role-aware API reads/writes use the server-side service-role client after
-- applying JWT and ownership checks; end-user app clients have no table access.
drop policy if exists "server managed profiles" on public.profiles;
drop policy if exists "server managed events" on public.events;
drop policy if exists "server managed event members" on public.event_members;
create policy "server managed profiles" on public.profiles for all to authenticated using (false) with check (false);
create policy "server managed events" on public.events for all to authenticated using (false) with check (false);
create policy "server managed event members" on public.event_members for all to authenticated using (false) with check (false);
drop policy if exists "server managed revoked tokens" on public.revoked_tokens;
create policy "server managed revoked tokens" on public.revoked_tokens for all to authenticated using (false) with check (false);

-- Remove direct table access for mobile/anonymous clients; only the backend's
-- service-role client can access these records after API authorization checks.
revoke all on public.profiles, public.events, public.event_members, public.revoked_tokens from anon, authenticated;
grant all on public.profiles, public.events, public.event_members, public.revoked_tokens to service_role;