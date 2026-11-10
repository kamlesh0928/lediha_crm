-- =====================================================================
-- LEDiHA CRM - part 2: push notifications + quiet CSV imports
-- Run once in: Supabase dashboard -> SQL Editor -> New query -> paste -> Run
-- (0001_schema.sql must have been run before.)
-- =====================================================================

create extension if not exists pg_net with schema extensions;

-- ---------- phones that should receive push alerts ----------
create table if not exists public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  token      text not null unique,
  platform   text,
  updated_at timestamptz not null default now()
);
alter table public.device_tokens enable row level security;
revoke all on public.device_tokens from anon, authenticated;   -- the app only uses the two functions below

create or replace function public.register_device_token(p_token text, p_platform text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not public.is_staff() then
    raise exception 'not allowed';
  end if;
  insert into public.device_tokens (user_id, token, platform)
  values (auth.uid(), p_token, p_platform)
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
end $$;

create or replace function public.unregister_device_token(p_token text)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.device_tokens where token = p_token and user_id = auth.uid();
end $$;

revoke all on function public.register_device_token(text, text) from public, anon;
revoke all on function public.unregister_device_token(text) from public, anon;
grant execute on function public.register_device_token(text, text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;

-- ---------- private settings (not reachable from the app) ----------
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table if not exists private.push_settings (
  id           int primary key default 1 check (id = 1),
  function_url text not null,
  secret       text not null
);

-- ---------- send a push whenever an alert or a chat message is created ----------
create or replace function public.push_on_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare cfg record;
begin
  select * into cfg from private.push_settings where id = 1;
  if not found then return null; end if;            -- push not configured yet: do nothing
  perform net.http_post(
    url     := cfg.function_url,
    body    := jsonb_build_object('table', tg_table_name, 'record', to_jsonb(new)),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', cfg.secret)
  );
  return null;
exception when others then
  return null;                                       -- a failed push must never block saving
end $$;

drop trigger if exists trg_push_notifications on public.notifications;
create trigger trg_push_notifications after insert on public.notifications
  for each row execute function public.push_on_insert();

drop trigger if exists trg_push_messages on public.messages;
create trigger trg_push_messages after insert on public.messages
  for each row execute function public.push_on_insert();

-- ---------- CSV imports must not create one alert per lead ----------
create or replace function public.notify_events() returns trigger
language plpgsql security definer set search_path = public as $$
declare fire boolean;
begin
  if tg_table_name = 'leads' then
    if new.campaign = 'CSV import' then return null; end if;   -- bulk import: stay quiet
    if tg_op = 'INSERT' then fire := new.assigned_to is not null;
    else fire := new.assigned_to is not null and new.assigned_to is distinct from old.assigned_to;
    end if;
    if fire and new.assigned_to is distinct from auth.uid() then
      insert into public.notifications(user_id, title, body, kind, ref_table, ref_id)
      values (new.assigned_to, 'New lead assigned',
              coalesce(new.customer_name, '') || ' - ' || coalesce(new.phone, ''),
              'lead_assigned', 'leads', new.id);
    end if;
    if tg_op = 'INSERT' and new.assigned_to is null and new.created_by is null then
      insert into public.notifications(user_id, title, body, kind, ref_table, ref_id)
      select p.id, 'New ' || new.source || ' lead',
             coalesce(new.customer_name, '') || ' - ' || coalesce(new.phone, ''),
             'lead_new', 'leads', new.id
      from public.profiles p where p.role = 'admin' and p.is_active;
    end if;
  elsif tg_table_name = 'tasks' then
    if tg_op = 'INSERT' then fire := new.assigned_to is not null;
    else fire := new.assigned_to is not null and new.assigned_to is distinct from old.assigned_to;
    end if;
    if fire and new.assigned_to is distinct from auth.uid() then
      insert into public.notifications(user_id, title, body, kind, ref_table, ref_id)
      values (new.assigned_to, 'New task assigned', new.title, 'task_assigned', 'tasks', new.id);
    end if;
  end if;
  return null;
end $$;

-- =====================================================================
-- AFTER the Edge Function "send-push" is deployed (SETUP.md part 12), run this ONCE with your values:
--
--   insert into private.push_settings (id, function_url, secret)
--   values (1, 'https://YOUR_REF.supabase.co/functions/v1/send-push', 'THE_SAME_RANDOM_TEXT_AS_PUSH_WEBHOOK_SECRET')
--   on conflict (id) do update set function_url = excluded.function_url, secret = excluded.secret;
-- =====================================================================
