-- پاچی شەفت: یەکجار لە Supabase > SQL Editor دا بە تەواوی Run بکە (دەتوانیت چەند جارێک Run ی بکەیت).
-- شەفتی هەر کارمەندێک لە خشتەی workers هەڵدەگیرێت: لە AutoHotkey کاتی تۆمارکردن هەڵدەبژێردرێت، و لە ماڵپەڕیش دەگۆڕدرێت.
-- 1 = شەفتی ڕۆژ (08:00-16:00) | 2 = شەفتی شەو (16:00-24:00) | 0 = دوای نیوەشەو

alter table public.workers add column if not exists shift smallint;

-- شەفتی کارمەندانی کۆن بەپێی کاتی تۆمارکردنیان (کاتی هەولێر)
update public.workers set shift = case
    when extract(hour from registered_at at time zone 'Asia/Baghdad') >= 16 then 2
    when extract(hour from registered_at at time zone 'Asia/Baghdad') >= 8 then 1
    else 0 end
where shift is null;

-- شەفتی ئێستا بەپێی کاتژمێری سێرڤەر (کاتی هەولێر)
create or replace function public.shift_now() returns smallint language sql stable as $$
  select (case when h >= 16 then 2 when h >= 8 then 1 else 0 end)::smallint
  from (select extract(hour from now() at time zone 'Asia/Baghdad') as h) x $$;
grant execute on function public.shift_now() to anon;

-- register_worker: پارامیتەری ٤ەم (شەفت) ئارەزوومەندانەیە. ئەگەر نەنێردرا، شەفت بەپێی کاتژمێر دیاری دەکرێت.
drop function if exists public.register_worker(text, text, text);
drop function if exists public.register_worker(text, text, text, int);
create or replace function public.register_worker(p_rid text, p_person_name text, p_task_name text, p_shift int default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v text := resolve_task(p_rid, p_task_name);
  s smallint := (case when p_shift in (0, 1, 2) then p_shift else public.shift_now() end)::smallint;
begin
  insert into workers(rid, person_name, task_name, registered_at, last_seen_at, is_active, closed_at, last_send_status, last_send_error, shift)
  values (p_rid, p_person_name, v, now(), now(), true, null, 'Registered', null, s)
  on conflict (rid) do update set person_name = excluded.person_name, task_name = excluded.task_name,
    last_seen_at = now(), is_active = true, closed_at = null, last_send_status = 'Registered', last_send_error = null,
    shift = case when p_shift in (0, 1, 2) then s else coalesce(workers.shift, s) end;
  return jsonb_build_object('ok', true, 'rid', p_rid, 'server_time', now());
end $$;
grant execute on function public.register_worker(text, text, text, int) to anon;

-- dash_workers: شەفت و کاتی تۆمارکردنیش دەگەڕێنێتەوە
drop function if exists public.dash_workers(text, text);
create or replace function public.dash_workers(p_user text, p_pass text)
returns table(rid text, person_name text, task_name text, last_seen_at timestamptz, is_active boolean,
              last_send_at timestamptz, last_send_status text, last_send_error text, registered_at timestamptz, shift smallint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not dash_ok(p_user, p_pass) then raise exception 'unauthorized'; end if;
  return query select w.rid, w.person_name, w.task_name, w.last_seen_at, w.is_active,
                      w.last_send_at, w.last_send_status, w.last_send_error, w.registered_at, w.shift
               from workers w order by w.registered_at desc, w.rid;
end $$;
grant execute on function public.dash_workers(text, text) to anon;

-- گۆڕینی شەفتی کارمەندێک لە ماڵپەڕەوە
create or replace function public.set_worker_shift(p_user text, p_pass text, p_rid text, p_shift int) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not dash_ok(p_user, p_pass) then raise exception 'unauthorized'; end if;
  if p_shift is null or p_shift not in (0, 1, 2) then return jsonb_build_object('ok', false, 'error', 'Invalid shift'); end if;
  update workers set shift = p_shift where rid = p_rid;
  if not found then return jsonb_build_object('ok', false, 'error', 'Worker not found'); end if;
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.set_worker_shift(text, text, text, int) to anon;

notify pgrst, 'reload schema';
