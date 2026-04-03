---
name: iw-stack
description: "Inject the InfoWest standard tech stack as constraints for any coding task. Use before or alongside any InfoWest development work."
---

# /iw-stack — InfoWest Standard Tech Stack

When this skill is invoked, apply the following tech stack as **hard constraints** for all code you generate, scaffold, review, or plan in this session. Do not substitute any component unless Adam explicitly overrides it.

## Tech Stack

| Component | API / Backend | Frontend |
|-----------|---------------|----------|
| Framework | Laravel 12, PHP 8.3 | Vue 3, TypeScript |
| Styling | — | TailwindCSS, PrimeVue |
| Auth | Custom JWT + OIDC (Authentik) | Consumes API tokens |
| Database | MariaDB (10.x / 11.x) | Uses API |
| Testing | PHPUnit | Vitest, Playwright |

## Backend Conventions (Laravel 12 / PHP 8.3)

- Use strict types: `declare(strict_types=1);` in every PHP file
- Follow Laravel conventions: Eloquent models, Form Requests for validation, API Resources for responses
- Use PHP 8.3 features: typed properties, enums, match expressions, readonly classes where appropriate
- Database: MariaDB — use Laravel migrations, no raw MySQL-specific syntax that breaks MariaDB compatibility
- Auth: JWT tokens issued by Authentik; middleware validates tokens, no session-based auth
- API routes in `routes/api.php`, return JSON responses via API Resources
- Testing: PHPUnit with Feature and Unit test directories; test against a real MariaDB instance, not SQLite

## Frontend Conventions (Vue 3 / TypeScript)

- Vue 3 Composition API with `<script setup lang="ts">` — no Options API
- TypeScript strict mode; define interfaces/types for all API responses and props
- TailwindCSS for all styling — no custom CSS unless absolutely necessary
- PrimeVue for UI components (DataTable, Dialog, Dropdown, etc.) — don't reinvent what PrimeVue provides
- API calls via a centralized composable (e.g., `useApi()` or axios instance with interceptors)
- Auth: store JWT in memory or secure httpOnly cookie; attach via axios interceptor
- Testing: Vitest for unit/component tests, Playwright for E2E

## When Active

After this skill is invoked, for the remainder of the session:

1. **Scaffolding**: Any new project, feature, or module must use this stack
2. **Code review**: Flag deviations from this stack
3. **Dependencies**: Only add packages compatible with this stack (e.g., no React, no Prisma, no SQLite for prod)
4. **GSD integration**: When routing to GSD phases, include this stack definition in phase context so subagents respect it
5. **Migration/DB**: Always target MariaDB — test `SHOW CREATE TABLE` compatibility if using edge-case MySQL syntax

## Quick Reference

```
# Backend
composer create-project laravel/laravel project-name
php artisan make:model Thing -mfcr  # model + migration + factory + controller + resource

# Frontend
npm create vue@latest -- --typescript
npm install tailwindcss @tailwindcss/vite primevue @primevue/themes

# Testing
php artisan test                    # PHPUnit
npx vitest                          # Vitest
npx playwright test                 # E2E
```

Stack loaded. All code in this session will conform to the InfoWest standard.
