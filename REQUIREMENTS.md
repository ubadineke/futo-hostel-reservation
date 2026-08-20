# FUTO Hostel Reservation — Requirements (Lean)

**Course:** SOE‑510 Mobile App Development · **Group 2**

> This replaces the earlier 40‑point "the system shall…" draft. Per the brief,
> requirements are kept **lean** — only what the real FUTO hostel process needs.
> What we deliberately cut, and why, is in §8.

---

## 1. What we're building

A **mobile‑first hostel reservation app** for FUTO students, plus a small
**web admin** for the Hostel / Student Affairs office. It takes the hostel
process students already do on the FUTO portal and turns it into a clean,
one‑hand phone task: **sign in → browse → reserve a bed → pay → get your
allocation.**

## 2. Grounded in the real FUTO process

Today a student does this on `portal.futo.edu.ng`:

1. Log in → **Hostel Allocation** → *Get Hostel*.
2. Choose hostel type (the portal offers **NDDC** vs **Other Hostels**).
3. Generate a **Remita invoice (RRR)** → pay at **FUTO Microfinance Bank** (or online).
4. Print the **e‑receipt + allocation slip** → clear at **Student Affairs**.

Rules that are real and that we honour:
- Bed space is **first‑come‑first‑serve** (limited beds).
- **100‑level and final‑year** students get **priority**.
- Hostel is **optional**, advised for freshers.

Our app keeps this spine but makes selecting, paying, and getting your bed
happen on the phone.

## 3. Actors

| Actor | Where | Can do |
|---|---|---|
| **Student** | Mobile app | Sign in, browse hostels, reserve a bed, pay, see allocation & history |
| **Admin** (Student Affairs / Hostel Officer) | Web | Manage hostels & rooms, view reservations & payments, allocate beds, see occupancy |

## 4. The hostels (demo data)

Confirmed real at FUTO: **Hostels A–E**, **PG Hostel**, **NDDC**, **TETFund**.
Per‑hostel gender / room size / fee below are **campus‑known or representative
values for the demo** — FUTO does not publish an authoritative per‑block table,
and the few published fees conflict (see §9).

| Hostel | Gender | Room size | ~Fee / session |
|---|---|---|---|
| A | Male | 8–10 / room | ₦100 |
| B | Male | 8–10 / room | ₦42,000 |
| C | Female | 6–8 / room | ₦45,000 |
| D | Female | 6–8 / room | ₦45,000 |
| E | Male | 8–10 / room | ₦42,000 |
| TETFund | Mixed (floor‑segregated) | 4 / room | ₦90,000 |
| NDDC | Mixed (floor‑segregated) | 3–4 / room | ₦62,500 |
| PG Hostel | Postgraduate | 2 / room | ₦75,000 |

## 5. Functional requirements (core)

**Authentication**
- **FR1** — Sign in with **registration number** (e.g. `20211234567`) *or* **school
  email** (`name.surname.regno@futo.edu.ng`) and a **password**.
- **FR2** — Sign up with the same identifier + password; password is **≥ 8 characters
  with at least one letter and one number** (simple, not harsh), confirmed via a
  **confirm‑password** field.
- **FR3** — After first login, allow **biometric unlock** (Face ID / fingerprint).

**Browse & reserve**
- **FR4** — Browse all hostels with a visual cover, **gender, price, and availability**.
- **FR5** — **Filter** by gender / price / availability and **search** by name.
- **FR6** — Open a hostel to see **details, room types, beds available, and location**.
- **FR7** — **Reserve** an available bed. **One active reservation per student**;
  availability decreases immediately on reserve.

**Pay & allocate**
- **FR8** — **Pay** the hostel fee in‑app (sandbox/mock gateway, Remita‑style RRR reference).
- **FR9** — On payment, issue a **reservation reference + e‑receipt + allocation**
  (hostel / room / bed).
- **FR10** — **View, cancel** (before deadline), and see **reservation history**.

**Admin (web)**
- **FR11** — Manage hostels & rooms (name, gender, capacity, price, availability).
- **FR12** — View all reservations & payments; **allocate / reassign** a bed.
- **FR13** — **Occupancy dashboard** (beds filled vs free per hostel).

## 6. Non‑functional (only what matters)

- **Usable** — modern, intuitive, one‑hand mobile UX; **light theme by default**.
- **Secure** — passwords hashed (bcrypt); biometric kept in the device secure
  enclave; traffic over HTTPS; students see only their own data.
- **Compatible** — runs on **Android and iOS**.
- **Responsive** — screens load instantly on the demo data set.

## 7. Login spec (exact)

| Field | Rule |
|---|---|
| Identifier | Reg‑number `^\d{11}$` **or** school email `^[a-z]+\.[a-z]+\.\d{11}@futo\.edu\.ng$` |
| Password | ≥ 8 chars, must contain at least one letter **and** one number |
| Confirm (sign‑up only) | Must match password |
| Biometric | Optional Face ID / fingerprint after first successful login |

## 8. What we cut from the first draft (and why)

The original draft listed ~40 "the system shall…" lines. We removed the
enterprise‑ops items that a course demo of the FUTO flow does not need:

- SMS broadcasts, announcement blasts, deadline‑reminder engine.
- 99% uptime SLAs, 500 concurrent users, ≤3s page‑load guarantees.
- Horizontal scaling, daily DB backups, multi‑campus expansion.
- Audit‑log / compliance reporting, activity logs, role suspension workflows.

**Kept** the actual spine — *sign in → browse → reserve → pay → get allocation* —
plus a small admin for the office side. Everything above can be re‑added later;
none of it is what the app needs to demonstrate.

## 9. Corrections to the original assumptions

- **NDDC is mixed‑gender** (segregated by floor), *not* male‑only.
- **"PG Hostel" = postgraduate students**, *not* a scholarship perk.
- **A/B/E male & C/D female** is campus‑known but **not officially published** —
  fine for the demo, not stated as fact.
- **Fees conflict** across sources. Lower‑occupancy hostels (NDDC 3–4/room) cost
  more than dense school blocks (8–10/room); the table in §4 uses representative
  figures.
