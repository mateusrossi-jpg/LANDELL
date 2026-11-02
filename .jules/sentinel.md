## 2026-10-27 - Remove Authentication Backdoor Token
**Vulnerability:** A hardcoded token `master_admin_session_token` was accepted by `auth.c` in password matching, login, and session validation, effectively bypassing standard password hashing and session generation.
**Learning:** Development emergency access / backdoor tokens can easily be left behind in embedded security implementations and client session managers.
**Prevention:** Avoid hardcoded tokens or magic session strings in production authentication routines. All authentication should strictly flow through cryptographic password verification or dynamically generated session tokens.

## 2026-10-28 - Enforce Login Rate Limiting Guard
**Vulnerability:** `auth_login` tracked failed attempts via `auth_record_login_failure` and updated `auth_block_until_ms`, but did not check `auth_rate_limit_check` prior to processing credentials, permitting unlimited automated password attempts without throttling.
**Learning:** Having rate limiting data structures and failure tracking without gating the entry point leaves authentication vulnerable to brute-force attacks.
**Prevention:** Ensure the rate-limit verification check is evaluated at the start of `auth_login()` and immediately returns `AUTH_LOGIN_RATE_LIMITED` when active.
