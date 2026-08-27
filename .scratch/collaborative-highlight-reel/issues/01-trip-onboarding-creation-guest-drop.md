# 01: Trip Onboarding, Custom Trip Creation & Frictionless Guest Drop

**What to build:**
A complete trip onboarding and entry flow starting with an editorial `WelcomeScreen` (hero polaroid collage and slogan), a `CreateTripScreen` (trip title, date range picker, and scrapbook cover swatch selector), and an `InviteCrewScreen` (friend checklist + tokenized URL & QR code guest drop portal) allowing frictionless photo/video/text drops into the shared trip pool with preserved EXIF timestamps.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] `WelcomeScreen` onboarding with tactile scrapbook polaroid collage and primary CTA.
- [ ] `CreateTripScreen` allowing custom trip name, date range, and cover swatch selection.
- [ ] `InviteCrewScreen` with friend toggle list, copyable tokenized session link (`roadsong.app/t/...`), and QR code preview.
- [ ] Session ingestion service supporting frictionless guest drops for photos, video clips, and text quotes.
- [ ] Unit & widget tests verifying trip creation state and media ingestion metadata parsing ($\ge 90\%$ coverage).
