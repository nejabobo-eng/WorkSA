-- Run this once in Supabase SQL Editor after schema.sql and owner-policy.sql.
create type public.inquiry_type as enum ('contact', 'employer');
create type public.inquiry_status as enum ('New', 'In Progress', 'Resolved', 'Archived');

create table public.inquiries (
  id uuid primary key default gen_random_uuid(),
  inquiry_type public.inquiry_type not null,
  name text not null check (char_length(trim(name)) >= 2),
  email text not null check (email ~* '^[^[:space:]@]+@[^[:space:]@]+\\.[^[:space:]@]+$'),
  phone text,
  company text,
  subject text,
  message text not null check (char_length(trim(message)) >= 10),
  status public.inquiry_status not null default 'New',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index inquiries_inbox_idx on public.inquiries (status, created_at desc);
alter table public.inquiries enable row level security;

-- Visitors may submit messages, but can never read inbox data.
create policy "public can submit inquiries" on public.inquiries
  for insert to anon, authenticated with check (true);

-- Only the WorkSA owner can access the inbox in the admin portal.
create policy "only WorkSA owner manages inbox" on public.inquiries
  for all to authenticated
  using (auth.uid() = '63c0a79a-d368-482c-8a96-4a6df5664874'::uuid)
  with check (auth.uid() = '63c0a79a-d368-482c-8a96-4a6df5664874'::uuid);
