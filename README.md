# SignalDesk

SignalDesk is a PHP 8.2/PostgreSQL newsroom platform for discovering current stories, generating original attributed reports, reviewing drafts, and publishing approved articles. It uses PDO, server-rendered HTML, a compiled Tailwind CSS build, and vanilla JavaScript. It does not use Laravel, React, Node.js as a backend, SQLite, or WordPress. Node.js is used only at build time to compile CSS — never at runtime.

## Delivered capabilities

The application includes RSS and GDELT discovery, deduplication, source/category administration, session-based admin authentication, CSRF protection, role checks, rate limits, provider abstraction for Groq/Gemini/OpenRouter, structured JSON generation, AI-generation audit records, draft editing, publishing, tags, source attribution, public search, public category pages, related articles, a health page, and a protected cron foundation.

## Local setup

Requirements are PHP 8.2+, PostgreSQL 14+, Node.js 20+ (build time only), and PHP extensions `pdo_pgsql`, `curl`, and `simplexml`.

```bash
npm install
npm run build:css   # writes public/assets/app.css; re-run after editing views or src/app.css
export DATABASE_URL='postgresql://user:password@host/db?sslmode=require'
export APP_ENV=development
php database/migrate.php
php bin-create-admin.php "Editor" editor@example.com
php -S 0.0.0.0:8000 -t public
```

The Docker image builds this same CSS automatically in a Node stage, so `npm run build:css` is only needed for local `php -S` development.

The admin creation command prompts for the password and never requires it as a process argument. It requires at least 12 characters. Visit `/login` after starting the server.

## Neon configuration

Create a PostgreSQL project at [Neon](https://neon.tech), copy the pooled connection string, and set it as `DATABASE_URL`. Run `php database/migrate.php`; it tracks applied migration versions in PostgreSQL and runs ordered SQL files once. Add the same `DATABASE_URL` to the Render service environment. Do not commit a `.env` file; this application reads environment variables directly and does not load dotenv files.

## Environment variables

`DATABASE_URL` is required. `APP_ENV` defaults to `production`. `CRON_SECRET` protects `/cron/fetch-news.php` and `/cron/generate-articles.php`. Configure one or more of `GROQ_API_KEY`, `GEMINI_API_KEY`, and `OPENROUTER_API_KEY`. Provider keys stay on the server and are never included in browser code. `ADMIN_PASSWORD` is optional for non-interactive container use of the admin creation script.

## AI and attribution policy

The generation prompt treats imported source material as untrusted reference text. It requires original reporting, factual accuracy, no sentence copying, no invented quotes, clear distinction between confirmed facts and claims, and source attribution. Generation records preserve provider, model, prompt, response, and article relationship. Every saved article carries the selected source name and validated original URL. The system stores RSS descriptions rather than scraping full publisher articles; operators must respect source terms, robots guidance, attribution rules, and rate limits.

## Editorial workflow

The intended lifecycle is discovered → review → AI generated → draft → administrator approval → published. AI generation never publishes automatically. Drafts can be edited from `/admin/articles?status=draft`, and the editor provides separate Save draft and Publish actions. Published articles are available through `/`, `/news`, `/news/{slug}`, `/category/{slug}`, and `/search?q=...`.

## Deployment to Render

Push the repository to GitHub and create a Render Web Service from the included `render.yaml` or Dockerfile. The container startup script reads Render's `PORT`, configures Apache to listen on that port, enables `AllowOverride All` for the public document root, and supports both web and cron commands. Add `DATABASE_URL`, `CRON_SECRET`, and the available AI keys as environment variables. The manifest also includes a 30-minute news-fetch cron service. The cron service only discovers and stores stories; it never publishes articles.

Before first login, run the migration files against Neon and create an admin using the safe CLI script in a trusted shell. The web service health check uses `/login`, which does not require a database query.

## Security and operations

All normal database queries use PDO prepared statements. Sessions use strict mode, HttpOnly/SameSite cookies, and session regeneration after login. Admin access requires a session tied to a user with role `admin`. State-changing browser requests use CSRF tokens. News and AI endpoints have bounded session rate limits. External fetches validate HTTP(S) URLs, use bounded connect and total timeouts, cap response size, and send a descriptive user agent. API routes return JSON errors instead of HTML stack traces. Production exceptions are logged server-side and shown as generic messages.

The health page tests database connectivity, an active RSS source, GDELT, and provider configuration without exposing credentials. Review logs for source failures and provider errors. The migration hardening file adds status/role constraints and operational indexes.

## Troubleshooting

If the database health check fails, verify the Neon connection string and `pdo_pgsql`. The Dockerfile installs `libpq-dev` before compiling `pdo_pgsql`; this is required because the extension build needs `libpq-fe.h` and `pg_config`. It also installs `libcurl4-openssl-dev` before compiling PHP cURL because the build requires `libcurl` pkg-config metadata. If an old image is cached, trigger a clean Render rebuild. If discovery returns source failures, inspect the health page and server logs; malformed feeds or publisher rate limits are reported without aborting all other sources. If generation fails, select a configured provider and check its model/account permissions. If a slug conflicts, edit the slug before saving. If Render cannot start the service, verify that the container is using the included entrypoint and that the service is not overriding the port incorrectly.

## Project structure

`public/index.php` is the front controller. `app/config/bootstrap.php` contains environment, database, session, CSRF, escaping, validation, authorization, rate-limit, and rendering helpers. `app/services/NewsService.php` handles RSS/GDELT collection and health checks. `app/services/AIService.php` handles provider-specific requests and shared validation. `app/views/` contains the public and admin UI. `database/migrations/` contains ordered SQL migrations. `docker-entrypoint.sh`, `Dockerfile`, and `render.yaml` provide deployment configuration.
