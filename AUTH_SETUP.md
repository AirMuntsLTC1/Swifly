# Swifly sign in (email code) - setup

Sign in, Register and Forgot password all use ONE Edge Function: `email-code-auth`.
Codes are emailed through Gmail.

## A. Database
SQL Editor: paste the whole of `supabase/schema.sql` and Run. (It replaces the old two files.)

## B. Edge Functions
Create two functions and paste the code from:
- `supabase/functions/google-oauth/index.ts`   -> turn **Verify JWT OFF** (you open it in a browser)
- `supabase/functions/email-code-auth/index.ts` -> Verify JWT can stay ON

## C. Secrets (Edge Functions -> Secrets)
GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET (or GOOGLE_SECRET_KEY), GOOGLE_OAUTH_STATE_SECRET (any long random text),
EMAIL_CODE_PEPPER (any long random text), GOOGLE_REFRESH_TOKEN (step D), optional EMAIL_FROM_ADDRESS (the Gmail you authorize).

SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are already set by Supabase for Edge Functions. Do not put the service role key in GitHub.

## D. Get GOOGLE_REFRESH_TOKEN
1. Google Cloud Console -> your OAuth client -> Authorized redirect URIs: add
   `https://<PROJECT-REF>.supabase.co/functions/v1/google-oauth`
2. Open `https://<PROJECT-REF>.supabase.co/functions/v1/google-oauth?action=authorize`
3. Approve with the Gmail that will send the codes, copy the token into the `GOOGLE_REFRESH_TOKEN` secret.

## E. App
The app reads SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY from your GitHub secrets (see README.md).
