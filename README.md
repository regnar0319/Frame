# Crewline

Crewline is a Next.js App Router starter for an India-first professional network
for the entertainment industry. Screens are intentionally empty; this repository
contains project setup and route scaffolding only.

## Requirements

- Node.js 20.9 or later
- npm

## Getting started

```bash
npm install
Copy-Item .env.example .env.local
npm run dev
```

Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` in `.env.local`
to connect to a Supabase project. `SUPABASE_SERVICE_ROLE_KEY` is optional until
server-only administrative operations are needed; never expose it to browser code.

## Project layout

- `app/(auth)` and `app/(app)`: empty pages for the auth and product screens in
  `Context.md`
- `components/ui`: shadcn/ui component destination
- `components/features`: feature-specific UI destination
- `lib/supabase`: browser, server, middleware, and admin Supabase clients
- `lib/queries` and `lib/validators`: data-access and validation destinations
- `types/database.ts`: placeholder for generated Supabase database types
- `supabase/migrations`: database migration destination

## Scripts

- `npm run dev`: start the development server
- `npm run build`: build the production app
- `npm run start`: serve the production build
- `npm run lint`: run ESLint
- `npm run typecheck`: run TypeScript without emitting files