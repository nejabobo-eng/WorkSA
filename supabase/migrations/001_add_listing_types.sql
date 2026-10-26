-- Run this once in the Supabase SQL Editor before deploying the updated app.
-- It keeps all opportunities in the existing jobs table while distinguishing jobs,
-- funding opportunities and requests for quotations.

alter table public.jobs
  add column if not exists listing_type text not null default 'Job';

alter table public.jobs
  drop constraint if exists jobs_listing_type_check;

alter table public.jobs
  add constraint jobs_listing_type_check
  check (listing_type in ('Job', 'Funding', 'RFQ'));

alter table public.jobs
  drop constraint if exists jobs_job_type_check;

alter table public.jobs
  add constraint jobs_job_type_check
  check (job_type in ('Permanent', 'Temporary', 'Contract', 'Part-time', 'Internship', 'Learnership', 'Grant', 'Funding', 'RFQ'));

create index if not exists jobs_listing_type_feed_idx
  on public.jobs (listing_type, status, closing_date, advertised_at desc);
