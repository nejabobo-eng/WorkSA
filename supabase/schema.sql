-- WorkSA production schema
-- Run this entire file in Supabase: SQL Editor > New query > Run.

create extension if not exists pg_trgm;

create type public.job_status as enum ('Draft', 'Pending Review', 'Published', 'Expired', 'Unpublished', 'Archived');

create table public.categories (
  id bigint generated always as identity primary key,
  name text not null unique,
  slug text not null unique,
  sort_order smallint not null unique
);

insert into public.categories (name, slug, sort_order) values
  ('Administration and Office Support', 'administration-office-support', 1),
  ('Accounting and Finance', 'accounting-finance', 2),
  ('General Workers and Labour', 'general-workers-labour', 3),
  ('Retail and Customer Service', 'retail-customer-service', 4),
  ('Driver, Delivery and Logistics', 'driver-delivery-logistics', 5),
  ('Security and Cleaning', 'security-cleaning', 6),
  ('Construction, Engineering and Technical', 'construction-engineering-technical', 7),
  ('Healthcare and Community Services', 'healthcare-community-services', 8),
  ('Education and Training', 'education-training', 9),
  ('Information Technology, Sales and Professional Services', 'it-sales-professional-services', 10);

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) >= 2),
  company text not null check (char_length(trim(company)) >= 2),
  category_id bigint not null references public.categories(id),
  province text not null,
  city text not null,
  job_type text not null check (job_type in ('Permanent', 'Temporary', 'Contract', 'Part-time', 'Internship', 'Learnership', 'Grant', 'Funding', 'RFQ')),
  listing_type text not null default 'Job' check (listing_type in ('Job', 'Funding', 'RFQ')),
  salary text,
  advertised_at date not null default current_date,
  closing_date date not null,
  description text not null,
  requirements text,
  application_email text,
  application_url text,
  reference_number text,
  source_url text not null,
  status public.job_status not null default 'Draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (application_email is not null or application_url is not null),
  check (application_email is null or application_email ~* '^[^[:space:]@]+@[^[:space:]@]+\\.[^[:space:]@]+$'),
  check (application_url is null or application_url ~* '^https?://')
);

-- When a source does not state a closing date, store a real effective date: advertised date + 30 days.
-- The app may submit NULL for closing_date; this trigger always stores a date.
create or replace function public.set_effective_closing_date()
returns trigger language plpgsql as $$
begin
  if new.advertised_at is null then new.advertised_at := current_date; end if;
  if new.closing_date is null then new.closing_date := new.advertised_at + 30; end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger jobs_set_effective_closing_date
before insert or update on public.jobs
for each row execute function public.set_effective_closing_date();

create table public.activity_log (
  id bigint generated always as identity primary key,
  job_id uuid references public.jobs(id) on delete set null,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  source_url text,
  old_value jsonb,
  new_value jsonb,
  occurred_at timestamptz not null default now()
);

create or replace function public.log_job_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.activity_log (job_id, actor_id, action, source_url, new_value)
    values (new.id, auth.uid(), 'created', new.source_url, to_jsonb(new));
    return new;
  elsif tg_op = 'UPDATE' then
    insert into public.activity_log (job_id, actor_id, action, source_url, old_value, new_value)
    values (new.id, auth.uid(), case when new.status = 'Published' and old.status <> 'Published' then 'published' else 'updated' end, new.source_url, to_jsonb(old), to_jsonb(new));
    return new;
  end if;
  return old;
end;
$$;

create trigger jobs_activity_log after insert or update on public.jobs
for each row execute function public.log_job_change();

create index jobs_public_feed_idx on public.jobs (status, closing_date, advertised_at desc);
create index jobs_listing_type_feed_idx on public.jobs (listing_type, status, closing_date, advertised_at desc);
create index jobs_category_feed_idx on public.jobs (category_id, status, advertised_at desc);
create index jobs_title_search_idx on public.jobs using gin (title gin_trgm_ops);
create index jobs_company_search_idx on public.jobs using gin (company gin_trgm_ops);
create unique index jobs_source_url_unique on public.jobs (source_url);

alter table public.categories enable row level security;
alter table public.jobs enable row level security;
alter table public.activity_log enable row level security;

-- Anyone can read only current, published vacancies and categories. No login is required.
create policy "public read categories" on public.categories for select using (true);
create policy "public read active jobs" on public.jobs for select
  using (status = 'Published' and closing_date >= current_date);

-- Only the one WorkSA owner can manage listings or read the activity log.
create policy "only WorkSA owner manages jobs" on public.jobs for all to authenticated
  using (auth.uid() = '63c0a79a-d368-482c-8a96-4a6df5664874'::uuid)
  with check (auth.uid() = '63c0a79a-d368-482c-8a96-4a6df5664874'::uuid);
create policy "only WorkSA owner reads activity" on public.activity_log for select to authenticated
  using (auth.uid() = '63c0a79a-d368-482c-8a96-4a6df5664874'::uuid);

-- Public API view: expired jobs are automatically absent without relying on a client-side timer.
create view public.public_jobs with (security_invoker = true) as
select j.*, c.name as category_name, c.slug as category_slug
from public.jobs j join public.categories c on c.id = j.category_id
where j.status = 'Published' and j.closing_date >= current_date;
