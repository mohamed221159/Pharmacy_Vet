create table if not exists public.docs (
  path        text primary key,          -- months/2026-10  أو  config/main
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

-- الحماية: محدش يقرا أو يكتب غير اللي عامل تسجيل دخول
alter table public.docs enable row level security;

drop policy if exists "staff read"   on public.docs;
drop policy if exists "staff insert" on public.docs;
drop policy if exists "staff update" on public.docs;
drop policy if exists "staff delete" on public.docs;
create policy "staff read"   on public.docs for select to authenticated using (true);
create policy "staff insert" on public.docs for insert to authenticated with check (true);
create policy "staff update" on public.docs for update to authenticated using (true) with check (true);
create policy "staff delete" on public.docs for delete to authenticated using (true);

-- حفظ يوم واحد جوه الشهر من غير ما يمسح باقي الأيام (لو اتنين سجّلوا في نفس الوقت)
create or replace function public.set_day(p_month text, p_day text, p_entries jsonb)
returns void language sql security invoker as $$
  insert into public.docs(path, data)
  values ('months/' || p_month,
          jsonb_build_object('m', p_month, 'days', jsonb_build_object(p_day, p_entries)))
  on conflict (path) do update
    set data = jsonb_set(
                case when public.docs.data ? 'days' then public.docs.data
                      else public.docs.data || '{"days":{}}'::jsonb end,
                array['days', p_day], p_entries, true),
        updated_at = now();
$$;
revoke all on function public.set_day(text, text, jsonb) from public, anon;
grant execute on function public.set_day(text, text, jsonb) to authenticated;

-- التحديث اللحظي بين الأجهزة
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;
