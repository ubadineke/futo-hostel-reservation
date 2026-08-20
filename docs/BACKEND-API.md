# Roost — Backend API (routes the app needs)

A short, framework-agnostic list of REST endpoints the mobile app + admin expect.
JSON in/out. Auth via a bearer token (JWT). Passwords hashed with **bcrypt**.
Money in **kobo or naira integers** (no floats). Payments via **Remita (RRR)**.

Base URL: `/api/v1`  ·  **Live:** `https://futo-hostel-reservation-backend.onrender.com/api/v1`  ·  **Docs:** `https://futo-hostel-reservation-backend.onrender.com/api/docs`

---

## Auth
| Method | Path | Purpose | Auth |
|---|---|---|---|
| `POST` | `/auth/register` | Create a student. Body: `{ name, regNo, email, dept, level, password }`; every field is required and the FUTO email's reg-no must match `regNo`. Returns `{ token, student }`. | — |
| `POST` | `/auth/login` | Body: `{ identifier, password }` → `{ token, student }`. | — |
| `GET`  | `/auth/me` | Current student profile. Used to restore session after biometric unlock. | student |
| `PATCH` | `/auth/me` | Update the current student's `name`, `email`, `dept`, or `level`. | student |
| `POST` | `/auth/logout` | Invalidate token (optional). | student |

> Biometric (Face ID/fingerprint) is **device-side only** — it unlocks the locally
> stored token, then the app calls `GET /auth/me`. No special biometric endpoint needed.

## Hostels
| Method | Path | Purpose | Auth |
|---|---|---|---|
| `GET` | `/hostels` | List all hostels: `{ id, name, code, funder, gender, price, roomSize, bedsAvailable, bedsTotal, status, lat, lng, coverA, coverB }`. Supports `?gender=&status=&q=` for filter/search. | student |
| `GET` | `/hostels/:id` | One hostel + `rooms: [{ id, name, capacity, bedsAvailable, bedsTotal }]` + `blurb`. | student |

## Reservations
| Method | Path | Purpose | Auth |
|---|---|---|---|
| `POST` | `/reservations` | Reserve a bed. Body: `{ hostelId, roomId, bed }`. Server checks availability, enforces **one active reservation per student**, holds the bed, returns `{ reservation, payment: { rrr, amount } }`. | student |
| `GET` | `/reservations` | The student's reservations (history), newest first. | student |
| `GET` | `/reservations/:id` | One reservation incl. allocation (hostel/room/bed) + receipt fields. | student |
| `POST` | `/reservations/:id/cancel` | Cancel before the deadline; frees the bed. | student |

## Payments (Remita)
| Method | Path | Purpose | Auth |
|---|---|---|---|
| `POST` | `/payments/initiate` | Body: `{ reservationId }` → generate a Remita invoice, return `{ rrr, amount, status:"pending" }`. | student |
| `GET`  | `/payments/:rrr/status` | Poll payment status (`pending`/`paid`/`failed`). App calls this after the user pays. | student |
| `POST` | `/payments/webhook/remita` | **Remita → server** callback. On success: mark reservation `paid`, confirm the bed allocation, generate the e-receipt. | Remita (HMAC) |

## Admin (web dashboard)
| Method | Path | Purpose | Auth |
|---|---|---|---|
| `POST` | `/auth/admin/login` | Admin login → `{ token, admin }`. | — |
| `GET` | `/admin/stats/occupancy` | Dashboard totals: `{ totalBeds, occupied, available, occupancyPct, revenue, perHostel:[{ id, name, occupied, total }] }`. | admin |
| `GET` | `/admin/reservations` | All reservations, `?status=` filter. | admin |
| `POST` | `/admin/reservations/:id/allocate` | Manual allocate / reassign. Body: `{ roomId, bed }`. (FR12) | admin |
| `GET` `POST` `PATCH` `DELETE` | `/admin/hostels[/:id]` | CRUD hostels (name, gender, funder, price, capacity, status). | admin |
| `GET` `POST` `PATCH` `DELETE` | `/admin/rooms[/:id]` | CRUD rooms within a hostel. | admin |

---

### Core data shapes
```jsonc
Student     { id, regNo, email, name, dept, level }
Hostel      { id, name, code, funder, gender:"male|female|mixed|postgrad",
              price, roomSize, lat, lng, coverA, coverB, rooms:[Room] }
Room        { id, hostelId, name, capacity, bedsAvailable, bedsTotal }
Reservation { id, reference, rrr, studentId, hostelId, roomId, bed,
              fee, status:"pending|paid|cancelled", createdAt }
```

### Rules the server enforces
- One **active** (paid/pending) reservation per student at a time (FR7).
- Decrement `bedsAvailable` when a bed is held; restore it on cancel/expiry.
- Bed allocation is **first-come-first-serve**; prioritise 100-level & final-year.
- Confirm allocation only **after** payment is verified (FR8/FR9).
- Role-based access: students can only read/modify their own reservations.
