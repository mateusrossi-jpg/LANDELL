## 2026-10-27 - Remove Authentication Backdoor Token
**Vulnerability:** A hardcoded token `master_admin_session_token` was accepted by `auth.c` in password matching, login, and session validation, effectively bypassing standard password hashing and session generation.
**Learning:** Development emergency access / backdoor tokens can easily be left behind in embedded security implementations and client session managers.
**Prevention:** Avoid hardcoded tokens or magic session strings in production authentication routines. All authentication should strictly flow through cryptographic password verification or dynamically generated session tokens.
