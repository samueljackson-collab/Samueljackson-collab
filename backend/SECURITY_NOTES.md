# Security Notes — ElderPhoto Backend

## Single-household deployment model (no multi-tenant isolation)

**Status: by design, not a bug.**

ElderPhoto's backend has no concept of users, accounts, households, or
tenants anywhere in its data model or routes:

- There is no `models.py` / ORM layer and no database — uploaded photos are
  stored as flat files on disk under `UPLOAD_DIR` (`backend/app/routers/photos.py`).
- `Photo` records (as returned by `GET /photos`) carry only `filename` and
  `url` — there is no `user_id`, `owner_id`, or `household_id` field to scope
  by, because no such concept exists in the app.
- The only access boundary today is the CORS allow-list
  (`CORS_ALLOWED_ORIGINS` in `backend/app/main.py`) plus an origin-based CSRF
  check on state-changing requests. Neither of these authenticates *who* is
  calling — they only restrict *which web origins* may call the API at all.
- There is no authentication middleware, login flow, session, or API key
  check anywhere in `backend/app/`.

**Conclusion:** any client that can reach the API and pass the CORS/CSRF
origin check can see and upload all photos. This is consistent with the
product's stated purpose — sharing photos within **one family** — where a
single backend deployment serves a single household. It is not a
multi-tenant product, so there is no "other household's data" for a
per-user access-control layer to protect against today.

**This is intentionally out of scope for this change.** Adding per-user/
household authorization here would mean building a new auth system
(accounts, sessions or tokens, and a `household_id`/`user_id` column with
nothing currently in the schema to attach it to) that doesn't match any
existing product requirement. That is a larger product decision, not a bug
fix.

### Go/No-Go implication for production

If this app is ever deployed such that **multiple families/households share
the same backend instance** (e.g., a hosted multi-tenant SaaS offering
rather than "one deployment per family"), the current design is **not
safe** for that use case: every photo is visible to every caller that
clears the CORS/CSRF check, with no further isolation.

- Single-household deployment (current design): acceptable as-is.
- Multi-household / shared deployment: **do not ship** without first adding
  authentication (so the API knows *who* is calling) and a
  household/user-scoping column plus filtering on every read/write path in
  `backend/app/routers/photos.py` and `backend/app/routers/images.py`.

See the "Access Control" checklist item in `docs/PRODUCTION_CHECKLIST.md`
for the corresponding go/no-go gate.

## Backup job status (added)

`POST /backup/photos` now returns a `job_id`. Callers can poll
`GET /backup/status/{job_id}` (or `GET /backup/status` for the most recent
job) to see whether the backup is `pending`, `running`, `success`, or
`failed`. Job state is tracked in-memory only (no database in this app) and
is reset on process restart — this is sufficient for a single-process
single-household deployment but would not survive a multi-process/
horizontally-scaled deployment without a shared store.
