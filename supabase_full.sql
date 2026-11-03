-- ============================================================
--  KHUNAW-ABDULKHALQ-AKAM — Supabase SETUP (تەواو، یەک فایل)
--  تەنها ئەم فایلە لە SQL Editor دا بە تەواوی Run بکە (دەتوانیت چەند جارێک Run ی بکەیت).
--  لۆگینی داشبۆرد:  بەکارهێنەر = khunav   |   وشەی نهێنی = khunav@123
-- ============================================================

-- ---------- خشتەکان ----------
create table if not exists public.workers (
  rid text primary key,
  person_name text not null,
  task_name text not null,
  registered_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  is_active boolean not null default true,
  closed_at timestamptz,
  last_send_at timestamptz,
  last_send_status text not null default 'Waiting',
  last_send_error text,
  total_count bigint not null default 0,
  last_seq bigint not null default 0
);
create table if not exists public.daily_task_counts (
  rid text not null references public.workers(rid) on delete cascade,
  task_date date not null,
  task_name text not null,
  count bigint not null default 0,
  primary key (rid, task_date, task_name)
);
create table if not exists public.task_prices  (task_name text primary key, price numeric not null default 0);
create table if not exists public.task_aliases (old_name text primary key, new_name text not null);
create table if not exists public.app_settings (key text primary key, value text not null);

alter table public.workers add column if not exists last_seq bigint not null default 0;   -- ژمارەی دوایین Shift+Enter ی وەرگیراو (بۆ ڕێگری لە دووبارەبوونەوە)
create index if not exists workers_last_seen_idx on public.workers(last_seen_at desc);
create index if not exists daily_task_counts_date_idx on public.daily_task_counts(task_date desc);
create index if not exists daily_task_counts_task_idx on public.daily_task_counts(task_name);

-- ---------- لۆگین ----------
insert into public.app_settings(key, value) values ('dash_user', 'khunav'), ('dash_pass', 'khunav@123')
on conflict (key) do update set value = excluded.value;
delete from public.app_settings where key = 'admin_pass';

-- ---------- ئاسایش: anon ناتوانێت هیچ خشتەیەک ڕاستەوخۆ بخوێنێتەوە ----------
alter table public.workers enable row level security;
alter table public.daily_task_counts enable row level security;
alter table public.task_prices enable row level security;
alter table public.task_aliases enable row level security;
alter table public.app_settings enable row level security;
drop policy if exists "public read workers" on public.workers;
drop policy if exists "public read daily counts" on public.daily_task_counts;
drop policy if exists "read prices" on public.task_prices;
revoke all on public.workers, public.daily_task_counts, public.task_prices, public.task_aliases, public.app_settings from anon, authenticated;
grant usage on schema public to anon;

-- ---------- لابردنی فەنکشنە کۆنەکان (ئەوانەی بێ وشەی نهێنی بوون) ----------
drop function if exists public.delete_worker(text);
drop function if exists public.delete_worker(text, text);
drop function if exists public.set_task_price(text, numeric);
drop function if exists public.set_task_price(text, text, numeric);
drop function if exists public.rename_task(text, text);
drop function if exists public.rename_task(text, text, text);
drop function if exists public.admin_login(text);
drop function if exists public.month_by_worker(date, date);
drop function if exists public.month_by_day(date, date);
drop function if exists public.day_detail(date);

-- ---------- فەنکشنەکانی سکریپتی AHK (وەک پێشوو) ----------
create or replace function public.resolve_task(t text) returns text language sql stable as $$
  select coalesce((select new_name from public.task_aliases where old_name = t), t) $$;

create or replace function public.register_worker(p_rid text, p_person_name text, p_task_name text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v text := resolve_task(p_task_name);
begin
  insert into workers(rid, person_name, task_name, registered_at, last_seen_at, is_active, closed_at, last_send_status, last_send_error)
  values (p_rid, p_person_name, v, now(), now(), true, null, 'Registered', null)
  on conflict (rid) do update set person_name = excluded.person_name, task_name = excluded.task_name,
    last_seen_at = now(), is_active = true, closed_at = null, last_send_status = 'Registered', last_send_error = null;
  return jsonb_build_object('ok', true, 'rid', p_rid, 'server_time', now());
end $$;

create or replace function public.record_shifts(p_rid text, p_task_name text, p_n int, p_date date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_count bigint; v text := resolve_task(p_task_name);
begin
  if p_n is null or p_n < 1 or p_n > 100000 then return jsonb_build_object('ok', false, 'error', 'Invalid count'); end if;
  update workers set last_seen_at = now(), is_active = true, closed_at = null, last_send_at = now(),
         last_send_status = 'Sent', last_send_error = null, total_count = total_count + p_n where rid = p_rid;
  if not found then return jsonb_build_object('ok', false, 'error', 'Worker is not registered'); end if;
  insert into daily_task_counts(rid, task_date, task_name, count) values (p_rid, coalesce(p_date, current_date), v, p_n)
  on conflict (rid, task_date, task_name) do update set count = daily_task_counts.count + excluded.count
  returning daily_task_counts.count into v_count;
  return jsonb_build_object('ok', true, 'count_today', v_count, 'server_time', now());
end $$;

-- هەر Shift+Enter ژمارەیەکی (s) هەیە. سێرڤەر تەنها ئەوانە وەردەگرێت کە s ی گەورەتر بێت لە last_seq،
-- بۆیە ئەگەر داواکارییەک دووبارە بنێردرێت (ئینتەرنێت پچڕا)، هیچ کاتێک دووجار ناژمێردرێت و هیچیش ون نابێت.
create or replace function public.record_batch(p_rid text, p_events jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_last bigint; v_new bigint; v_n bigint;
begin
  if jsonb_typeof(p_events) <> 'array' or jsonb_array_length(p_events) > 2000 then
    return jsonb_build_object('ok', false, 'error', 'Invalid events');
  end if;
  select last_seq into v_last from workers where rid = p_rid for update;   -- دوو داواکاری هاوکات ڕیز دەکرێن
  if not found then return jsonb_build_object('ok', false, 'error', 'Worker is not registered'); end if;
  with ev as (
    select (e->>'s')::bigint as s, (e->>'d')::date as d, resolve_task(e->>'t') as t
    from jsonb_array_elements(p_events) e
  ), nw as (select s, d, t from ev where s > v_last),
  agg as (select d, t, count(*)::bigint as c from nw group by d, t),
  ins as (
    insert into daily_task_counts(rid, task_date, task_name, count)
    select p_rid, d, t, c from agg
    on conflict (rid, task_date, task_name) do update set count = daily_task_counts.count + excluded.count
    returning 1
  )
  select coalesce((select max(s) from nw), v_last), (select count(*) from nw) into v_new, v_n;
  update workers set last_seq = v_new, total_count = total_count + v_n,
         last_seen_at = now(), is_active = true, closed_at = null,
         last_send_at = now(), last_send_status = 'Sent', last_send_error = null
   where rid = p_rid;
  return jsonb_build_object('ok', true, 'last_seq', v_new, 'applied', v_n, 'server_time', now());
end $$;

create or replace function public.record_shift(p_rid text, p_task_name text)
returns jsonb language sql security definer set search_path = public as $$
  select public.record_shifts(p_rid, p_task_name, 1, current_date) $$;

create or replace function public.heartbeat_worker(p_rid text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update workers set last_seen_at = now(), is_active = true, closed_at = null where rid = p_rid;
  if not found then return jsonb_build_object('ok', false, 'error', 'Worker is not registered'); end if;
  return jsonb_build_object('ok', true, 'server_time', now());
end $$;

create or replace function public.deactivate_worker(p_rid text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update workers set last_seen_at = now(), is_active = false, closed_at = now(),
         last_send_at = now(), last_send_status = 'Script closed', last_send_error = null where rid = p_rid;
  return jsonb_build_object('ok', true, 'server_time', now());
end $$;

create or replace function public.report_worker_error(p_rid text, p_error text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update workers set last_send_status = 'Failed', last_send_error = left(coalesce(p_error, 'Unknown error'), 1000) where rid = p_rid;
  return jsonb_build_object('ok', true, 'server_time', now());
end $$;

create or replace function public.reset_worker_counts(p_rid text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  delete from daily_task_counts where rid = p_rid;
  update workers set total_count = 0 where rid = p_rid;
  return jsonb_build_object('ok', true, 'server_time', now());
end $$;

-- ---------- لۆگین و خوێندنەوەی داشبۆرد (هەموو بە khunav / khunav@123 دەپارێزرێن) ----------
create or replace function public.dash_ok(p_user text, p_pass text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from app_settings where key = 'dash_user' and value = p_user)
     and exists(select 1 from app_settings where key = 'dash_pass' and value = p_pass) $$;
revoke execute on function public.dash_ok(text, text) from public, anon;

create or replace function public.dash_login(p_user text, p_pass text) returns boolean
language sql stable security definer set search_path = public as $$ select public.dash_ok(p_user, p_pass) $$;

create or replace function public.server_now() returns timestamptz language sql stable as $$ select now() $$;

create or replace function public.dash_workers(p_user text, p_pass text)
returns table(rid text, person_name text, task_name text, last_seen_at timestamptz, is_active boolean,
              last_send_at timestamptz, last_send_status text, last_send_error text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not dash_ok(p_user, p_pass) then raise exception 'unauthorized'; end if;
  return query select w.rid, w.person_name, w.task_name, w.last_seen_at, w.is_active,
                      w.last_send_at, w.last_send_status, w.last_send_error from workers w order by w.rid;
end $$;

create or replace function public.dash_prices(p_user text, p_pass text)
returns table(task_name text, price numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if not dash_ok(p_user, p_pass) then raise exception 'unauthorized'; end if;
  return query select t.task_name, t.price from task_prices t order by t.task_name;
end $$;

create or replace function public.month_by_worker(p_user text, p_pass text, p_from date, p_to date)
returns table(rid text, task_name text, total bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not dash_ok(p_user, p_pass) then raise exception 'unauthorized'; end if;
  return query select d.rid, d.task_name, sum(d.count)::bigint from daily_task_counts d
    where d.task_date >= p_from and d.task_date < p_to group by d.rid, d.task_name order by d.rid, d.task_name;
end $$;

create or replace function public.month_by_day(p_user text, p_pass text, p_from date, p_to date)
returns table(task_date date, task_name text, total bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not dash_ok(p_user, p_pass) then raise exception 'unauthorized'; end if;
  return query select d.task_date, d.task_name, sum(d.count)::bigint from daily_task_counts d
    where d.task_date >= p_from and d.task_date < p_to group by d.task_date, d.task_name order by d.task_date, d.task_name;
end $$;

create or replace function public.day_detail(p_user text, p_pass text, p_date date)
returns table(rid text, task_name text, count bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not dash_ok(p_user, p_pass) then raise exception 'unauthorized'; end if;
  return query select d.rid, d.task_name, d.count from daily_task_counts d where d.task_date = p_date order by d.rid, d.task_name;
end $$;

create or replace function public.month_rows(p_user text, p_pass text, p_from date, p_to date)
returns table(rid text, task_date date, task_name text, count bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not dash_ok(p_user, p_pass) then raise exception 'unauthorized'; end if;
  return query select d.rid, d.task_date, d.task_name, d.count from daily_task_counts d
    where d.task_date >= p_from and d.task_date < p_to order by d.task_date, d.rid, d.task_name;
end $$;

-- ---------- بەڕێوەبردن: سڕینەوە، نرخ، گۆڕینی ناوی تاسک ----------
create or replace function public.delete_worker(p_user text, p_pass text, p_rid text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not dash_ok(p_user, p_pass) then raise exception 'unauthorized'; end if;
  delete from workers where rid = p_rid;          -- ژمارەکانیشی خۆکار دەسڕێنەوە
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.set_task_price(p_user text, p_pass text, p_task text, p_price numeric) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not dash_ok(p_user, p_pass) then raise exception 'unauthorized'; end if;
  insert into task_prices values (p_task, greatest(coalesce(p_price, 0), 0))
  on conflict (task_name) do update set price = excluded.price;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.rename_task(p_user text, p_pass text, p_old text, p_new text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not dash_ok(p_user, p_pass) then raise exception 'unauthorized'; end if;
  p_new := btrim(p_new);
  if p_new = '' or p_new = p_old then return jsonb_build_object('ok', false, 'error', 'Invalid name'); end if;
  insert into daily_task_counts(rid, task_date, task_name, count)
    select rid, task_date, p_new, count from daily_task_counts where task_name = p_old
  on conflict (rid, task_date, task_name) do update set count = daily_task_counts.count + excluded.count;
  delete from daily_task_counts where task_name = p_old;
  update workers set task_name = p_new where task_name = p_old;
  insert into task_prices select p_new, price from task_prices where task_name = p_old on conflict do nothing;
  delete from task_prices where task_name = p_old;
  update task_aliases set new_name = p_new where new_name = p_old;
  insert into task_aliases values (p_old, p_new) on conflict (old_name) do update set new_name = excluded.new_name;
  return jsonb_build_object('ok', true);
end $$;

-- ---------- مافەکان ----------
grant execute on function
  public.register_worker(text,text,text), public.record_shifts(text,text,int,date), public.record_batch(text,jsonb), public.record_shift(text,text),
  public.heartbeat_worker(text), public.deactivate_worker(text), public.report_worker_error(text,text),
  public.reset_worker_counts(text), public.server_now(), public.dash_login(text,text),
  public.dash_workers(text,text), public.dash_prices(text,text),
  public.month_by_worker(text,text,date,date), public.month_by_day(text,text,date,date),
  public.day_detail(text,text,date), public.month_rows(text,text,date,date),
  public.delete_worker(text,text,text), public.set_task_price(text,text,text,numeric), public.rename_task(text,text,text,text)
to anon;

notify pgrst, 'reload schema';
