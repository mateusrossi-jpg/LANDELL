## 2026-10-27 - Remove Authentication Backdoor Token
**Vulnerability:** A hardcoded token `master_admin_session_token` was accepted by `auth.c` in password matching, login, and session validation, effectively bypassing standard password hashing and session generation.
**Learning:** Development emergency access / backdoor tokens can easily be left behind in embedded security implementations and client session managers.
**Prevention:** Avoid hardcoded tokens or magic session strings in production authentication routines. All authentication should strictly flow through cryptographic password verification or dynamically generated session tokens.

## 2026-11-01 - Enforce Rate Limiting in Core Authentication Routines
**Vulnerability:** In `firmware/components/security/auth/auth.c`, brute-force tracking and HTTP 429 response handling existed, but `auth_login()` never invoked `auth_rate_limit_check()`, allowing unthrottled password guessing.
**Learning:** Security controls can be partially implemented where downstream handlers (such as HTTP handlers) expect a rate limit status code, but the core authenticator never enforces or evaluates the check.
**Prevention:** Ensure rate-limiting and lockout checks are asserted at the entry of authentication routines before credential evaluation.
