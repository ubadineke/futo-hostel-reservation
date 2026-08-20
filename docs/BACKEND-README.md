# Roost — Backend Integration Guide

> **Status:** the backend is built and deployed, and the app + admin are wired to
> it. **Live API:** `https://futo-hostel-reservation-backend.onrender.com/api/v1`
> · **Swagger:** `https://futo-hostel-reservation-backend.onrender.com/api/docs`.
> The client side is described in [`INTEGRATION.md`](./INTEGRATION.md); the sections
> below remain the source-of-truth contract for shapes and rules.

**For the backend developer.** This document is derived directly from the Flutter
app's screens and data models (`app/lib/`). It tells you **exactly what data each
screen reads and writes**, the **JSON shapes** the app expects, the **business
rules** the server must enforce, and the **seed data** to reproduce the demo.

Today the app runs entirely off static in-memory demo data
(`app/lib/core/demo/hostel_data.dart`) — there is **no network layer yet**. Your
job is to stand up the API behind these shapes so the app can be wired to a real
backend with minimal client changes. Where the app currently *fakes* something
(payment gateway, bed-occupancy, RRR/reference generation), it's called out
explicitly under **"What the app fakes today."**

> Companion docs: [`REQUIREMENTS.md`](../REQUIREMENTS.md) (FR1–FR13, the source of
> truth for scope) and [`BACKEND-API.md`](./BACKEND-API.md) (the short endpoint
> list this guide expands on).

---

## 1. Conventions

| Thing | Decision |
|---|---|
| **Base URL** | `/api/v1` |
| **Format** | JSON in, JSON out (`Content-Type: application/json`) |
| **Auth** | Bearer JWT in `Authorization: Bearer <token>`. Issued on login/register. |
| **Passwords** | Hashed with **bcrypt**. Never returned. |
| **Money** | **Integer naira** (no decimals, no floats). `42000` means ₦42,000. The app formats display itself (`₦42,000`, `₦42k`). |
| **IDs** | Hostel IDs are short human strings (`"A"`, `"TETFUND"`, `"NDDC"`, `"PG"`). Room/reservation/student/payment IDs are server-generated (UUID or similar). |
| **Timestamps** | ISO-8601 UTC (`2025-09-14T10:30:00Z`). The app renders its own short date (`Sep 14, 2025`); send a real timestamp and let the client format. |
| **Transport** | HTTPS only. Students may read/modify **only their own** data. |
| **Errors** | JSON `{ "error": { "code": "BED_TAKEN", "message": "..." } }` with appropriate HTTP status (see §9). |

### Enum values (must match the app exactly)

```
gender              : "male" | "female" | "mixed" | "postgrad"
hostel/room status  : "available" | "limited" | "full"
reservation status  : "pending" | "reserved" | "paid" | "cancelled"
payment status      : "pending" | "paid" | "failed"
funder (free-ish)   : "School" | "TETFund" | "NDDC" | "Postgraduate"
```

---

## 2. Core data models

These mirror the Dart classes in `app/lib/core/demo/hostel_data.dart` and
`status_pill.dart`. Field names are what the app uses — keep them identical so the
JSON maps straight onto the models.

### Student
The signed-in student. Shown on **Profile** and used to personalise the app.

```jsonc
{
  "id": "stu_01H...",                  // server-generated
  "name": "Chidi Okeke",
  "regNo": "20211234567",              // 11 digits
  "email": "okeke.chidi.20211234567@futo.edu.ng",
  "dept": "Software Engineering",
  "level": "400 Level"
}
```

### Hostel
A hostel block. **Note:** a hostel's `rooms` are room **types/categories**, not
individual physical rooms (see §6).

```jsonc
{
  "id": "A",
  "name": "Hostel A",
  "code": "A",                         // short badge, e.g. "TF", "ND", "PG"
  "funder": "School",
  "gender": "male",
  "price": 42000,                      // ₦ per session (integer naira)
  "roomSize": "8–10 per room",         // display string
  "blurb": "A male school block close to the lecture halls. …",
  "lat": 5.3869,                       // for "View on map" (Google Maps)
  "lng": 7.0341,
  "coverA": 4280171146,                // cover gradient start, 32-bit ARGB int (0xFF1E3A8A)
  "coverB": 4280640491,                // cover gradient end,   32-bit ARGB int (0xFF2563EB)
  "rooms": [ /* Room[] */ ],

  // ---- server-computed, returned for convenience (see §6 thresholds) ----
  "bedsAvailable": 12,                 // = sum(rooms[].bedsAvailable)
  "bedsTotal": 88,                     // = sum(rooms[].bedsTotal)
  "status": "available"                // derived from bedsAvailable
}
```

> `coverA`/`coverB` are ARGB integers because the app does `Color(coverA)`. You may
> send them as decimal ints (above) or hex strings (`"0xFF1E3A8A"`) — agree on one;
> decimal int is simplest. These are pure presentation; they never change.

### Room (room **type** within a hostel)

```jsonc
{
  "id": "A-r1",                        // server-generated, stable
  "hostelId": "A",
  "name": "8-bed room",
  "capacity": 8,                       // beds per physical room of this type
  "bedsAvailable": 9,                  // free beds in this category right now
  "bedsTotal": 48,                     // total beds in this category
  "occupiedBeds": [1, 2, 5]            // NEEDED by the reserve screen — see §6
}
```

### Reservation
A booking. Drives **Bookings** and the **receipt**.

```jsonc
{
  "id": "res_01H...",
  "reference": "RST-7F3A21",           // human receipt code (server-generated, unique)
  "rrr": "270054118832",              // 12-digit Remita Retrieval Reference
  "studentId": "stu_01H...",
  "hostelId": "NDDC",
  "roomId": "NDDC-r1",
  "roomName": "4-bed room",            // denormalised for display
  "bed": 2,                            // bed number within the room (1..capacity)
  "fee": 62500,                        // ₦ paid (integer naira) = hostel.price
  "status": "paid",
  "createdAt": "2025-09-14T10:30:00Z"
}
```

### Payment (Remita)

```jsonc
{
  "rrr": "270054118832",
  "reservationId": "res_01H...",
  "amount": 62500,
  "status": "pending"                  // -> "paid" | "failed"
}
```

---

## 3. Screen-by-screen flow → what the backend serves

This is the heart of the doc: every screen, the data it consumes, and the
endpoint(s) behind it.

### 3.1 Onboarding / Login — `app/lib/features/onboarding/onboarding_page.dart`
The first screen (route `/`). Three actions:

1. **Sign in** — identifier + password.
   - `identifier` = reg-number `^\d{11}$` **or** school email
     `^[a-z]+\.[a-z]+\.\d{11}@futo\.edu\.ng$` (case-insensitive).
   - `password` = ≥ 8 chars, at least **one letter and one digit**.
   - → `POST /auth/login` → `{ token, student }`. App stores the token, navigates to home.
2. **Create account** — full name, 11-digit registration number, matching FUTO school
   email, department, level, password, and confirm password. Every field is required.
   - → `POST /auth/register` → `{ token, student }`.
3. **Face ID / fingerprint** — **device-side only.** Biometric unlocks the locally
   stored token; the app then calls `GET /auth/me` to restore the session. **No
   biometric endpoint exists or is needed.**

> The app validates the regexes client-side too, but the server **must** re-validate
> and own uniqueness/credential checks. (FR1, FR2, FR3, §7 of REQUIREMENTS.)

### 3.2 Browse — `app/lib/features/browse/browse_page.dart`  (tab 0)
Lists all hostels as cards (cover gradient, name, gender, price, availability pill).

- **Reads:** `GET /hostels` → `Hostel[]`.
- **Search box** matches against **hostel name OR funder** (`q`).
- **Filter chips:** `All`, `Male`, `Female`, `Mixed`, `Available` (= status ≠ `full`).
- Supports server-side filtering via query params, or fetch-all + filter client-side
  (the demo set is tiny). Recommended: `GET /hostels?q=&gender=&available=`.
- Tap a card → hostel detail (`/hostel/:id`).

### 3.3 Hostel detail — `app/lib/features/hostel_detail/hostel_detail_page.dart`
Route `/hostel/:id`. Shows cover, name, `gender · roomSize`, `priceFull`, blurb,
a **"View on map"** button (opens `https://www.google.com/maps/search/?api=1&query=<lat>,<lng>`),
an **availability hero** (`bedsAvailable of bedsTotal`, progress = available/total),
and the **rooms** list (per-room name, `capacity per room · bedsAvailable beds open`,
status pill).

- **Reads:** `GET /hostels/:id` → one `Hostel` incl. `rooms[]` and `blurb`.
- **Bottom CTA logic (important):**
  - If hostel `status == "full"` → **"Fully booked"** (disabled).
  - Else if the student **already has an active reservation** → **"View my booking"**
    (jumps to Bookings tab). "Active" = a reservation with status `paid` **or**
    `reserved`/`pending` (a held bed). This enforces **one active reservation**
    (FR7). The app reads this from local state today; the server is the real source
    of truth — see §4.
  - Else → **"Reserve a bed"** → `/hostel/:id/reserve`.

### 3.4 Reserve + Pay — `app/lib/features/reserve/reserve_page.dart`
Route `/hostel/:id/reserve`. Two steps then payment:

1. **Choose a room** (room types with `bedsAvailable == 0` are disabled).
2. **Pick a bed** — a grid of `capacity` beds for the chosen room; some are shown
   **taken**. **The app currently fakes which beds are taken** with a local
   heuristic. The server must supply real occupancy — return `occupiedBeds` per room
   (see §6) so the grid is accurate.
3. **Fee summary** — hostel, room, bed, **Total = hostel.price** (fee is the hostel
   session fee; it is **not** room-specific today).
4. **Pay** — currently a 1.6s mock "Remita gateway" delay, then a local
   `reserve()`. Replace with the real flow:
   - `POST /reservations` `{ hostelId, roomId, bed }` → server holds the bed
     (status `pending`/`reserved`), returns `{ reservation, payment: { rrr, amount } }`.
   - `POST /payments/initiate` `{ reservationId }` (or fold into the step above) →
     `{ rrr, amount, status: "pending" }`.
   - App shows the gateway / polls `GET /payments/:rrr/status` until `paid`.
   - On `paid` (confirmed by the Remita **webhook**), the reservation flips to
     `paid` and the **receipt sheet** is shown.
- **Receipt fields shown:** hostel name, room name, `Bed N`, **reference**, **Remita
  RRR**, **amount paid** — all from the returned `Reservation`. After "Done" the app
  goes to the Bookings tab.

### 3.5 Bookings / Reservations — `app/lib/features/reservations/reservations_page.dart`  (tab 1)
The student's reservations + history, newest first.

- **Reads:** `GET /reservations` → `Reservation[]` (this student only, newest first).
- **Header stats:** `Active` = count of `paid` reservations; `Paid this session` =
  sum of `fee` over `paid` reservations.
- **Tap a booking** → detail sheet: room, `Bed N`, reference, RRR, amount, date,
  status pill.
  - If `paid` → **"Cancel reservation"** → `POST /reservations/:id/cancel` (frees the
    bed, status → `cancelled`).
  - Else → **"Close"**.
- Empty state offers "Browse hostels".

### 3.6 Profile — `app/lib/features/profile/profile_page.dart`  (tab 2)
- **Identity card:** `name`, `regNo`, `dept`, `level`, `email` (from `GET /auth/me`).
- **"Your stay":** the first **`paid`** reservation → hostel name, room, `Bed N`,
  `PAID` pill; otherwise an empty-state prompt.
- **Settings sheet:** appearance (light/dark) toggle is **device-side only** (no
  backend); **Sign out** → `POST /auth/logout` (optional) and returns to login.
- **Menu items** (Help & support, About Roost, Terms & privacy) are static — no
  backend needed (serve static URLs/markdown if you want them live).

---

## 4. Business rules the server must enforce

These come straight from the app's behaviour + REQUIREMENTS §5/§9.

1. **One active reservation per student** (FR7). "Active" = status `pending`,
   `reserved`, or `paid`. Block a second reserve while one is active — the detail
   screen already switches its CTA to "View my booking" based on this. Return
   `409 ALREADY_HAS_ACTIVE` if a client attempts it anyway.
2. **Availability decrements immediately on reserve** and is restored on
   **cancel** or **payment expiry/timeout**. The app re-reads availability after a
   booking and expects the counts to reflect the held bed.
3. **Confirm allocation only after payment is verified** (FR8/FR9). A bed is *held*
   on reserve (`pending`/`reserved`) and *allocated* (`paid`) only when Remita
   confirms via webhook.
4. **First-come-first-serve**, with **priority for 100-level and final-year**
   students (REQUIREMENTS §2). Encode priority in the allocation logic.
5. **Own-data-only:** a student can read/modify only their own reservations; reject
   others with `403`.
6. **Status thresholds** (so server-sent `status` matches what the app computes):
   - **Hostel-level:** `full` if `bedsAvailable == 0`; `limited` if `1 ≤ bedsAvailable ≤ 6`; else `available`.
   - **Room-level (detail & reserve):** `full` if `0`; `limited` if `≤ 4`; else `available`.
   You can send `status` or let the client derive it from counts — but if you send
   it, use these thresholds.

---

## 5. Endpoint reference

All under `/api/v1`. `Auth` column: — = public, `student` = student JWT, `admin` =
admin JWT.

### Auth
| Method | Path | Body → Response | Auth |
|---|---|---|---|
| `POST` | `/auth/register` | `{ name, regNo, email, dept, level, password }` → `{ token, student }` | — |
| `POST` | `/auth/login` | `{ identifier, password }` → `{ token, student }` | — |
| `GET`  | `/auth/me` | → `{ student }` (restores session after biometric unlock) | student |
| `PATCH` | `/auth/me` | `{ name?, email?, dept?, level? }` → updated student | student |
| `POST` | `/auth/logout` | → `204` (optional token invalidation) | student |

### Hostels
| Method | Path | Notes | Auth |
|---|---|---|---|
| `GET` | `/hostels` | `Hostel[]`. Optional `?q=&gender=&available=true`. `q` matches name **or** funder. | student |
| `GET` | `/hostels/:id` | One `Hostel` with `rooms[]` (incl. `occupiedBeds`) + `blurb`. | student |

### Reservations
| Method | Path | Notes | Auth |
|---|---|---|---|
| `POST` | `/reservations` | `{ hostelId, roomId, bed }` → `{ reservation, payment:{ rrr, amount } }`. Enforces §4. | student |
| `GET` | `/reservations` | This student's reservations, newest first. | student |
| `GET` | `/reservations/:id` | One reservation (allocation + receipt fields). | student |
| `POST` | `/reservations/:id/cancel` | Cancel before deadline; frees the bed → `cancelled`. | student |

### Payments (Remita)
| Method | Path | Notes | Auth |
|---|---|---|---|
| `POST` | `/payments/initiate` | `{ reservationId }` → `{ rrr, amount, status:"pending" }`. | student |
| `GET`  | `/payments/:rrr/status` | → `{ status: "pending"|"paid"|"failed" }`. App polls this. | student |
| `POST` | `/payments/webhook/remita` | Remita → server callback. On success: reservation → `paid`, allocate bed, issue e-receipt. Verify HMAC signature. | Remita |

### Admin (web dashboard — `admin/`, FR11–FR13)
| Method | Path | Notes | Auth |
|---|---|---|---|
| `POST` | `/auth/admin/login` | → `{ token, admin }`. | — |
| `GET` | `/admin/stats/occupancy` | `{ totalBeds, occupied, available, occupancyPct, revenue, perHostel:[{ id, name, occupied, total }] }`. | admin |
| `GET` | `/admin/reservations` | All reservations, `?status=`. | admin |
| `POST` | `/admin/reservations/:id/allocate` | `{ roomId, bed }` — manual allocate/reassign (FR12). | admin |
| `GET/POST/PATCH/DELETE` | `/admin/hostels[/:id]` | CRUD hostels (name, gender, funder, price, capacity, status). | admin |
| `GET/POST/PATCH/DELETE` | `/admin/rooms[/:id]` | CRUD room types within a hostel. | admin |

### Example: reserve → pay → confirm

```http
POST /api/v1/reservations
Authorization: Bearer <student-jwt>

{ "hostelId": "TETFUND", "roomId": "TETFUND-r1", "bed": 3 }
```
```jsonc
// 201 Created — bed held, awaiting payment
{
  "reservation": {
    "id": "res_01HZ...", "reference": "RST-9C12A4", "rrr": "350078221904",
    "studentId": "stu_01H...", "hostelId": "TETFUND", "roomId": "TETFUND-r1",
    "roomName": "4-bed room (en-suite)", "bed": 3, "fee": 90000,
    "status": "pending", "createdAt": "2026-06-26T09:12:00Z"
  },
  "payment": { "rrr": "350078221904", "amount": 90000, "status": "pending" }
}
```
```http
GET /api/v1/payments/350078221904/status     → { "status": "paid" }
```
After the Remita webhook marks it paid, `GET /reservations/:id` returns the same
object with `"status": "paid"` — that's the receipt the app shows.

---

## 6. The room-type vs. physical-bed model (read this)

The app's `rooms` are **categories**, not individual rooms:

- `capacity` = beds **per physical room** of that type (e.g. an "8-bed room").
- `bedsTotal` = total beds of that type across the whole hostel (e.g. 48 = six
  8-bed rooms).
- `bedsAvailable` = free beds of that type right now.

The **reserve screen** renders a single room's worth of beds (`1..capacity`) and
needs to know **which bed numbers are taken**. The app currently invents this with
a heuristic (`_openBeds`/`_isTaken` in `reserve_page.dart`). **You must replace it**
with real data:

- Return `occupiedBeds: number[]` (or `availableBeds`) per room in `GET /hostels/:id`.
- On `POST /reservations`, the server should authoritatively **assign the concrete
  room + bed** (FCFS + priority) and return the final `roomName` + `bed`; treat the
  client-sent `bed` as a preference, not a guarantee. If the requested bed was taken
  in the meantime, either assign the next free bed or return `409 BED_TAKEN`.

If you later want differential pricing per room type, add `price` to `Room`; today
`fee == hostel.price`.

---

## 7. What the app fakes today (must become real server-side)

| Faked in app | File | Real behaviour |
|---|---|---|
| Login always succeeds (regex-only) | `onboarding_page.dart` | Verify credentials, issue JWT, own uniqueness. |
| `hasActive` from local list | `hostel_data.dart` | Server is source of truth for the one-active rule. |
| Which beds are "taken" | `reserve_page.dart` | Return real `occupiedBeds` per room (§6). |
| 1.6s `Future.delayed` "Remita gateway" | `reserve_page.dart` | Real Remita initiate + webhook + status poll. |
| `RST-…` reference from epoch hex | `hostel_data.dart` | Server-generated unique reference. |
| 12-digit RRR from epoch | `hostel_data.dart` | Real Remita RRR from the gateway. |
| Availability decrement in memory | `hostel_data.dart` | Persisted decrement/restore in DB. |
| Short date string (`Sep 14, 2025`) | `hostel_data.dart` | Send ISO-8601 `createdAt`; client formats. |
| Appearance toggle, menu items | `profile_page.dart` | Device-side / static — no backend. |

---

## 8. Seed data (reproduce the demo exactly)

Eight hostels (REQUIREMENTS §4). Values below are taken verbatim from
`app/lib/core/demo/hostel_data.dart` so a freshly seeded DB matches the current app.
Cover colours are shown as the source hex (store as the ARGB int).

| id | name | code | funder | gender | price | roomSize | lat | lng | coverA / coverB |
|---|---|---|---|---|---|---|---|---|---|
| A | Hostel A | A | School | male | 100 | 8–10 per room | 5.3869 | 7.0341 | 0xFF1E3A8A / 0xFF2563EB |
| B | Hostel B | B | School | male | 42000 | 8–10 per room | 5.3872 | 7.0347 | 0xFF312E81 / 0xFF4F46E5 |
| C | Hostel C | C | School | female | 45000 | 6–8 per room | 5.3858 | 7.0359 | 0xFF0F766E / 0xFF0EA5A4 |
| D | Hostel D | D | School | female | 45000 | 6–8 per room | 5.3855 | 7.0364 | 0xFF155E75 / 0xFF0891B2 |
| E | Hostel E | E | School | male | 42000 | 8–10 per room | 5.3877 | 7.0338 | 0xFF1E293B / 0xFF334155 |
| TETFUND | TETFund Hostel | TF | TETFund | mixed | 90000 | 4 per room (en-suite) | 5.3851 | 7.0366 | 0xFF1D4ED8 / 0xFF3B82F6 |
| NDDC | NDDC Hostel | ND | NDDC | mixed | 62500 | 3–4 per room | 5.3848 | 7.0371 | 0xFF134E4A / 0xFF0D9488 |
| PG | PG Hostel | PG | Postgraduate | postgrad | 75000 | 1–2 per room | 5.3845 | 7.0331 | 0xFF4C1D95 / 0xFF6D28D9 |

Room types per hostel — `name (capacity, bedsAvailable / bedsTotal)`:

| Hostel | Room types |
|---|---|
| A | 8-bed room (8, 9/48) · 10-bed room (10, 3/40) |
| B | 8-bed room (8, 0/48) · 10-bed room (10, 5/50) |
| C | 6-bed room (6, 7/36) · 8-bed room (8, 6/48) |
| D | 6-bed room (6, 2/36) · 8-bed room (8, 0/32) |
| E | 8-bed room (8, 0/64) |
| TETFUND | 4-bed room (en-suite) (4, 8/80) |
| NDDC | 4-bed room (4, 6/64) · 3-bed room (3, 4/36) |
| PG | 2-bed room (2, 5/40) · 1-bed studio (1, 2/12) |

**Demo student** (Profile): `Chidi Okeke` · regNo `20211234567` ·
`okeke.chidi.20211234567@futo.edu.ng` · Software Engineering · 400 Level.

**One seeded past booking** (so history isn't empty): reference `RST-7F3A21`,
rrr `270054118832`, hostel `NDDC`, room `4-bed room`, bed `2`, fee `62500`,
status `cancelled`, date `Sep 14, 2025`.

---

## 9. Validation & status codes

```
Registration number : ^\d{11}$
School email        : ^[a-z]+\.[a-z]+\.\d{11}@futo\.edu\.ng$   (case-insensitive; embedded reg-no must match)
Password   : length ≥ 8 AND contains ≥1 letter AND ≥1 digit
Confirm    : (register only) must equal password
```

| Code | When |
|---|---|
| `200 / 201` | OK / created |
| `204` | logout, no body |
| `400 / 422` | malformed body / failed validation (bad identifier or password) |
| `401` | missing/invalid/expired token, or wrong credentials |
| `403` | accessing another student's data |
| `404` | hostel/room/reservation not found |
| `409` | conflict: `ALREADY_HAS_ACTIVE`, `BED_TAKEN`, `HOSTEL_FULL` |

Error body:
```json
{ "error": { "code": "BED_TAKEN", "message": "Bed 3 in 4-bed room (en-suite) is no longer available." } }
```

---

## 10. Security & non-functional (REQUIREMENTS §6)

- Passwords hashed with **bcrypt**; never stored or returned in plaintext.
- **Biometric** Face ID/fingerprint is **entirely on-device** — it gates access to
  the locally stored JWT. The server only ever sees the token.
- **HTTPS** everywhere; students see only their own data (enforce on every
  student-scoped route).
- Light theme is the app default; appearance is a device setting, not a profile
  field.
- The demo data set is tiny — no scaling/SLA requirements (explicitly cut in
  REQUIREMENTS §8). Correctness of the reserve → pay → allocate flow is what matters.

---

### TL;DR for the backend dev
Build `/api/v1` with **JWT auth**, serve the **8 seed hostels** with their **room
types and real bed occupancy**, and implement the **reserve → Remita pay → webhook
→ allocate** flow with **one active reservation per student** and
**availability that decrements on hold / restores on cancel**. Match the JSON field
names and enums in §2 and the app wires up with no model changes.
