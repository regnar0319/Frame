# Context.md: Crewline

> **Crewline** is a professional network for India's entertainment industry. *"Every craft. Connected."*
> People from every department (acting to stunts) build a verified portfolio and credits, find collaborators, join projects, and apply to jobs. Production houses hire through a recruiter studio.
> Voice: warm, respectful of every role ("No small roles. Only shared vision."), India-first.
> Read this file before generating code. `schema.sql` is the source of truth for the database.

---

## 1. Tech Stack

| Layer | Choice |
|---|---|
| Framework | Next.js 14+ (App Router, TypeScript, Server Components, Route Handlers) |
| Backend | Supabase: Postgres, Auth (email, **phone OTP**, Google), Storage, Realtime, RLS |
| Styling | Tailwind CSS + shadcn/ui (restyled to the monochrome tokens below) |
| Data fetching | RSC + Supabase server client for reads; TanStack Query for interactive lists |
| Validation | Zod (shared by client and API) |
| Payments | Razorpay (UPI, cards, net banking), webhook-driven, GST invoices |
| SMS / OTP | Supabase phone auth via an Indian SMS provider (MSG91 / Twilio) |
| Video | Supabase Storage for MVP showreels; Mux / Cloudflare Stream when transcoding is needed |
| Search | Postgres FTS + pg_trgm (`search_professionals` RPC); Meilisearch later |
| i18n | `next-intl`; header shows `INDIA / EN` (language switcher; Hindi first) |
| Hosting | Vercel + Supabase (Mumbai `ap-south-1` region for latency and data residency) |

## 2. UI Theme (from the Figma screens)

Strictly **monochrome**, editorial and calm. Black, white and light grey only. Photography (black-and-white film stills) carries the personality. No accent color; status uses grey pills.

Values below are estimated from screenshots. Verify them in Figma Dev Mode.

```ts
// tailwind.config.ts, theme.extend
colors: {
  canvas: "#F2F2F2",   // app background (grey) behind cards
  card:   "#FFFFFF",   // sidebar, top bar, cards, inputs
  ink:    "#111111",   // primary text, active nav pill, primary buttons, dark promo cards
  muted:  "#8A8A8A",   // secondary text, placeholders, meta
  line:   "#E6E6E6",   // card borders, dividers
  pill:   "#EFEFEF",   // chips: "Available", "Reviewing", tags
},
fontFamily: { sans: ["Inter", "system-ui", "sans-serif"] },
borderRadius: { card: "12px", control: "8px", pill: "9999px" },
```

**Typography:** page H1 28 to 32px semibold, tight tracking ("Your industry, in focus."); card titles 16 to 20px semibold; body 13 to 14px; meta 11 to 12px muted; **eyebrow labels** 9 to 10px UPPERCASE with wide tracking ("YOUR NEXT CHAPTER", "WORKSPACE"). Wordmark `CREWLINE` is heavy uppercase, with a tiny uppercase tagline `EVERY CRAFT. CONNECTED.`

**App shell (all authenticated screens)**
- **Left sidebar (white, ~190px):** wordmark and tagline; `WORKSPACE` nav: Home feed, Explore professionals, Departments, Projects, Opportunities, Messages, Recruiter studio, Credit wallet. Active item = black pill with white text. `YOUR NETWORK` block lists the user's collective (e.g. *Mumbai Film Collective, Independent cinema · India*). Bottom: user chip (avatar, name, "View your profile →") and `Settings ↗`.
- **Top bar (white):** page title at left, wide grey search input (`Search people, skills, projects and opportunities`), `INDIA / EN` language switch, `Notifications •` (dot when unread).
- **Content area:** grey canvas, H1 and subtext at left, primary black action button at right (e.g. "+ Share your work", "+ Post an opportunity", "+ Create a project"), cards on white.
- **Buttons:** primary = black fill, white text, 8px radius; secondary = white with 1px border; text actions end with an arrow (`→` or `↗`). Chips = pill grey. Checkmark (✓) next to a name = verified.
- **Mobile:** sidebar becomes a bottom tab bar (Home, Explore, Projects, Opportunities, Messages) plus a drawer for the rest.

**Auth screens:** split layout. Left: dark panel with a B&W set photograph, wordmark, uppercase headline (*"BEHIND EVERY FRAME, AN ENTIRE INDUSTRY."*), subtext and `MADE FOR INDIA. OPEN TO POSSIBILITY.` Right: white form (eyebrow, H1 "Good to see you.", fields, black submit, Google button, "Create an account →").

## 3. Screens (Figma frames) and what they need

| # | Screen | Key UI | Backed by |
|---|---|---|---|
| 01 | Login | Email **or mobile number** + password, Forgot password, Google, Create account | Supabase Auth (email / phone OTP / Google) |
| 02 | Onboarding | Choose departments (multi-select grid of 15), "I'm here to": showcase my work / discover collaborators / hire professionals; experience and portfolio can be added later | `profile_departments`, `profiles.intents` |
| 03 | Home feed | Tabs: For you / Following / From your departments; composer (Photo / Video / Post); post cards with media label chip, like, comments, share, "Saved by cinematographers, editors & lighting crews"; right rail: profile-completeness card, People worth knowing, Open collaboration promo | `get_feed`, `posts`, `saved_by_departments`, `profiles.profile_completeness` |
| 04 | Explore professionals | Search, **Save search**, filters (department, location, experience, languages, availability, **verified credits only**), result count, sort, cards (verified tick, role, city, years, specialties, availability chip) | `search_professionals`, `saved_searches` |
| 05 | Departments | Intro banner; 15 numbered cards with sample roles | `departments` |
| 06 | Professional profile | Cover, "Featured professional / Cinematography" badge, name + tick, headline, city, languages, years, availability date; stats (project credits, connections, collaborators); Connect + / Message; tabs Portfolio, Credits, About, Recommendations; hero showreel, "Selected credit", about card with gear/genre tags | `profiles`, `portfolio_items`, `project_credits`, `recommendations`, `profile_tags` |
| 07 | Recruiter dashboard | Greeting by organization; stat cards (active opportunities, applications received, shortlisted, interviews this week); hiring pipeline table; talent matched to your projects | `recruiter_stats`, `hiring_pipeline`, `match_talent_for_job` |
| 08 | Projects and collaborations | Tabs Discover / My collaborations / Saved; featured project with tags (location, compensation, start month), View open roles, Contact producer; crew grid per department (Confirmed / open positions / Apply to collaborate); project values strip | `projects`, `project_positions`, `position_applications` |
| 09 | Job opportunities | Search by role/skill, department and location filters, master-detail list; pay shown with unit (project / day / month); tags; "What you bring"; Apply with your profile; Message recruiter; My applications | `jobs`, `job_applications` |
| 11 | Credit wallet | Balance card (no expiry, not redeemable for cash); what credits unlock; top-up packs; recent activity | `wallets`, `credit_products`, `credit_packs`, `credit_transactions` |

> **Frame 10 is missing** from the export and is presumably **Messages** (it is in the nav). Also not yet designed: Settings, Notifications, Saved, My applications, My collaborations, Post an opportunity, Create a project, Project detail, Job-apply flow, Edit profile, Add credit, Organization page. See section 9.

## 4. Product Rules (non-negotiable)

1. **Networking and applying are always free.** Credits only buy optional visibility tools.
2. **Credits never influence hiring rankings or guarantee work.** `match_talent_for_job` and `search_professionals` must never read `wallets`, `spotlights` or `credit_transactions`. Spotlights appear only in a clearly labelled slot ("Featured professional").
3. **Credits do not expire and cannot be redeemed for cash.** Prices include GST.
4. **Verified credits are the trust signal.** A credit counts (stats, "Verified credits only" filter, matching) only when `status = 'verified'`: confirmed by the project owner or by the credited person (whichever side did not create it).
5. **Every department matters:** the same profile, credit and portfolio model for all 15 crafts; no department gets a lesser UI.
6. **Project values** (fair pay, safe sets, inclusive crews, credit for every contribution) are explicit commitments a project owner selects (`projects.commitments`) and displayed on the project.
7. **Pay transparency:** opportunities show a range with a unit (`₹60,000 – ₹80,000 / project`). Unpaid roles must be labelled.
8. **Wallet integrity:** balances change only through `spend_credits` (user) and `grant_credits_for_payment` (service role, idempotent). Clients never write wallet tables.
9. **Recruiter studio is an organization workspace.** Any user can create or join an organization; the nav item shows for org members (others see a "Create your studio" prompt).

## 5. Core Features

**Accounts and onboarding**
1. Sign in with email, **mobile OTP** or Google; onboarding picks departments (multi-select) and intent; the rest is deferrable ("Add later").
2. Profile completeness meter with a next-best-action CTA ("Add project credits").

**Profile and credibility**
3. Profile: headline, bio, languages, years of experience, availability (`available` / `available from <date>` / `busy`), gear and specialty tags, cover, verified tick.
4. Portfolio (showreels, stills) with a featured hero item; **Credits** (per project, role, year) with verification; "Selected credit" highlight.
5. Stats: project credits, connections, collaborators (people credited on shared projects).
6. Recommendations: written by connections, shown only after the recipient approves.

**Discovery**
7. **Explore professionals** with filters and Save search (optional alerts).
8. **Departments** hub (15 crafts) with department pages and feeds.
9. Global search across people, skills, projects and opportunities.

**Feed**
10. Posts (text, photo, video, behind-the-scenes, showreel) tagged to a department or project; like, comment, share, save.
11. Tabs: For you, Following, From your departments. Social proof: "Saved by cinematographers, editors & lighting crews".
12. Collectives ("Your network"): city or genre communities such as Mumbai Film Collective.

**Projects and collaboration**
13. Create a project: type, summary, location, compensation, start date, values, crew positions per department.
14. Discover projects; apply to an open position; owner confirms; confirmed crew can receive credits.
15. Tabs: Discover, My collaborations, Saved.

**Opportunities and hiring**
16. Jobs: department, pay range and unit, work mode (on set / hybrid / remote), duration, start date, requirements, languages.
17. Apply with profile (plus note); My applications with status; message recruiter.
18. **Recruiter studio:** KPIs, hiring pipeline, talent matched to your projects, shortlist, interview scheduling, post an opportunity.

**Credit wallet (optional visibility tools)**
19. Buy packs (100 / 250 / 600 credits, ₹499 / ₹999 / ₹1,999) via UPI / card / net banking; activity ledger.
20. Spend: **Priority introduction** (10), **Portfolio spotlight** (20 for 7 days in your department).

**Platform**
21. Messages (realtime), notifications (in-app, email, WhatsApp later), blocks and reports, verification requests (identity, credit, organization), settings with language and privacy.

## 6. Project Structure

```
/app
  (auth)/login, signup, onboarding
  (app)/home, explore, departments, departments/[slug], projects, projects/[id],
        opportunities, opportunities/[id], opportunities/applications,
        messages, notifications, saved, recruiter, recruiter/jobs/[id],
        wallet, settings, [username], collectives/[slug], studio/[slug]
  api/v1/...            # route handlers (section 8)
  api/webhooks/razorpay # payment webhook (service role)
/components/ui          # shadcn primitives (restyled)
/components/features    # ProfileCard, PostCard, MediaPost, ProfessionalCard, DepartmentCard,
                        # ProjectCard, PositionCard, JobListItem, JobDetail, StatCard,
                        # PipelineTable, WalletBalance, PackCard, Sidebar, Topbar
/lib/supabase           # client.ts, server.ts, middleware.ts, admin.ts (service role, server only)
/lib/validators         # zod schemas
/lib/queries            # typed data access
/types/database.ts      # generated: supabase gen types typescript
/supabase/migrations
```

## 7. Database (see `schema.sql`)

| Domain | Tables / functions |
|---|---|
| Taxonomy | `departments` (15 seeded, with sample roles) |
| Identity | `profiles`, `profile_departments`, `profile_tags`, `experiences`, `media_assets`, `portfolio_items` |
| Organizations | `organizations`, `organization_members` (`owner`/`admin`/`recruiter`), `is_org_member()` |
| Community | `collectives`, `collective_members` |
| Projects | `projects`, `project_positions`, `position_applications`, `project_credits` |
| Network | `connections`, `follows`, `recommendations`, `blocks` |
| Feed | `posts`, `post_media`, `comments`, `likes`, `post_shares`, `bookmarks`, `saved_by_departments()` |
| Opportunities | `jobs`, `job_applications`, `saved_searches` |
| Wallet | `credit_packs`, `credit_products`, `wallets`, `payments`, `credit_transactions`, `spotlights`, `introductions` |
| Messaging and ops | `conversations`, `conversation_members`, `messages`, `notifications`, `verification_requests`, `reports` |
| RPC | `search_professionals`, `get_feed`, `recruiter_stats`, `hiring_pipeline`, `match_talent_for_job`, `spend_credits`, `grant_credits_for_payment`, `refresh_profile_stats`, `unread_conversations_count` |

Design decisions:
- **Departments are the spine:** profiles, posts, positions and jobs all point at `departments`.
- **Credits (credibility) vs credits (wallet)** are different things. Tables are named `project_credits` and `credit_*` to avoid confusion; UI says "Project credits" and "Crewline credits".
- Counters (likes, comments, shares, connections, collaborators, credits, completeness) are trigger- or RPC-maintained.
- The wallet is an append-only ledger (`credit_transactions`) plus a cached `wallets.balance`, changed only inside `SECURITY DEFINER` functions.
- Money is stored as integer **paise**; pay ranges on jobs are `numeric` with an explicit `pay_unit`.
- Languages are stored as ISO codes (`hi`, `en`, `mr`, `ml`, ...) and rendered as names.
- Pagination: cursor on `created_at` for feeds; `limit/offset` acceptable for Explore (returns `total_count`).

## 8. API Endpoints

Base `/api/v1`. Auth = Supabase session (JWT cookie). All bodies validated with Zod. Envelope: `{ data, error, nextCursor? }`. "Org" = caller must be a member of the organization.

### Auth and onboarding
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/auth/login` | Email + password | Public |
| POST | `/auth/otp/send` | Send OTP to mobile number | Public |
| POST | `/auth/otp/verify` | Verify OTP, start session | Public |
| GET | `/auth/google` | Google OAuth redirect | Public |
| POST | `/auth/signup` | Create account | Public |
| POST | `/auth/forgot-password` | Send reset link/OTP | Public |
| POST | `/auth/logout` | Logout | Yes |
| GET | `/me` | Current user, profile, wallet balance, org memberships, unread counts | Yes |
| PUT | `/me/onboarding` | Save departments, intents, mark complete | Yes |
| PATCH | `/me` | Update profile (headline, bio, city, languages, availability, ...) | Yes |
| POST | `/me/avatar`, `/me/cover` | Signed upload URL | Yes |

### Profiles, portfolio and credits
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/profiles/:username` | Public profile with stats, availability, active spotlight flag | Public |
| GET | `/profiles/:username/portfolio` | Portfolio items | Public |
| GET | `/profiles/:username/credits` | Verified credits (all for the owner) | Public |
| GET | `/profiles/:username/recommendations` | Visible recommendations | Public |
| GET | `/profiles/:username/posts` | Posts by person | Public |
| PUT | `/me/departments` | Replace departments `{ids[], primaryId}` | Yes |
| PUT | `/me/tags` | Replace gear/software/specialty/genre tags | Yes |
| POST | `/me/portfolio` | Add item (media or external URL) | Yes |
| PATCH/DELETE | `/me/portfolio/:id` | Edit, reorder, feature, delete | Yes |
| POST | `/credits` | Add credit `{projectId, profileId?, roleTitle, year}` (self-claim or owner-assigned) | Yes |
| PATCH | `/credits/:id` | Verify / dispute / mark selected | Yes |
| DELETE | `/credits/:id` | Remove credit | Yes |
| GET | `/me/credits?status=pending` | My credits and pending requests | Yes |
| POST | `/recommendations` | Write a recommendation `{recipientId, body, projectId?}` | Yes |
| PATCH | `/recommendations/:id` | Recipient approves / hides | Yes |
| POST | `/verification-requests` | Request identity / credit / org verification | Yes |

### Network
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/connections` | Connect `{addresseeId, note?}` | Yes |
| GET | `/connections` | My connections | Yes |
| GET | `/connections/requests` | Pending in/out | Yes |
| PATCH | `/connections/:id` | Accept / decline | Yes |
| DELETE | `/connections/:id` | Remove / cancel | Yes |
| POST/DELETE | `/follows/:userId` | Follow / unfollow | Yes |
| GET | `/people/suggestions` | "People worth knowing" (same departments, mutuals; excludes self) | Yes |
| POST/DELETE | `/blocks/:userId` | Block / unblock | Yes |
| GET | `/collectives/:slug` | Collective detail | Public |
| PUT/DELETE | `/collectives/:slug/membership` | Join / leave | Yes |
| POST | `/collectives` | Create collective | Yes |

### Explore, departments and search
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/professionals?q=&department=&city=&minExperience=&languages=&availability=&verifiedOnly=&sort=&page=` | Explore (wraps `search_professionals`, returns `totalCount`) | Yes |
| GET | `/saved-searches` | List saved searches | Yes |
| POST | `/saved-searches` | Save `{name, query, filters, alertsEnabled}` | Yes |
| PATCH/DELETE | `/saved-searches/:id` | Edit / delete | Yes |
| GET | `/departments` | 15 departments with sample roles and member counts | Public |
| GET | `/departments/:slug` | Department detail (members, open positions, jobs, posts) | Public |
| GET | `/search?q=&type=people\|projects\|jobs\|posts` | Global search | Yes |
| GET | `/search/autocomplete?q=` | Typeahead | Yes |

### Feed
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/feed?tab=foryou\|following\|departments&cursor=` | Feed (wraps `get_feed`) | Yes |
| POST | `/posts` | Create post `{kind, body, label?, mediaIds[], projectId?, departmentId?, collectiveId?}` | Yes |
| GET | `/posts/:id` | Post detail (+ `savedByDepartments`) | Public |
| PATCH/DELETE | `/posts/:id` | Edit / delete | Yes |
| GET/POST | `/posts/:id/comments` | List / add comment | Public / Yes |
| PATCH/DELETE | `/comments/:id` | Edit / delete | Yes |
| PUT/DELETE | `/likes` | Like / unlike `{targetType, targetId}` | Yes |
| POST | `/posts/:id/share` | Record share, return share link | Yes |
| POST | `/media/upload-url` | Signed upload URL (image / video) | Yes |
| GET | `/bookmarks?type=` | Saved items | Yes |
| PUT/DELETE | `/bookmarks` | Save / unsave `{targetType, targetId}` | Yes |
| GET | `/me/profile-completeness` | Meter value plus suggested next step | Yes |

### Projects and collaborations
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/projects?tab=discover\|mine\|saved&department=&city=&compensation=&status=` | Browse projects | Yes |
| POST | `/projects` | Create project (with positions and commitments) | Yes |
| GET | `/projects/:id` | Detail with crew grid and credits | Public |
| PATCH/DELETE | `/projects/:id` | Edit / delete | Yes (owner) |
| POST | `/projects/:id/positions` | Add position | Yes (owner) |
| PATCH/DELETE | `/positions/:id` | Edit, invite, confirm, close | Yes (owner) |
| POST | `/positions/:id/apply` | Apply to collaborate `{message}` | Yes |
| GET | `/positions/:id/applications` | Applicants | Yes (owner) |
| PATCH | `/position-applications/:id` | Accept / decline | Yes (owner) |
| POST | `/projects/:id/contact` | Message the producer (creates conversation) | Yes |
| GET | `/me/collaborations` | Projects I own or crew on | Yes |

### Opportunities and applications
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/jobs?q=&department=&city=&workMode=&compensation=&minPay=&payUnit=&sort=` | List opportunities | Yes |
| GET | `/jobs/:id` | Job detail (pay range, requirements, org verified tick) | Yes |
| POST | `/jobs/:id/apply` | Apply with profile `{coverNote}` | Yes |
| DELETE | `/jobs/:id/apply` | Withdraw | Yes |
| GET | `/me/applications` | My applications and statuses | Yes |
| POST | `/jobs` | Post an opportunity | Org |
| PATCH/DELETE | `/jobs/:id` | Edit / close / mark filled | Org |
| GET | `/jobs/:id/applications?status=` | Applicants | Org |
| PATCH | `/applications/:id` | Update status, schedule interview, private note | Org |

### Recruiter studio and organizations
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/organizations` | Create organization | Yes |
| GET | `/organizations/:slug` | Public organization page | Public |
| PATCH | `/organizations/:id` | Edit | Org admin |
| GET/POST/DELETE | `/organizations/:id/members` | Manage recruiters | Org admin |
| GET | `/recruiter/:orgId/stats` | Dashboard KPIs (`recruiter_stats`) | Org |
| GET | `/recruiter/:orgId/pipeline` | Hiring pipeline table | Org |
| GET | `/recruiter/:orgId/talent-matches?jobId=` | Matched talent (`match_talent_for_job`) | Org |

### Credit wallet
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/wallet` | Balance, products, packs | Yes |
| GET | `/wallet/transactions?cursor=` | Recent activity | Yes |
| POST | `/wallet/orders` | Create Razorpay order for a pack `{packId}` | Yes |
| POST | `/webhooks/razorpay` | Verify signature, mark paid, call `grant_credits_for_payment` | Webhook |
| GET | `/wallet/invoices/:paymentId` | GST invoice (PDF) | Yes |
| POST | `/wallet/spend` | `{product: 'priority_introduction' \| 'portfolio_spotlight', targetId?, message?}` (calls `spend_credits`) | Yes |
| GET | `/introductions` | Incoming / sent introductions | Yes |
| PATCH | `/introductions/:id` | Accept / decline | Yes |

### Messages, notifications and moderation
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/conversations` | Inbox | Yes |
| POST | `/conversations` | Start conversation `{recipientId}` | Yes |
| GET | `/conversations/unread-count` | Badge | Yes |
| GET/POST | `/conversations/:id/messages` | History / send | Yes |
| POST | `/conversations/:id/read` | Mark read | Yes |
| GET | `/notifications` | List | Yes |
| GET | `/notifications/unread-count` | Dot / count | Yes |
| PATCH | `/notifications/:id/read`, `/notifications/read-all` | Mark read | Yes |
| POST | `/reports` | Report profile/post/project/job | Yes |
| GET/PATCH | `/admin/reports`, `/admin/verification-requests` | Review queues | Admin |

Realtime channels: `messages` (by conversation) and `notifications` (by recipient) via Supabase Realtime.

## 9. New Observations and Ideas

**What the new designs add (compared with the earlier "Frame" concept)**
- India-first: INR pricing with GST, UPI, mobile-number login, language switch, regional languages on profiles and jobs.
- 15 **departments** as the core taxonomy, with onboarding built around them.
- **Verified project credits** as a trust signal, plus "collaborators" derived from shared credits.
- **Recruiter studio** and a **credit wallet** (new revenue line) with strong ethical guardrails.
- **Project positions** (crew grid with confirmed and open slots) bridge "projects" and "jobs".

**Design gaps or inconsistencies to fix before building**
- Frame 10 (likely Messages) is missing; Settings, Notifications, Saved, My applications, Post an opportunity, Create a project, Project detail and Add credit also need screens.
- Home feed "People worth knowing" lists **Aditi Rao**, the logged-in user. The suggestion query must exclude self.
- Dates mix 2024 and 2025 (wallet activity, jobs, projects) and one company is named "Frame by Frame". Use consistent mock data.
- "Stories from the coast" appears as project, job context and promo. Make sure the data model keeps one project linked to its jobs (`jobs.project_id`).
- Recruiter studio shows in every user's nav. Decide the empty state for non-recruiters.
- Cards use tiny grey text (~11px, low contrast). Check accessibility (WCAG AA), especially muted text on grey.
- "Available" chips are the same for everyone. Show the date for `available_from`, and grey out `busy`.

**Feature ideas, roughly by value**
1. **Credit verification flow:** owner or producer one-tap verify, with a "Verified by <producer>" line and an optional document upload for disputes.
2. **Rate card and pay transparency:** optional day-rate range on profiles; salary insights per department and city; flag jobs below a "fair pay" threshold.
3. **Safe sets and conduct:** a safe-set pledge on projects, a POSH-compliance badge for organizations, anonymous reporting, and visible review of project conduct.
4. **Availability calendar:** block dates, "available from" auto-updates after a wrap date, and a recruiter filter by date range.
5. **Crew builder for producers:** build a project crew department by department, send invites in bulk, and export a crew list or call sheet.
6. **Guild and association badges** (self-declared, then verified): e.g. cinematographers' and actors' associations.
7. **Reels with timestamped credits:** tag who did what at a given time of a showreel; clicking jumps to the relevant person.
8. **Contracts and payment protection:** simple crew-deal templates (day rate, kill fee) and optional escrow via the payment provider.
9. **Gear and location listings:** rent cameras, lights, studios and locations; link to profile gear tags.
10. **Reference checks:** recruiters request quick feedback from past collaborators listed in credits.
11. **Collectives and events:** screenings, festivals, workshops; collective feeds and city meetups (Mumbai, Kochi, Chennai, Hyderabad, Kolkata, Bengaluru).
12. **Mentorship:** match students with professionals in the same department; student profile type.
13. **WhatsApp notifications and share cards** (high usage in India): application updates, interview reminders, profile share images.
14. **Multilingual UI and content translation** (Hindi, Marathi, Tamil, Telugu, Malayalam, Kannada, Bengali), including translated job descriptions.
15. **Portfolio PDF / link-in-bio export** for sending to directors outside the platform.
16. **AI assists (optional):** draft a bio from credits, suggest tags, summarize a long applicant list, translate messages. Keep human review; never auto-reject.
17. **Anti-abuse:** rate limits on connection requests and introductions, duplicate-profile checks, fake-job detection, and organization verification before posting.

**Compliance notes (India)**
- Follow the **Digital Personal Data Protection Act, 2023**: explicit consent, data export and deletion, and a grievance contact. Keep verification documents in a private bucket with admin-only access.
- Collect GST correctly on credit packs and issue invoices; keep payment records.
- Credits are a prepaid product; review RBI prepaid-instrument rules with your payment provider before launch.

## 10. Conventions for AI Assistants

- TypeScript strict; no `any`. Use generated `Database` types.
- Prefer Server Components for reads; route handlers for mutations and webhooks.
- **Never bypass RLS** from the client. The service-role key is server-only, used for webhooks, admin, and background jobs.
- Never write to `wallets`, `credit_transactions`, `payments` from app code except via the defined functions and webhook.
- Use design tokens (`bg-canvas`, `text-ink`, `text-muted`, `border-line`, `bg-pill`); never hard-code hex values in components.
- UI copy follows the Crewline voice: encouraging, concise, respectful of every craft. Use "Opportunities" (not Jobs), "Departments", "Project credits", "Crewline credits".
- Format INR with `Intl.NumberFormat('en-IN')`; show pay with its unit.
- Cursor pagination for feeds and messages; page size 20.
- Accessibility: keyboard navigable, visible focus rings, ARIA labels on icon buttons, alt text on portfolio media.
- Env vars: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`.
- Files `kebab-case`; components `PascalCase`; DB `snake_case`.

## 11. Roadmap

1. **MVP:** auth (email/OTP/Google), onboarding, profiles, portfolio, departments, Explore with filters, connect and message, feed (For you / Following / departments)
2. **v1:** project credits with verification, projects and positions, opportunities and applications, notifications, saved searches
3. **v2:** recruiter studio (organizations, pipeline, matching), credit wallet and payments, recommendations, collectives
4. **v3:** availability calendar, rate cards, contracts and escrow, WhatsApp, multilingual UI, analytics, mobile app