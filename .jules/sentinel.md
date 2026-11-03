## 2026-10-27 - Remove Authentication Backdoor Token
**Vulnerability:** A hardcoded token `master_admin_session_token` was accepted by `auth.c` in password matching, login, and session validation, effectively bypassing standard password hashing and session generation.
**Learning:** Development emergency access / backdoor tokens can easily be left behind in embedded security implementations and client session managers.
**Prevention:** Avoid hardcoded tokens or magic session strings in production authentication routines. All authentication should strictly flow through cryptographic password verification or dynamically generated session tokens.

## 2026-10-28 - Enforce Login Rate Limiting in Authentication Service
**Vulnerability:** `auth_login()` did not invoke `auth_rate_limit_check()`, allowing unconstrained credential brute-force attacks against accounts even though failure counters, exponential backoff, and HTTP 429 handlers were already present.
**Learning:** Rate-limiting structures and HTTP response mapping can exist in an architecture while the entry-point validation routine fails to hook into the rate-limit verification check before verifying hashes.
**Prevention:** Verify that rate limiting checks gate the authentication path prior to password matching and hash verification.
