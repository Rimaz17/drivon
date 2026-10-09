# 11. Vehicle documents on Cloudflare R2

- Status: Accepted
- Date: 2026-10-10

## Context

Phase 4 stores insurance, revenue licence, registration, invoices and receipts with a type, issue date, expiry date, file and notes. Files must stay private, the app must never hold storage credentials, and everything has to fit Cloudflare R2's free tier (10 GB, 1 million writes and 10 million reads a month). Render's free instance has 512 MB of memory and sleeps when idle, so streaming files through the API would be slow and memory-hungry.

## Decision

- **Files never pass through the API.** The app uploads and downloads directly from R2 with short-lived presigned URLs signed by the backend with the AWS SDK v2 S3 client (endpoint `https://<account>.r2.cloudflarestorage.com`, region `auto`, path-style URLs). The bucket is private and is never listed; object keys live in Postgres.
- **Two-step upload:**
  1. `POST /vehicles/{id}/documents` with the details plus `contentType` and `sizeBytes` saves a `PENDING` row and returns a presigned `PUT` (10 minutes). Content type and length are part of the signature, so R2 rejects a different file.
  2. The app sends the file to R2, then calls `POST …/documents/{documentId}/confirm`. The API `HEAD`s the object and checks size and type before marking the row `ACTIVE`. A missing object is `422 UPLOAD_NOT_FOUND`; a mismatched one is deleted and answered with `422 UPLOAD_MISMATCH`.
  - The app generates the document ID, so a retry of step 1 resumes the same document with a fresh URL, or returns it without an upload once confirmed.
- **Limits:** JPEG, PNG or PDF (`422 UNSUPPORTED_FILE_TYPE`, with `allowedContentTypes`), at most 5 MB (`422 FILE_TOO_LARGE`, with `maxBytes`), and at most 100 documents per vehicle (`422 DOCUMENT_LIMIT_REACHED`). The app compresses photos to JPEG before uploading. Database `CHECK` constraints repeat the type and size rules.
- **Object keys** are `users/{userId}/vehicles/{vehicleId}/documents/{documentId}.{ext}`. Original file names are never stored; downloads get a readable name such as `insurance-2026-03-01.pdf` through `response-content-disposition`.
- **Details:** `type` (`INSURANCE`, `REVENUE_LICENCE`, `REGISTRATION`, `INVOICE`, `RECEIPT`, plus `OTHER` for papers such as an emission test certificate), optional `issueDate` and `expiryDate` (expiry after issue, `422 DOCUMENT_DATES_INVALID`), and `notes`. Details can be edited; the file can't be replaced (delete the document and add it again).
- **Downloads:** `GET …/documents/{documentId}/download-url` returns a presigned `GET` that is valid for 5 minutes.
- **Expiring documents:** `GET /documents/expiring?withinDays=30` lists the user's active documents expiring within that many days of today in Sri Lanka, including ones already expired, soonest first. Phase 6 reminders and the Phase 7 assistant build on it.
- **Deleting:** storage can't join a database transaction, so files are deleted after the commit (`TransactionSynchronization.afterCommit`). A failed delete is logged and leaves an orphaned object; it never fails the request. Deleting a vehicle publishes `VehicleDeletingEvent` inside the transaction; the documents feature collects that vehicle's keys and deletes the files after the cascade commits. Uploads left `PENDING` for a day are removed the next time someone starts an upload for that vehicle.
- **Configuration:** `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` and `R2_BUCKET`. They are required in `prod`. Elsewhere they are optional: without them, document endpoints answer `503 STORAGE_UNAVAILABLE` and the rest of the API works. The R2 token is limited to *Object Read & Write* on one bucket.
- **Tests** run against [Adobe S3Mock](https://github.com/adobe/S3Mock) (Apache 2.0) in Testcontainers. MinIO was the first choice, but it no longer publishes community images. S3Mock doesn't verify signatures, so the API's own `HEAD` check is what the mismatch test covers; a unit test checks that the presigned `PUT` signs `content-type` and `content-length` and carries no checksum parameters.

## Consequences

- The API's memory and bandwidth don't depend on file sizes, and a sleeping server doesn't slow down downloads once the URL is issued.
- The app makes three calls per upload (start, `PUT`, confirm). An upload that is never confirmed stays invisible and is cleaned up later.
- Orphaned objects are possible after a storage outage during a delete. They are logged with their key and can be removed by hand. With the limits above, worst-case storage per user is 1 GB.
