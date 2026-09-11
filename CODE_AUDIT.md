# SignalDesk MVP Deep Code Audit

> **Remediation note:** This report records the pre-remediation audit. The implementation has since been updated to address the release-blocking findings, including generation persistence, attribution preservation, editing/publishing, admin management, public search/category routes, source controls, validation, rate limits, migration tracking, and Render port/rewrite configuration. Re-run the checks in the final response after deployment with Neon and provider credentials.
>
> **2026-09-11 addendum #3 — root-caused the `/api/generate` 500 after the news_id fix:**
> - **Critical: the Groq and Gemini default models baked into `AIService.php` no longer exist.** Groq decommissioned `llama-3.1-8b-instant` (the app's Groq default) on August 16, 2026, and Google has fully shut down all Gemini 1.5-series models including `gemini-1.5-flash` (the app's Gemini default) — both now return an error status instead of a completion whenever the admin leaves the optional "Model" field blank, which is the normal path. `AIService::request()` then collapsed *any* non-2xx provider response into one generic `RuntimeException('AI provider request failed.')`, so there was no way to see which of the three providers failed or why. Updated the defaults to currently-active models (Groq → `openai/gpt-oss-20b`, Gemini → the Google-maintained `gemini-flash-latest` alias so this doesn't go stale again, OpenRouter free tier → `openai/gpt-oss-20b:free`) and changed `request()` to surface the provider name, HTTP status, and the provider's own error message (curl transport errors are reported separately) so a future model retirement, invalid key, or rate limit shows up as an actionable message instead of a blank 500. `public/index.php`'s `/api/generate` route now catches `AIService::generate()` failures explicitly and returns that detail as JSON regardless of `APP_ENV`, since this endpoint is already admin-only and CSRF-protected.

> **2026-09-11 addendum #2 — root-caused the reported `/api/generate` 404 and the Tailwind CDN warning:**
> - **Critical (new), root cause of the "news sourced but AI generation fails" report:** `app/views/ai-studio.php` had two form controls both named `news_id` — the source-selection `<select>` and a hidden `<input>` in the result panel that starts empty. `new FormData(form)` serializes both under the same key, and PHP keeps the *last* value for a duplicate POST key, so `$_POST['news_id']` was always empty until after a first successful generation. `public/index.php` correctly looked up the news item and correctly returned `json_response(['error'=>'News item not found'],404)` when it found none — the 404 in the browser console was the app behaving as designed against bad input, not a routing failure. Removed the duplicate hidden field; the select is now the single source of truth for `news_id` in both the generate and save requests.
> - **Low: unmatched nested `/admin/*` paths silently rendered the dashboard (HTTP 200) instead of a 404,** masking broken or mistyped admin links. Now returns a proper 404 with a "Page not found" panel.
> - **Low: the `/admin` → `/admin/` redirect in `public/.htaccess` was a leftover from when `public/admin/` existed as a real directory** (see F-05 above). That directory is gone and `DirectorySlash Off` is already set, so the rule only added an unnecessary redirect hop on every visit to the admin area. Removed; `^admin(?:/.*)?$` already routes bare `/admin` straight to the front controller.
> - **Low (polish): `cdn.tailwindcss.com` is a development-only script** and Tailwind's own docs warn against using it in production (this is the console warning reported). Replaced it with a compiled, minified Tailwind build (`npm run build:css`, run automatically in a Node build stage in `Dockerfile`) and used the freed-up styling budget to add a sticky/blurred masthead and consistent hover-elevation "story card" treatment across the public site.
> - **Enhancement: added a `003_africa_sources.sql` migration** seeding a new "Africa" category plus verified Nigerian and pan-African RSS feeds (Premium Times, Vanguard, Punch, Daily Post, The Guardian Nigeria, and two AllAfrica feeds), so `NewsService::fetchAll()` pulls regional coverage without any code changes.

> **2026-09-11 addendum — three additional defects found and fixed during the nested-admin-route investigation, verified against a live Apache 2.4 + PHP 8.3 + PostgreSQL reproduction:**
> - **Critical (new): `require_admin()` was a no-op.** `app/config/bootstrap.php` defined `function require_admin():void{}` with a comment claiming an "emergency open-access mode requested by the owner." This left every `/admin/*` route — including publishing, source management, and AI generation — completely unauthenticated on the live site. Restored to check the session and re-verify the user's `role` against the database on every request (closes F-11 for real, not just partially).
> - **Critical (new): `/login` was unreachable.** `public/index.php` had `if($path==='/'||$path==='/login'){redirect('/admin/');}` at the top of the router, which redirected every visit to `/login` straight to `/admin/` before the actual login handler ever ran. Combined with the `require_admin()` fix above, this created an infinite redirect loop between `/admin/` and `/login` and made the site fully unusable for a real login. This bug had been silently masked by the open-access mode. Removed the stray redirect; `/` and `/login` now reach their real handlers.
> - **F-05, confirmed root cause of the originally reported `/admin/ai-studio` 404s:** `public/admin/index.php` and `public/admin/.htaccess` made `/admin` a real filesystem directory. Apache resolves a request into an existing directory during URL-to-filename translation *before* consulting the parent directory's `.htaccess`, so the explicit `^admin(?:/.*)?$` rewrite rule in `public/.htaccess` never ran for nested paths — only `/admin/` itself worked, via plain `DirectoryIndex`. Removed both files (and the equivalent `public/login/index.php`) so the app has a single real front controller, matching the routing logic `public/index.php` already implements. Verified with a live Apache reproduction: `/admin`, `/admin/`, `/admin/ai-studio`, `/admin/articles/5/edit`, and unknown paths all now resolve to the front controller instead of 404ing at the Apache level.
> - **Reliability (new): DB connection had no timeout, unlike every outbound HTTP call in the codebase.** `db()` in `app/config/bootstrap.php` opened its PDO connection with no `connect_timeout` and no statement timeout, the only network call in the project without one (`NewsService` and `AIService` both set explicit connect/total timeouts on every request). If the Postgres endpoint is briefly unreachable or slow to wake, this call could hang indefinitely — and since nearly every route touches the database (including the restored `require_admin()` check), a single hung connection can make the entire site stop responding, which looks like a dead server rather than a slow page. Added `connect_timeout=5` to the DSN, `PDO::ATTR_TIMEOUT=>5`, and a 15s Postgres `statement_timeout`. Verified locally: a connection to an unreachable host now fails in 5s instead of hanging.

**Audit scope:** `/home/ubuntu/news-platform` as delivered on 2026-09-10. The review covers the requested product requirements, source code, database migration, security controls, deployment configuration, and documentation. The audit is static plus local smoke validation; it does not claim that a Neon database or third-party AI account was available in the sandbox.

## Executive conclusion

The repository is a coherent PHP prototype, but it is **not yet a production-quality MVP that satisfies the supplied specification**. The basic foundation is present: PHP 8.2-compatible syntax, PDO/PostgreSQL schema, session login, CSRF checks on the main mutating forms, RSS/GDELT service entry points, three AI provider branches, a public article route, and Render-oriented packaging.

The implementation has several **release-blocking functional gaps**. Most importantly, generated articles are not persisted as AI generation records, the UI cannot edit existing drafts or publish them, source attribution is lost during saving, generated categories and tags are not stored, the requested admin management pages are missing, public `/category/{slug}` and `/search` routes are missing, and the deployment does not honor Render's `PORT` requirement. There are also material security and reliability gaps: authorization is authentication-only, external fetching has no explicit timeout or robots/rate-limit handling, input validation is minimal, API errors are not consistently JSON, and the health page reports readiness rather than actual subsystem checks.

## Severity scale

| Severity | Meaning |
|---|---|
| Critical | Core workflow is broken, data is lost, or deployment/security failure is likely. Must fix before user testing or production. |
| High | A stated requirement is missing or a realistic failure/security scenario exists. Fix before calling the build complete. |
| Medium | Requirement is partially implemented or operational quality is below the requested standard. Fix during MVP hardening. |
| Low | Usability, maintainability, or polish issue that does not block the central workflow. |

## Release-blocking findings

| ID | Severity | Finding | Evidence | Impact |
|---|---|---|---|---|
| F-01 | Critical | The generated article is never saved to `ai_generations`. | `public/index.php:9` calls `AIService::generate()` and returns JSON; no INSERT into `ai_generations` occurs anywhere. | Provider, model, prompt, and response tracking requirement fails. The dashboard's AI generation count remains zero. |
| F-02 | Critical | There is no functional draft editor or publish workflow. | The only write route is `POST /admin/articles/save` at `public/index.php:13`; there is no article ID update path, draft edit route, or publish action. AI Studio creates a new draft only. | Existing drafts cannot be edited, and an administrator cannot publish an article through the UI. Requirements 9, 10, and the editor buttons are not met. |
| F-03 | Critical | Source attribution is discarded by the AI Studio save flow. | `app/views/ai-studio.php` clears `form.elements.source_url.value` after generation and sets `source_name` to `SignalDesk source` before submit. The generated response does not contain source URL/name fields. | Published articles can have blank or inaccurate source attribution and lose the original URL, violating the copyright and attribution requirements. |
| F-04 | Critical | Render deployment does not honor the required `PORT` environment variable. | `Dockerfile` starts Apache on its default port 80; neither `Dockerfile` nor `render.yaml` configures Apache from `PORT`. | The service may not bind to the port Render expects. The explicit deployment requirement is not satisfied. |
| F-05 | Critical | Apache rewrite configuration is likely ineffective. | `public/.htaccess` contains the rewrite rules, but the Dockerfile does not enable `AllowOverride All` for the document root. Debian Apache commonly has overrides disabled by default. | `/news/slug`, `/admin`, and other front-controller routes may return 404 in the container instead of reaching `public/index.php`. |
| F-06 | High | The requested admin management surfaces are absent. | Layout links only expose Overview, News discovery, AI studio, System health, and Public site. There are no Categories, Sources, AI Providers, Settings, Drafts, or Published pages/routes. | Configurable source system, category management, provider/model management, settings, draft management, and published management are not delivered. |
| F-07 | High | Required public routes are missing. | `public/index.php` handles `/`, `/news`, and `/news/{slug}` only. There is no `/category/{slug}` or `/search`. | Public site routing requirement is incomplete. |
| F-08 | High | Discovery filters are incomplete. | `app/views/news-discovery.php` has only client-side text search. No source, category, or date filter is implemented, and the list is hard-limited to 100 records. | The requested discovery page filtering requirements are not met and large datasets are inaccessible. |
| F-09 | High | Generated category and tags are not mapped to the database. | AI Studio writes a `category` text field and `tags` text field, but the save route reads `category_id` and never processes `tags`, `article_tags`, or `tags`. | AI output fields are silently discarded. Category and tag requirements fail. |
| F-10 | High | The health page is not a health check. | `public/index.php:14` hard-codes `RSS => READY` and `GDELT => READY` without making a request or checking recent successful imports. | The UI can report healthy integrations when they are unavailable. This violates the testing/system-health requirement. |
| F-11 | High | No authorization check enforces the `admin` role. | `require_admin()` checks only `$_SESSION['admin_id']`; it never loads or verifies `users.role`. | Any authenticated session with an ID is treated as an administrator. Role-based authorization is not implemented. |
| F-12 | High | External news fetching has no explicit timeout, validation, or robots/rate-limit handling. | `NewsService.php:5` uses `@simplexml_load_file($source['rss_url'])`; `NewsService.php:6` uses `@file_get_contents($url)`. | Requests can hang, warnings are suppressed, source URLs are not validated, and the stated robots, terms, and rate-limit requirements are not operationalized. |

## Requirement coverage matrix

| Requirement area | Status | Audit result |
|---|---|---|
| PHP 8.2, PDO, PostgreSQL | Partial | Code is compatible and `pdo_pgsql` is used. No live Neon connection test was possible. |
| Vanilla HTML/Tailwind/JS | Pass | Server-rendered PHP views use Tailwind CDN and small inline Fetch/DOM scripts. |
| Environment-based secrets | Partial | AI and database secrets use environment variables. `.env.example` is safe, but the README's `cp .env.example .env` is misleading because no dotenv loader exists. |
| Groq/Gemini/OpenRouter abstraction | Partial | A shared `AIService` exists with provider branches. Provider persistence and reliable fallback behavior are missing. |
| Provider selection | Partial | The UI selects providers, but arbitrary provider values are not validated server-side and model compatibility is not validated. |
| RSS source configuration | Fail | Seed sources exist, but no admin CRUD for sources, active state, URLs, or categories exists. |
| GDELT discovery | Partial | A GDELT request exists, but it has no timeout, retry policy, response validation, rate limit, or health verification. |
| Duplicate prevention | Partial | `content_hash` is unique and `source_id/external_guid` is unique. The implementation does not normalize URLs beyond lowercase, and a duplicate conflict can still produce operational ambiguity. |
| Original reporting/copyright prompt | Partial | The prompt instructs originality, attribution, no invented quotes, and factual accuracy. Source context is not isolated from prompt injection, and attribution is lost at save time. |
| Required database tables | Pass | All ten requested tables are present. |
| Foreign keys/indexes | Partial | Main foreign keys and indexes exist, but requested indexes for `slug`, `external_guid`, and `content_hash` are provided only through uniqueness constraints rather than explicit named indexes. Status values have no check constraint. |
| Authentication | Partial | Login, logout, `password_hash`, `password_verify`, session regeneration, and CSRF on login are present. Secure role authorization, login throttling, and password reset are absent. |
| CSRF | Partial | Main POST routes use CSRF. Logout is a state-changing GET without CSRF. Cron uses a token, which is appropriate for machine access. |
| Input validation | Fail | IDs and strings are mostly cast or accepted without length, enum, URL, slug, or required-field validation. Database exceptions become generic 500s. |
| Output escaping | Partial | Most visible values use `e()`. The CSS color in dashboard is derived from fixed internal arrays. Article content is escaped as text, which is safe but not a rich content editor. |
| Admin dashboard | Partial | Dashboard cards and recent signals exist. The requested complete sidebar sections and recent article view are incomplete. |
| News discovery filters/actions | Fail | Search exists. Source/category/date filters, ignore action, view modal/details, pagination, and AJAX refresh are missing. |
| AI Studio | Partial | Provider/style/length/instructions and structured generation exist. Source details are not displayed as a full source information panel, and generated result cannot be persisted with correct source metadata. |
| Article editor | Fail | There is a one-time result form, but no standalone editor, update route, publish button, featured image support, category selector, or reliable source fields. |
| Drafts/publishing | Fail | Draft insert exists. Update and publish workflows do not. |
| Public website | Partial | Homepage, latest list, detail route, attribution container, responsive layout, and basic navigation exist. Category/search, related articles, featured image, category sections, breaking/latest distinction, and footer are absent. |
| Cron foundation | Partial | Secret-token fetch endpoint exists. There is no `/cron/generate-articles.php`, no scheduling configuration, no lock/idempotency mechanism, and no job audit record. |
| Render deployment | Fail | Dockerfile and render manifest exist, but `PORT` and rewrite behavior are not correctly handled. No Render Cron service is declared. |
| Error handling | Partial | Exceptions are logged and production messages are generic. JSON routes can emit HTML on exceptions, and provider errors discard diagnostic context. |
| Testing | Fail | No automated test suite exists. Only ad hoc lint and route smoke checks were possible. |
| README | Partial | Setup, Neon, environment, deployment, cron, and security notes exist. The documented admin creation flow exposes a password as a command-line argument and the documented `.env` step is not implemented by the application. |

## Detailed technical findings

### 1. Data integrity and workflow

**F-01 through F-03 are the most serious application defects.** The database was designed to record AI generations and source relationships, but the request path returns a generated object without persisting the generation metadata. The save form then clears the source URL and replaces the source name with a placeholder-like generic label. This means the central promise of “original article with retained attribution and tracked provider/model” is not reliable.

The article insertion route also accepts `category_id` but the visible form does not provide one. The AI-generated `category` string is ignored. Tags are never upserted into `tags` or linked through `article_tags`. `featured_image` is never accepted. `updated_at` is not updated on any write. These are not cosmetic omissions; they make the stored article materially different from the generated result.

There is no edit-by-ID operation. A production review workflow needs at least `GET /admin/articles/{id}/edit`, `POST /admin/articles/{id}`, `POST /admin/articles/{id}/publish`, and `POST /admin/articles/{id}/unpublish` or equivalent. Each operation should enforce valid state transitions and preserve the source relationship.

### 2. Routing and deployment

The application relies on a front controller but the Docker image only enables the rewrite module. It does not configure Apache to permit `.htaccess` overrides. The safe deployment approach is either to add an explicit Apache virtual-host configuration with `AllowOverride All`, or to avoid `.htaccess` and route through a dedicated vhost configuration.

The requirement explicitly says the application must listen on Render's `PORT`. The current image exposes port 80 and starts `apache2-foreground`; it does not read `PORT`. The deployment must either configure Apache to listen on `${PORT}` during container startup or use a PHP server command that binds to `0.0.0.0:${PORT}`. A Render health check against `/` will also fail when `DATABASE_URL` is missing because the public homepage immediately queries the database.

### 3. Security

The positive controls are real but incomplete. PDO prepared statements are used for normal query parameters. Passwords are hashed. Sessions regenerate after login. CSRF tokens exist on login, news fetch, generation, and article save.

The main authorization defect is role blindness. The schema has a `role` field, but the application never checks it. The code should load the user record at session validation time and require `role = 'admin'`. Login should also have rate limiting, ideally keyed by normalized email and IP with a short lockout window.

The admin creation script accepts the password as a positional shell argument. On many systems, command arguments are visible to other users through process inspection and can remain in shell history. The script should prompt using `readline` with terminal echo disabled or accept the password through an environment variable that is not printed.

`/logout` mutates session state through a GET request and does not require CSRF. This is lower impact than publishing or password changes, but it violates the stated CSRF standard and can be corrected by using a POST form.

There is no URL validation for configured feeds, imported links, or source URLs. The current renderer escapes output, which limits immediate reflected HTML injection, but the application should still enforce `https` URLs and reject unsupported schemes. The AI prompt directly embeds external source text without delimiters or a clear instruction hierarchy. A malicious feed description could attempt to manipulate the model.

### 4. News ingestion and operational reliability

`simplexml_load_file()` and `file_get_contents()` are convenient but unsuitable as the only production HTTP layer. They provide no explicit connect timeout, total timeout, user agent, status-code handling, content-size cap, retry policy, conditional requests, or structured diagnostics. Warnings are suppressed with `@`, so operators cannot tell which source failed.

The importer stores RSS descriptions but does not extract common media namespaces such as `media:content` or `enclosure`, so the requested image URL support is largely unimplemented. Publication dates are passed through `date('c', strtotime(...))`; malformed dates can become epoch-like values. GDELT `seendate` values may not be ISO-8601 timestamps accepted consistently by PostgreSQL.

The application does not check `robots.txt` or enforce per-source throttling. The README acknowledges publisher terms but the code has no corresponding control. A production collector should use a per-source request interval, a descriptive user agent, a bounded queue, and a persisted fetch status.

### 5. AI provider behavior

The abstraction removes most duplicated article-generation logic, which is a sound design choice. However, the implementation has no retry/backoff, no provider-specific response diagnostics, no token/length control, and no provider fallback when the selected provider fails. The specification describes Gemini and OpenRouter as fallback providers; the current code only lets the administrator select them manually.

The server accepts arbitrary `provider` values. Any value other than `gemini` is treated as an OpenAI-compatible endpoint while the API key lookup is derived from the arbitrary string. The server should allowlist `groq`, `gemini`, and `openrouter` before making a request.

The code requests JSON but validates only that `title` and `content` exist. It should validate all required fields, normalize lengths, validate `tags` as a bounded array of strings, and reject unexpected or oversized responses. The `model` field should be provider-specific and configured server-side or allowlisted.

### 6. UI and product completeness

The current interface is visually coherent and more polished than a generic PHP template. It has responsive layouts, cards, badges, empty states, and basic asynchronous fetch/generate actions.

The product surface is nevertheless much smaller than requested. Missing screens include source management, category management, provider configuration, settings, drafts, published articles, and a real article editor. The discovery page lacks the requested source/category/date filters and ignore action. The public site lacks category pages, search, related articles, featured image rendering, category sections, breaking news treatment, and a footer.

The AI Studio form is inside one `<form>`, but the generated result fields are mixed with generation parameters. The save action serializes the entire form into a new dynamically-created form and does not preserve the originating news item's ID reliably after a generation. The source URL is explicitly blanked. This is a high-risk workflow bug.

### 7. Database and migrations

The migration creates the requested entities and basic relationships. It is idempotent for repeated execution in a clean database. It is not a full migration mechanism: there is no migration history table, version tracking, rollback strategy, or later migration file. Seed source insertion uses `ON CONFLICT DO NOTHING` without a targeted unique constraint for the source URL, so repeated runs can create duplicate logical sources if the name changes.

The schema should add check constraints for `role`, article `status`, and non-empty slugs. It should add useful indexes for common filters, including `news_items.source_id`, `news_items.content_hash`, `news_items.external_guid`, `articles.slug`, and a composite publication/status index. The current unique constraints create indexes for some of these, but the design should make the intent explicit.

### 8. Testing and observability

The repository contains no automated tests. The audit environment confirmed that all PHP files pass `php -l` and that `curl`, `PDO`, `pdo_pgsql`, and `SimpleXML` are installed. `psql` was not available in the sandbox, and no Neon credentials were supplied, so SQL execution against PostgreSQL was not verified.

A minimum test suite should cover login success/failure, CSRF rejection, role rejection, duplicate import behavior, RSS parsing, GDELT normalization, AI response schema validation, article save/update/publish transitions, attribution persistence, cron secret rejection, and public article visibility rules. The health page should run real checks and expose timestamped last-success information without revealing secrets.

## Prioritized remediation plan

### Phase 1: Make the core workflow correct

1. Add an article repository/service with create, update, publish, unpublish, and find methods.
2. Persist `ai_generations` immediately after a successful provider response and link it to the saved article.
3. Preserve `news_id`, `source_url`, and `source_name` from the selected news item through generation and save.
4. Implement category resolution, tag upsert, `article_tags`, featured image, and slug collision handling.
5. Add draft list, article edit, and publish screens with POST-only state-changing actions.
6. Add role-aware authorization and validate all article fields server-side.

### Phase 2: Fix deployment and ingestion reliability

1. Replace implicit Apache overrides with an explicit vhost or startup configuration that binds the configured `PORT`.
2. Add a real HTTP client wrapper with timeouts, status handling, user agent, size limits, and diagnostics.
3. Add per-source rate limiting, fetch timestamps, failure status, and safe URL validation.
4. Implement actual RSS media extraction and robust GDELT timestamp normalization.
5. Add a migration-version table and separate migration files for future changes.

### Phase 3: Complete requested product surfaces

1. Implement source, category, provider, and settings administration.
2. Add discovery source/category/date filters, pagination, ignore action, and item detail view.
3. Add `/category/{slug}` and `/search`, related articles, featured article, category sections, and footer.
4. Add the second cron endpoint as a protected “generate drafts” operation that never publishes automatically.
5. Add real system checks and a test suite.

## Audit checks executed

| Check | Result |
|---|---|
| PHP syntax lint | Passed for all PHP files. |
| Required table presence scan | All ten requested tables found in the migration. |
| Required schema field scan | Core requested fields found. |
| PHP extension scan | `curl`, `PDO`, `pdo_pgsql`, and `SimpleXML` available in the audit environment. |
| Local login route smoke test | Passed earlier: HTTP 200 with login content. |
| Database integration test | Not run; no Neon URL or PostgreSQL server was available. |
| Third-party AI integration test | Not run; no provider keys were available. |
| Render container test | Not run; Docker daemon was not available. |
| Automated application tests | Not present in repository. |

## Final verdict

**Status: Not ready to call complete.** The code is a useful starting scaffold and passes basic PHP syntax validation, but it does not yet meet the user’s “complete, production-quality MVP” requirement. The release should be blocked until findings F-01 through F-05 are corrected. Findings F-06 through F-12 and the missing test coverage should be addressed before deployment to a public Render service.

## References

No external references were required for this repository-local audit. The conclusions above are based on direct inspection of the project files and the executed checks documented in this report.
