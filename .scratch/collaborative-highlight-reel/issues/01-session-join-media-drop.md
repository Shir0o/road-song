# 01: Collaborative Session Creation & Frictionless Media Drop

**What to build:** 
A trip host can create a shared trip session, generate a shareable session invite code/QR code, and co-travelers/guests can immediately contribute photos, video snippets, and text quotes/inside jokes into the shared session pool without mandatory account login. Contributed media extracts and preserves EXIF timestamps and metadata.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] Data models for `Session`, `Participant`, and `EvidenceItem` (media and text types).
- [ ] Session creation flow generating unique session codes / join links.
- [ ] Media & quote ingestion interface allowing frictionless guest asset drops.
- [ ] Metadata extraction (timestamps, location, captions) for uploaded assets.
- [ ] Test coverage $\ge 90\%$ for session management and ingestion services.
