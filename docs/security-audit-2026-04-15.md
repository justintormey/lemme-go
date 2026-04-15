# LemmeGo — Security & PII Audit
**Date:** 2026-04-15  
**Issue:** #11 — QA before making repo public  
**Scope:** Full git history (45 commits), current HEAD, all tracked files

---

## Verdict: SAFE TO PUBLISH

No credentials, API keys, passwords, private keys, SSNs, phone numbers, or sensitive PII found in current HEAD or git history.

---

## Findings

### Fixed in This Audit (commit b86187c)

| Finding | Location | Risk | Resolution |
|---------|----------|------|------------|
| `.claude/settings.local.json` still tracked | HEAD | Low | `git rm --cached` + deleted. File only contained Xcode sandbox permissions — no credentials. Was supposed to be removed in #9 but sandbox restrictions blocked it. |
| Stale `AppBlockingManager.swift` in wrong path | `LemmeGo/LemmeGo.xcodeproj/AppBlockingManager.swift` | None | Removed. Outdated v1 copy accidentally committed to xcodeproj directory instead of Services/. Superseded by correct version. |

### In Git History (Low Risk — History Not Rewritten)

| Finding | Commit(s) | Risk | Notes |
|---------|-----------|------|-------|
| Apple Developer Team ID `5Y8S56DTEH` | Pre-`82e9a31` commits | **Low** | Blanked in #9 open-source prep (current HEAD has `DEVELOPMENT_TEAM = ""`). Team IDs are semi-public — they appear in App Store metadata, provisioning profiles, and thousands of public repos. Not a credential. History rewrite not warranted. |

### Acceptable / Intentional

| Item | Status |
|------|--------|
| Git author email `jt@justintormey.com` | Intentional — Justin's public portfolio email |
| `justintormey` GitHub username in README/blog post | Intentional — portfolio project, attribution expected |
| GitHub repo URL in blog draft | Intentional — that's where the code lives |
| Bundle ID `com.lemmego.app` | No PII — generic app namespace |

---

## Code Quality Review

### Current HEAD State
- All Swift source files are in correct locations under `LemmeGo/LemmeGo/`
- No external dependencies — pure Apple frameworks only
- MIT License in place
- README is comprehensive and accurate

### Known Technical Debt (Documented in history.md, Pre-Existing)

| Item | Location | Severity |
|------|----------|----------|
| `print()` used for all logging | Throughout Services/ | Low — no security impact, just maintenance debt |
| Raw UserDefaults key strings | LockManager, BlockedAppsStore | Low — no PII risk |
| `LockManager` class is large | LockManager.swift | Low — documented, not a blocker |

### No Issues Found In
- NFC chip ID storage (device-local UserDefaults, no network transmission)
- Screen Time permission flow
- Emergency unlock tracker
- Session persistence
- All test files

---

## Gitignore Coverage (Current)

`.gitignore` now correctly excludes:
- `.claude/` — Claude Code internal files
- `.env` / `.env.*` — Environment variables
- `xcuserdata/` — Xcode user data
- Standard iOS build artifacts

---

## Recommendation

**Repository is ready to be made public.** The two tracked-file issues are now fixed. The Team ID in history is low-risk and not worth the disruption of a history rewrite for a portfolio project.
