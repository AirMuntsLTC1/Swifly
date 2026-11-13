# Swifly sign in (email code) - setup

Sign in / Register / Forgot password all use ONE Edge Function: `email-code-auth`.
Codes are emailed through Gmail (same method as your Intly app).

## A. New Supabase project
1. SQL editor: run `supabase/schema.sql`, then `supabase/auth_setup.sql`.
2. Authentication -> Providers -> Email: you can leave it on. Users are created by the function (already confirmed).
3. Paste Project URL + anon key into `lib/supabase_config.dart`.

## B. Edge Functions
Create two functions and paste the code from:
- `supabase/functions/google-oauth/index.ts`   -> turn **Verify JWT OFF** (you open it in a browser)
- `supabase/functions/email-code-auth/index.ts` -> Verify JWT can stay ON

## C. Secrets (Edge Functions -> Secrets)
GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET (or GOOGLE_SECRET_KEY), GOOGLE_OAUTH_STATE_SECRET (any long random text),
EMAIL_CODE_PEPPER (any long random text), GOOGLE_REFRESH_TOKEN (step D), optional EMAIL_FROM_ADDRESS (the Gmail you authorize).

## D. Get GOOGLE_REFRESH_TOKEN
1. Google Cloud Console -> your OAuth client -> Authorized redirect URIs: add
   `https://<NEW-PROJECT-REF>.supabase.co/functions/v1/google-oauth`
2. Open `https://<NEW-PROJECT-REF>.supabase.co/functions/v1/google-oauth?action=authorize`
3. Approve with the Gmail that will send the codes, copy the token into the `GOOGLE_REFRESH_TOKEN` secret.

## E. App
`flutter pub get` (adds supabase_flutter). Build with your GitHub Action as usual.
Set `kRequireLogin = false` in `lib/app_config.dart` to skip sign in while testing.
