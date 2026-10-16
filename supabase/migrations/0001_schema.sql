-- =====================================================================
-- LEDiHA CRM - database schema, security rules (RLS), triggers
-- Run once in: Supabase dashboard -> SQL Editor -> New query -> paste -> Run
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- helpers ----------
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := clock_timestamp();   -- distinct per row, so sync never skips rows
  return new;
end $$;

create sequence if not exists public.employee_seq start 1;

-- ---------- profiles (one per login) ----------
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  employee_code text unique,
  full_name     text not null,
  phone         text,
  email         text,
  role          text not null default 'employee' check (role in ('admin','employee')),
  is_active     boolean not null default true,
  joining_date  date default current_date,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default clock_timestamp()
);

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and role = 'admin' and is_active)
$$;

create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and is_active)
$$;

create or replace function public.profile_defaults() returns trigger
language plpgsql as $$
begin
  if new.employee_code is null then
    new.employee_code := 'EMP' || lpad(nextval('public.employee_seq')::text, 4, '0');
  end if;
  return new;
end $$;
create trigger trg_profile_defaults before insert on public.profiles
  for each row execute function public.profile_defaults();

-- employees cannot change their own role / active flag
create or replace function public.guard_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.id := old.id; new.role := old.role; new.is_active := old.is_active;
    new.employee_code := old.employee_code;
  end if;
  return new;
end $$;
create trigger trg_guard_profile before update on public.profiles
  for each row execute function public.guard_profile();

-- ---------- leads ----------
create table public.leads (
  id               uuid primary key default gen_random_uuid(),
  lead_no          bigint generated always as identity,
  customer_name    text not null,
  phone            text,
  phone_norm       text generated always as
                   (right(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), 10)) stored,
  email            text,
  area             text,
  tv_brand         text,
  tv_model         text,
  issue            text,
  notes            text,
  source           text not null default 'manual'
                   check (source in ('manual','facebook','instagram','whatsapp','messenger','csv','walk_in','call')),
  campaign         text,
  external_id      text unique,            -- Meta lead / chat id: stops duplicate imports
  status           text not null default 'new'
                   check (status in ('new','contacted','follow_up','converted','lost')),
  priority         text not null default 'medium' check (priority in ('low','medium','high','hot')),
  assigned_to      uuid references public.profiles(id),
  received_at      timestamptz not null default now(),
  next_followup_at timestamptz,
  closed_at        timestamptz,
  lost_reason      text,
  is_deleted       boolean not null default false,
  created_by       uuid references public.profiles(id),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default clock_timestamp()
);
create index leads_phone_norm_idx  on public.leads (phone_norm);
create index leads_assigned_idx    on public.leads (assigned_to);
create index leads_updated_idx     on public.leads (updated_at);

-- employees may only change status, priority, notes, follow-up and closing fields
create or replace function public.guard_lead() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.customer_name := old.customer_name; new.phone := old.phone; new.email := old.email;
    new.assigned_to := old.assigned_to;     new.source := old.source;
    new.campaign := old.campaign;           new.external_id := old.external_id;
    new.created_by := old.created_by;       new.is_deleted := old.is_deleted;
    new.received_at := old.received_at;
  end if;
  return new;
end $$;
create trigger trg_guard_lead before update on public.leads
  for each row execute function public.guard_lead();

-- ---------- follow-ups (delivery, pickup, work pending, work done, hot lead...) ----------
create table public.followups (
  id           uuid primary key default gen_random_uuid(),
  lead_id      uuid not null references public.leads(id),
  assigned_to  uuid references public.profiles(id),
  kind         text not null default 'general'
               check (kind in ('hot_lead','pickup','work_pending','work_done','delivery','general')),
  scheduled_at timestamptz not null,
  status       text not null default 'open' check (status in ('open','done')),
  note         text,
  outcome      text,
  completed_at timestamptz,
  created_by   uuid references public.profiles(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default clock_timestamp()
);
create index followups_assigned_idx on public.followups (assigned_to);
create index followups_updated_idx  on public.followups (updated_at);

-- ---------- tasks ----------
create table public.tasks (
  id              uuid primary key default gen_random_uuid(),
  task_no         bigint generated always as identity,
  title           text not null,
  description     text,
  assigned_to     uuid references public.profiles(id),
  priority        text not null default 'medium' check (priority in ('low','medium','high','hot')),
  due_at          timestamptz,
  status          text not null default 'pending'
                  check (status in ('pending','in_progress','completed','reopened')),
  lead_id         uuid references public.leads(id),
  completion_note text,
  reopen_reason   text,
  created_by      uuid references public.profiles(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default clock_timestamp()
);
create index tasks_assigned_idx on public.tasks (assigned_to);
create index tasks_updated_idx  on public.tasks (updated_at);

create or replace function public.guard_task() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.title := old.title; new.description := old.description; new.assigned_to := old.assigned_to;
    new.priority := old.priority; new.due_at := old.due_at; new.lead_id := old.lead_id;
    new.created_by := old.created_by; new.reopen_reason := old.reopen_reason;
    if new.status = 'reopened' then new.status := old.status; end if;
  end if;
  return new;
end $$;
create trigger trg_guard_task before update on public.tasks
  for each row execute function public.guard_task();

-- ---------- attendance (time only; location is stored separately) ----------
create table public.attendance (
  id                uuid primary key,
  user_id           uuid not null references public.profiles(id),
  work_date         date not null,
  check_in_at       timestamptz,          -- time on the employee's phone
  check_out_at      timestamptz,
  check_in_lat      double precision,
  check_in_lng      double precision,
  check_out_lat     double precision,
  check_out_lng     double precision,
  corrected         boolean not null default false,
  correction_reason text,
  corrected_by      uuid references public.profiles(id),
  orig_check_in_at  timestamptz,
  orig_check_out_at timestamptz,
  synced_at         timestamptz not null default now(),  -- when the server first received it
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default clock_timestamp(),
  unique (user_id, work_date)
);
create index attendance_updated_idx on public.attendance (updated_at);

create or replace function public.guard_attendance() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.user_id := old.user_id; new.work_date := old.work_date;
    if old.check_in_at is not null then new.check_in_at := old.check_in_at; end if;
    new.corrected := old.corrected; new.correction_reason := old.correction_reason;
    new.corrected_by := old.corrected_by;
    new.orig_check_in_at := old.orig_check_in_at; new.orig_check_out_at := old.orig_check_out_at;
    new.synced_at := old.synced_at;
  end if;
  return new;
end $$;
create trigger trg_guard_attendance before update on public.attendance
  for each row execute function public.guard_attendance();

-- ---------- location pings (employee location while checked in) ----------
create table public.location_pings (
  id          uuid primary key,
  user_id     uuid not null references public.profiles(id),
  lat         double precision not null,
  lng         double precision not null,
  accuracy    real,
  recorded_at timestamptz not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default clock_timestamp()
);
create index pings_user_time_idx on public.location_pings (user_id, recorded_at desc);

-- latest position of every person (admin only)
create or replace function public.latest_locations()
returns table (user_id uuid, full_name text, lat double precision, lng double precision,
               recorded_at timestamptz)
language sql stable security definer set search_path = public as $$
  select distinct on (lp.user_id) lp.user_id, p.full_name, lp.lat, lp.lng, lp.recorded_at
  from public.location_pings lp
  join public.profiles p on p.id = lp.user_id
  where public.is_admin() and lp.recorded_at > now() - interval '2 days'
  order by lp.user_id, lp.recorded_at desc
$$;

-- ---------- direct messages + team chat ----------
create table public.messages (
  id           uuid primary key,
  sender_id    uuid not null references public.profiles(id),
  recipient_id uuid references public.profiles(id),   -- null = team chat
  body         text not null check (char_length(body) <= 2000),
  read_at      timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default clock_timestamp()
);
create index messages_updated_idx   on public.messages (updated_at);
create index messages_recipient_idx on public.messages (recipient_id);

create or replace function public.guard_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.body := old.body; new.sender_id := old.sender_id;
  new.recipient_id := old.recipient_id; new.created_at := old.created_at;
  return new;
end $$;
create trigger trg_guard_message before update on public.messages
  for each row execute function public.guard_message();

-- ---------- daily income / expenses ----------
create table public.finance_entries (
  id         uuid primary key,
  entry_date date not null,
  kind       text not null check (kind in ('income','expense')),
  amount     numeric(12,2) not null check (amount >= 0),
  category   text,
  pay_mode   text,
  note       text,
  lead_id    uuid references public.leads(id),
  is_deleted boolean not null default false,
  created_by uuid references public.profiles(id),
  synced_at  timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default clock_timestamp()
);
create index finance_date_idx    on public.finance_entries (entry_date);
create index finance_updated_idx on public.finance_entries (updated_at);

-- employees can fix their own entries only for 24 h after the server received them
create or replace function public.guard_finance() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin()
     and old.synced_at < now() - interval '24 hours' then
    new := old;
  end if;
  return new;
end $$;
create trigger trg_guard_finance before update on public.finance_entries
  for each row execute function public.guard_finance();

-- ---------- notifications ----------
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id),
  title      text not null,
  body       text,
  kind       text,
  ref_table  text,
  ref_id     uuid,
  read_at    timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default clock_timestamp()
);
create index notif_user_idx    on public.notifications (user_id);
create index notif_updated_idx on public.notifications (updated_at);

-- ---------- Facebook / Instagram / WhatsApp intake log ----------
create table public.meta_events (
  id                uuid primary key default gen_random_uuid(),
  external_event_id text not null unique,
  source            text,
  status            text not null default 'received'
                    check (status in ('received','processed','failed','duplicate')),
  error             text,
  lead_id           uuid references public.leads(id),
  payload           jsonb,
  attempts          int not null default 0,
  received_at       timestamptz not null default now()
);

-- ---------- audit log (who changed what) ----------
create table public.audit_logs (
  id         bigint generated always as identity primary key,
  actor      uuid,
  action     text not null,
  table_name text not null,
  record_id  text,
  old_row    jsonb,
  new_row    jsonb,
  created_at timestamptz not null default now()
);
create index audit_created_idx on public.audit_logs (created_at desc);

create or replace function public.audit_row() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.audit_logs(actor, action, table_name, record_id, new_row)
    values (auth.uid(), 'insert', tg_table_name, to_jsonb(new)->>'id', to_jsonb(new));
  elsif tg_op = 'UPDATE' then
    if (to_jsonb(new) - 'updated_at') is distinct from (to_jsonb(old) - 'updated_at') then
      insert into public.audit_logs(actor, action, table_name, record_id, old_row, new_row)
      values (auth.uid(), 'update', tg_table_name, to_jsonb(new)->>'id', to_jsonb(old), to_jsonb(new));
    end if;
  end if;
  return null;
end $$;

-- updated_at + audit triggers
do $$
declare t text;
begin
  foreach t in array array['profiles','leads','followups','tasks','attendance',
                           'location_pings','messages','finance_entries','notifications']
  loop
    execute format('create trigger trg_touch before insert or update on public.%I
                    for each row execute function public.touch_updated_at()', t);
  end loop;
  foreach t in array array['profiles','leads','tasks','attendance','finance_entries']
  loop
    execute format('create trigger trg_audit after insert or update on public.%I
                    for each row execute function public.audit_row()', t);
  end loop;
end $$;

-- ---------- in-app notifications ----------
create or replace function public.notify_events() returns trigger
language plpgsql security definer set search_path = public as $$
declare fire boolean;
begin
  if tg_table_name = 'leads' then
    if tg_op = 'INSERT' then fire := new.assigned_to is not null;
    else fire := new.assigned_to is not null and new.assigned_to is distinct from old.assigned_to;
    end if;
    if fire and new.assigned_to is distinct from auth.uid() then
      insert into public.notifications(user_id, title, body, kind, ref_table, ref_id)
      values (new.assigned_to, 'New lead assigned',
              coalesce(new.customer_name, '') || ' - ' || coalesce(new.phone, ''),
              'lead_assigned', 'leads', new.id);
    end if;
    -- a lead that arrives from Facebook/Instagram/WhatsApp with nobody assigned: tell the admins
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
create trigger trg_notify_leads after insert or update on public.leads
  for each row execute function public.notify_events();
create trigger trg_notify_tasks after insert or update on public.tasks
  for each row execute function public.notify_events();

-- =====================================================================
-- Row Level Security: the database itself enforces who can see/change what
-- =====================================================================
alter table public.profiles        enable row level security;
alter table public.leads           enable row level security;
alter table public.followups       enable row level security;
alter table public.tasks           enable row level security;
alter table public.attendance      enable row level security;
alter table public.location_pings  enable row level security;
alter table public.messages        enable row level security;
alter table public.finance_entries enable row level security;
alter table public.notifications   enable row level security;
alter table public.meta_events     enable row level security;
alter table public.audit_logs      enable row level security;

-- profiles: every active person can see the team list; only admin edits others
create policy profiles_select on public.profiles for select to authenticated
  using (public.is_staff());
create policy profiles_update on public.profiles for update to authenticated
  using (public.is_admin() or id = auth.uid())
  with check (public.is_admin() or id = auth.uid());
-- (new profiles are created by the manage-employee Edge Function, never by the app)

-- leads
create policy leads_select on public.leads for select to authenticated
  using (public.is_admin() or (assigned_to = auth.uid() and public.is_staff()));
create policy leads_insert on public.leads for insert to authenticated
  with check (public.is_admin());
create policy leads_update on public.leads for update to authenticated
  using (public.is_admin() or (assigned_to = auth.uid() and public.is_staff()))
  with check (public.is_admin() or (assigned_to = auth.uid() and public.is_staff()));

-- follow-ups
create policy followups_select on public.followups for select to authenticated
  using (public.is_admin() or (assigned_to = auth.uid() and public.is_staff()));
create policy followups_insert on public.followups for insert to authenticated
  with check (public.is_admin() or
              (assigned_to = auth.uid() and public.is_staff()
               and exists (select 1 from public.leads l where l.id = lead_id)));
create policy followups_update on public.followups for update to authenticated
  using (public.is_admin() or (assigned_to = auth.uid() and public.is_staff()))
  with check (public.is_admin() or (assigned_to = auth.uid() and public.is_staff()));

-- tasks
create policy tasks_select on public.tasks for select to authenticated
  using (public.is_admin() or (assigned_to = auth.uid() and public.is_staff()));
create policy tasks_insert on public.tasks for insert to authenticated
  with check (public.is_admin());
create policy tasks_update on public.tasks for update to authenticated
  using (public.is_admin() or (assigned_to = auth.uid() and public.is_staff()))
  with check (public.is_admin() or (assigned_to = auth.uid() and public.is_staff()));

-- attendance
create policy att_select on public.attendance for select to authenticated
  using (public.is_admin() or (user_id = auth.uid() and public.is_staff()));
create policy att_insert on public.attendance for insert to authenticated
  with check (public.is_admin() or (user_id = auth.uid() and public.is_staff()));
create policy att_update on public.attendance for update to authenticated
  using (public.is_admin() or (user_id = auth.uid() and public.is_staff()))
  with check (public.is_admin() or (user_id = auth.uid() and public.is_staff()));

-- location pings
create policy pings_select on public.location_pings for select to authenticated
  using (public.is_admin() or (user_id = auth.uid() and public.is_staff()));
create policy pings_insert on public.location_pings for insert to authenticated
  with check (user_id = auth.uid() and public.is_staff());
create policy pings_update on public.location_pings for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- messages: private between the two people; recipient null = whole team
create policy msg_select on public.messages for select to authenticated
  using (public.is_staff() and (sender_id = auth.uid() or recipient_id = auth.uid() or recipient_id is null));
create policy msg_insert on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.is_staff());
create policy msg_update on public.messages for update to authenticated
  using (sender_id = auth.uid() or recipient_id = auth.uid())
  with check (sender_id = auth.uid() or recipient_id = auth.uid());

-- income / expenses
create policy fin_select on public.finance_entries for select to authenticated
  using (public.is_admin() or (created_by = auth.uid() and public.is_staff()));
create policy fin_insert on public.finance_entries for insert to authenticated
  with check (public.is_admin() or (created_by = auth.uid() and public.is_staff()));
create policy fin_update on public.finance_entries for update to authenticated
  using (public.is_admin() or (created_by = auth.uid() and public.is_staff()))
  with check (public.is_admin() or (created_by = auth.uid() and public.is_staff()));

-- notifications: yours only
create policy notif_select on public.notifications for select to authenticated
  using (user_id = auth.uid());
create policy notif_update on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- logs: admin read only (the Edge Function writes with the service key)
create policy meta_select  on public.meta_events for select to authenticated using (public.is_admin());
create policy audit_select on public.audit_logs  for select to authenticated using (public.is_admin());

-- live updates for chat, alerts and new leads
alter publication supabase_realtime add table
  public.messages, public.notifications, public.leads, public.tasks, public.followups;

-- =====================================================================
-- FIRST ADMIN: create the user in Authentication > Users (Add user, tick
-- "Auto Confirm"), then run this with that user's email:
--
--   insert into public.profiles (id, full_name, email, role)
--   select id, 'Owner Name', email, 'admin' from auth.users
--   where email = 'owner@example.com';
-- =====================================================================
