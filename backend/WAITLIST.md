# Waitlist

One endpoint. The website's only piece of backend.

```
POST /api/waitlist   { "email": "..." }  ->  { "ok": true }
```

## Rules

- **Validate server-side.** Client validation is a convenience, never a control.
- **Rate-limit by IP.** A public form with no limit is a spam list waiting to happen, and
  cleaning one up later costs more than adding the limit now.
- Spam protection without a CAPTCHA if possible: a honeypot field plus a minimum
  time-to-submit stops nearly everything, and never blocks a real person or asks them to
  identify a bus.
- **Store the minimum.** Email and timestamp. Not IP, not user agent, not a fingerprint.
  Everything stored has to be justified in the privacy policy, so store less.
- Confirm double opt-in before anything is ever sent to the list.

## Choice

Per the backend-selection playbook: this is a single table with one column that matters and
no realtime need, so **Supabase** (Postgres, RLS on, insert-only anon policy) or Resend
Contacts both fit. Supabase if the app later needs accounts; Resend if the list will only
ever be emailed.

Pick one, write down why in `docs/DECISIONS.md`, do not build both.

## Never

- Never put the service-role key in the frontend. Anon key plus an insert-only RLS policy, or
  a server route that holds the secret.
- Never log submitted emails.
- **Never point a production redirect or webhook at localhost.**
