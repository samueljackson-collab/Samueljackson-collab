# Production Checklist — ElderPhoto

Work through every item before deploying or releasing a new version. Check each box only when
the criterion has been verified.

---

## Prerequisites

- [ ] `backup_sync.py` known bugs are fixed (duplicate `main()`, missing `sys`/`logging` imports,
      undefined `DEFAULT_PROMPT` and `args.yes`) — confirmed by `pytest backend/tests/test_backup_sync.py`
      passing with zero failures
- [ ] All five frontend test files pass: `cd frontend && npm test`
- [ ] All three backend test files pass: `cd backend && pytest --tb=short`
- [ ] `cd frontend && npm run build` completes with zero TypeScript errors
- [ ] Frontend Lighthouse accessibility score is 90 or higher (see below)

---

## Environment & Configuration

- [ ] `.env.local` (or equivalent secrets manager) contains valid values for all required
      variables (`VITE_API_BASE_URL`, `ALLOWED_ORIGINS`)
- [ ] `ALLOWED_ORIGINS` is set to the production frontend domain — **not** `localhost` and not
      the wildcard `*`
- [ ] `VITE_API_BASE_URL` points to the production backend URL
- [ ] No `.env.local` or secrets file is committed to version control
- [ ] Backend virtual environment is activated and `pip install -r requirements.txt` has been
      run against the production Python version

---

## Photo Upload

- [ ] Upload a 5 MB JPEG photo via the Upload screen; confirm the upload completes successfully
      and the photo appears in the Gallery
- [ ] Upload a 5 MB PNG photo; confirm it is accepted and displayed correctly
- [ ] Attempt to upload a file type that is not an image (e.g., a `.pdf`); confirm the backend
      returns an appropriate error and the UI displays a user-friendly message
- [ ] Upload multiple files at once; confirm all are processed and stored correctly

---

## Backup Synchronisation

- [ ] `backup_sync.py` bugs are fixed (this is a hard prerequisite — do not deploy with known
      bugs in this script)
- [ ] Run a full sync against two local test directories; confirm files are mirrored correctly
      and the script exits 0
- [ ] Run an incremental sync; confirm only changed/new files are copied
- [ ] Run `verify_sync` and confirm it reports no discrepancies on a freshly synced directory
- [ ] Trigger a backup via the UI **Backup** screen; confirm the backend responds with success
      and no errors appear in server logs

---

## Accessibility

- [ ] Open the app in Chrome or Edge; run DevTools > Lighthouse > Accessibility; score must be
      90 or higher
- [ ] All primary action buttons render with white text on `#0D47A1` background (contrast
      ratio 8.63:1, WCAG AAA)
- [ ] Body text is near-black `#0A0A0A` on white background
- [ ] All images have descriptive `alt` attributes (check with axe DevTools or a screen reader)
- [ ] Keyboard navigation reaches all interactive elements in a logical order (Tab through the
      entire page)
- [ ] All form fields have associated `<label>` elements

---

## Access Control (go/no-go)

- [ ] Confirm the deployment target is **single-household** (one backend
      instance serves exactly one family). If so, the lack of per-user/
      household authorization is acceptable — see `backend/SECURITY_NOTES.md`.
- [ ] If the deployment target is **multi-household / shared** (multiple
      families on one backend instance), **do not deploy** until
      authentication and household/user-scoped filtering have been added to
      `backend/app/routers/photos.py` and `backend/app/routers/images.py`.
      The CORS allow-list and CSRF origin check are not a substitute for
      authentication — they restrict origins, not users.

---

## CORS & API

- [ ] From the production frontend origin, confirm that API calls to the backend succeed without
      CORS errors in the browser console
- [ ] From an unexpected origin, confirm that the backend returns a CORS error (not a silent
      success)
- [ ] FastAPI `/docs` Swagger UI is either disabled or access-restricted in production

---

## Performance & Build

- [ ] `npm run build` output in `frontend/dist/` is under a reasonable size budget
- [ ] App loads in under 3 seconds on a standard broadband connection
- [ ] Calendar and gallery screens load without visible layout shift or spinner timeout
- [ ] Photo thumbnails are served at an appropriate resolution (not full-resolution originals)

---

## Security

- [ ] File upload endpoint validates MIME type and file extension server-side, not only
      client-side
- [ ] Backend does not expose internal file system paths in API error responses
- [ ] Python dependencies are pinned and reviewed for known CVEs (`pip-audit` or equivalent)
- [ ] Node dependencies are reviewed (`npm audit`)

---

## Rollback Plan

- [ ] Previous working backend and frontend artifacts are retained before deploying
- [ ] Rollback procedure is documented and can be completed in under 10 minutes
- [ ] Database/photo storage backup taken before migrating any schema or storage layout changes
