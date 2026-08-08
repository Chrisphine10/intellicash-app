# Release Notes

Newest first.

---

## 2.2.0 (build 10) — 8 August 2026

`app-release.aab` · 47.5 MB · signed · commits `2ef3925`, `ebe7ff1`

**Store copy**

> Fixed a problem where the Payment Providers screen opened blank. It now shows
> M-Pesa (Daraja) and Paystack for your group: whether each one collects into
> your group's own account or into the platform account, and what is still
> missing before a setup is finished.

**Changed**

- Payment Providers opened blank. A button in a `Row` inherited the theme's
  infinite minimum width, nothing clamped it, and layout aborted — silently,
  taking the screen with it. Buttons are now width-bounded; the trap is
  documented in the theme.
- M-Pesa environment field showed its raw key instead of a label.

**Affects** anyone on 2.1.0 (build 9), which shipped the blank screen. Group
accounts and admins reach this screen; members never do. No migration, no
server change, no re-authentication.

**Verified** full flow on emulator from a clean install against production.
Bundle checked for the new code; `versionCode` read back as `10`. The AAB
itself was not installed and run — only a debug build of the same commit.

**Rollback** halt the staged rollout. Nothing to undo server-side; build 9
restores the bug, so prefer rolling forward.
