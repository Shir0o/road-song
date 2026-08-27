# 09: Choose storage & delivery for media and renders

Type: research
Status: open
Blocked by: 05

## Question

Where should uploaded source media, intermediate assets, and final rendered videos live, and how should they be served?

Research and decide:
- Cloudflare R2 vs S3 vs alternatives for source media and exports.
- Presigned upload URLs for direct-to-storage uploads from the PWA.
- Delivery/CDN for final videos and 15-second previews.
- Cost per event and per export, matching the $0.002 storage/bandwidth estimate.

## Notes

- The brief names Cloudflare R2 for storage & bandwidth.
- Feeds unit economics and uploader implementation.
