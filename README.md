# Roost — FUTO Hostel Reservation

**SOE‑510 Mobile App Development · Group 2**

A mobile‑first hostel reservation app for FUTO students, with a marketing landing
page and a web admin for the Hostel / Student Affairs office. It digitises the
real FUTO flow — *sign in → browse → reserve a bed → pay (Remita) → get your
allocation* — into a clean, modern app.

> "Roost" is a working brand name (the wordmark is `Roost.` with a blue dot).
> To rename, change the wordmark in `landing/index.html`, the title in
> `app/lib/app.dart`, and the login wordmark in `app/lib/features/onboarding/`.

---

## What's inside

```
futo-hostel-reservation/
├── REQUIREMENTS.md     Lean, accurate requirements (replaces the 40-point draft)
├── app/                Flutter mobile app  (the graded deliverable)
├── landing/            Marketing landing page  (static HTML/CSS/JS)
├── admin/              Web admin dashboard  (static HTML/CSS/JS)
└── README.md
```

All three share **one design language**: white surfaces + **FUTO royal blue**
(`#2563EB`) accent, Montserrat, squircle corners. The Flutter design system is
ported from our in-house Flutter design system; the web pages mirror its tokens in plain CSS.

---

## Run it

### 📱 Run the student app

```bash
cd app
flutter pub get
flutter run
# explicitly select the student entry point:
flutter run -t lib/main.dart
```
- The student app is **API-only**. Sign-in, hostel availability, reservations and
  payments always come from the backend; it does not fall back to sample hostel
  data when the API is unavailable.
- The first request can take about 50 seconds if the Render service is asleep.
- **Login:** register or sign in with a reg number like `20211234567` (or a school
  email `name.surname.regno@futo.edu.ng`) + a password that is **8+ chars with a
  letter and a number** (e.g. `futo2026`). After the first sign-in, **Face ID /
  fingerprint** unlocks the saved session.

### Build the student APK

Install Android Studio and its Android SDK first. Then:

```bash
cd app
flutter pub get
flutter build apk --release
```

The installable APK is written to
`app/build/app/outputs/flutter-apk/app-release.apk`. This project currently uses
debug-key signing for release builds, which is suitable for testing on devices;
configure a private upload key before publishing to Google Play.

### 🛠 Optional admin app

The Flutter student app is the primary deliverable. An admin app is also
available for hostel staff, but it is optional to build and test:

```bash
cd app
flutter run -t lib/main_admin.dart
# or build its separate APK:
flutter build apk --release -t lib/main_admin.dart
```

The repository also contains a lightweight web admin dashboard in `admin/`.
Both admin clients require an admin account on the backend.

### 🍎 Run both apps on a physical iPhone

Connect and unlock the iPhone, trust the Mac, and enable **Developer Mode** in
**Settings → Privacy & Security → Developer Mode**. With the device connected:

```bash
cd app
flutter devices                         # copy the iPhone device ID

# Student app — opens as “Futo Hostel”
flutter run -d <iphone-device-id> -t lib/main.dart

# Admin app — opens separately as “Hostel Admin”
flutter run -d <iphone-device-id> --flavor admin -t lib/main_admin.dart
```

Run the commands in separate terminals if you want both debug sessions active.
The `admin` flavor selects the iOS `Debug-admin` configuration, which has a
different bundle ID from the student app, so both remain installed side by side.

### 🌐 Landing page and web admin (no build step)
Open `landing/index.html` or `admin/index.html` directly, **or** serve the folder:
```bash
python3 -m http.server 8765      # from this directory
# landing → http://localhost:8765/landing/
# admin   → http://localhost:8765/admin/
```

### 🎬 Wire up the landing CTAs
Edit the `CONFIG` block at the top of `landing/script.js`:
- `appetizeUrl` — paste your **Appetize.io** public link (powers **View live**).
- `videoEmbedUrl` — paste a YouTube/Loom **embed** URL (powers **Watch video**).
- Until set, **View live** opens the local web build and **Watch video** shows a
  placeholder.

---

## Live backend

- **API base:** `https://futo-hostel-reservation-backend.onrender.com/api/v1`
- **API docs (Swagger):** `https://futo-hostel-reservation-backend.onrender.com/api/docs`
- The Flutter app **and** the web admin talk to this by default. How the client is
  wired (and how to point at a different backend) is in
  [`docs/INTEGRATION.md`](docs/INTEGRATION.md).
- **Admin dashboard:** open `admin/index.html`, sign in with an admin account, and
  it shows live occupancy, reservations and hostels.
- Heads-up: the backend is on Render's free tier — after ~15 min idle it sleeps and
  the next request cold-starts (~50s).

## Maps & imagery
- The landing embeds a **live Google Map** of FUTO and every hostel card links to
  its location on Google Maps; the app's hostel detail has a **View on map**
  button that opens Google Maps at the hostel's coordinates.
- Hostel covers are on‑brand gradient cards (distinct per block). To use a real
  photo instead, drop `app/assets/hostels/<id>.jpg` (and set a `background-image`
  on `.hcard-cover` in the landing) — the layout already accommodates it.

## The hostel catalogue
Hostels **A–E**, **TETFund**, **NDDC**, **PG** — real blocks. Gender / room size /
fee are representative seed values (FUTO doesn't publish an authoritative table,
and the few published fees conflict). See **REQUIREMENTS.md §4 & §9** for the
sourcing and corrections (e.g. NDDC is mixed‑gender; "PG" = postgraduate).

## Requirement → where it lives
| FR | Implemented in |
|---|---|
| FR1–3 Auth + biometric | `app/lib/features/onboarding/` |
| FR4–6 Browse / search / detail | `app/lib/features/browse`, `hostel_detail` |
| FR7 Reserve a bed (live availability) | `app/lib/features/reserve`, `core/demo/hostel_data.dart` |
| FR8–9 Pay (mock Remita) + receipt/RRR | `app/lib/features/reserve` |
| FR10 View / cancel / history | `app/lib/features/reservations` |
| FR11–13 Manage hostels, reservations, allocation, occupancy | `app/lib/features/admin/`, `admin/` |
