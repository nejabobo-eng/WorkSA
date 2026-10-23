# WorkSA

One responsive South African jobs website with its public experience and administrator panel in the same application.

## Run locally

Open `index.html` in a web browser to use the interface demo. No build step or dependency installation is required.

## Supabase production setup

1. In Supabase, open **SQL Editor**, create a new query, paste the contents of `supabase/schema.sql`, and run it.
2. In **Authentication > Users**, create the single WorkSA owner account.
3. Run `supabase/owner-policy.sql` in the SQL Editor after creating the owner user. This locks admin access to that one UUID.
4. Store the project URL and publishable key in `.env.local`; do not commit this file.

The publishable key is suitable for the browser only when the Row Level Security policies in the schema are enabled. Never use a Supabase service-role key in browser code.

## Included routes/views

- Public job listings, job details, search, filters and categories
- Admin sign-in and dashboard
- Job creation, draft, review, publish, unpublish and expiry views
- CSV and JSON bulk import validation
- Local browser persistence for the demo

The current admin panel is accessed with the **Admin portal** button in the shared site header. A production release should replace the demo client-side access with a real backend, database, server-side authentication and role-based permissions.

## Commit

```powershell
git init
git add .
git commit -m "Initial WorkSA jobs platform"
```
