# Reels "Flash Speed" – What You Should Do

The app now **preloads the first reel** as soon as the list loads and uses a **fast path** when that reel is already prepared, so the first play can start with minimal delay. Swiping to the next reel already uses the **preloaded** player when available.

To get the full Instagram-like feel (instant start, minimal delay), do the following.

---

## 1. Serve media from Firebase Storage (fast URLs)

- In [Firebase Console](https://console.firebase.google.com) → your project → **Storage**:
  - Create folders: `reels/audio/`, `reels/images/`.
- Upload your reel files:
  - **Audio:** one file per reel (e.g. `reel1.m4a`, `reel2.m4a`) into `reels/audio/`.
  - **Images:** one image per reel into `reels/images/`.
- Set **Storage rules** so these files are readable (e.g. allow read for authenticated users or for all).
- Get **download URLs** for each file (Storage UI: click file → "Get download URL"), or generate them in your backend/script with the Firebase Admin SDK.
- Update your **database**: set each reel’s `audio_url` and `image_url` to these Firebase Storage URLs (replace the current placeholder URLs). You can do this by:
  - Running SQL updates, or
  - Adding a small script that uploads to Storage and then updates the `reels` table with the returned URLs.

**Result:** Audio and images are served from Firebase’s edge network (CDN-like), which reduces latency.

---

## 2. Use an audio format that starts quickly

- Prefer **AAC in MP4 (.m4a)** with **fast start** so playback can begin as soon as the first chunk is received.
- Encode with ffmpeg:
  ```bash
  ffmpeg -i input.wav -c:a aac -movflags +faststart -b:a 128k output.m4a
  ```
- If you keep **MP3**, encode with metadata at the **beginning** (fast start) so streaming still starts quickly.

**Result:** Less buffering time before playback starts.

---

## 3. (Optional) Preload on scroll start

- If you want to squeeze more out of fast swipes, you can start preloading the **next** reel when the user **starts** dragging (e.g. via `PageController` or scroll notifications). The app already preloads the next reel when a reel becomes current; this would add preload a bit earlier.

---

## Summary

| Step | What you do | Why |
|------|-------------|-----|
| 1 | Upload reels to Firebase Storage, set Storage rules, put URLs in DB | Fast, CDN-like delivery |
| 2 | Use .m4a (AAC, fast start) or fast-start MP3 | Audio can start with minimal buffer |
| 3 | (Optional) Preload on drag start | Slightly faster feel when swiping |

The code already does: **prepare first reel on list load**, **preload next reel**, and **fast path when first reel is prepared**. Steps 1 and 2 above are what **you** do (content + URLs + format) to make that feel like “flash” speed.
