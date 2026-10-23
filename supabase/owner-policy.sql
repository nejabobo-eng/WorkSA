-- Run this once in Supabase SQL Editor after schema.sql has completed.
-- Locks all admin job access to the one WorkSA owner account.

drop policy if exists "owner manages jobs" on public.jobs;
drop policy if exists "owner reads activity" on public.activity_log;

create policy "only WorkSA owner manages jobs" on public.jobs
  for all to authenticated
  using (auth.uid() = '63c0a79a-d368-482c-8a96-4a6df5664874'::uuid)
  with check (auth.uid() = '63c0a79a-d368-482c-8a96-4a6df5664874'::uuid);

create policy "only WorkSA owner reads activity" on public.activity_log
  for select to authenticated
  using (auth.uid() = '63c0a79a-d368-482c-8a96-4a6df5664874'::uuid);
