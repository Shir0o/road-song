# Collaborative Session Ingestion & Guest Drop Architecture

`wayfinder:research`

## Question

How should collaborative trip sessions be modeled and ingested in Firestore/Storage so that friends and family can upload media (photos/videos) and submit text anecdotes (quotes, inside jokes, receipts) via shareable links/QR codes without mandatory user authentication or app installation, while preserving timestamps, location, and upload integrity?

## Scope & Deliverables
1. Data model for `Session`, `Participant`, and `Evidence` (media + text moments).
2. Frictionless guest auth/anonymous session tokens vs. web drop portal.
3. Media upload, thumbnailing, and metadata extraction strategy.
