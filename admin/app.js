/* ============================================================
   Roost — FUTO Hostel Reservation : Admin dashboard
   Vanilla JS, no build step. Open index.html directly.
   ============================================================ */

/* ---------------- SEED DATA ---------------- */

const HOSTELS = [
  { name: 'Hostel A', gender: 'Male', funder: 'School', price: 100, rooms: [
    { type: '8-bed', avail: 9, total: 48 },
    { type: '10-bed', avail: 3, total: 40 },
  ]},
  { name: 'Hostel B', gender: 'Male', funder: 'School', price: 42000, rooms: [
    { type: '8-bed', avail: 0, total: 48 },
    { type: '10-bed', avail: 5, total: 50 },
  ]},
  { name: 'Hostel C', gender: 'Female', funder: 'School', price: 45000, rooms: [
    { type: '6-bed', avail: 7, total: 36 },
    { type: '8-bed', avail: 6, total: 48 },
  ]},
  { name: 'Hostel D', gender: 'Female', funder: 'School', price: 45000, rooms: [
    { type: '6-bed', avail: 2, total: 36 },
    { type: '8-bed', avail: 0, total: 32 },
  ]},
  { name: 'Hostel E', gender: 'Male', funder: 'School', price: 42000, rooms: [
    { type: '8-bed', avail: 0, total: 64 },
  ]},
  { name: 'TETFund Hostel', gender: 'Mixed', funder: 'TETFund', price: 90000, rooms: [
    { type: '4-bed en-suite', avail: 8, total: 80 },
  ]},
  { name: 'NDDC Hostel', gender: 'Mixed', funder: 'NDDC', price: 62500, rooms: [
    { type: '4-bed', avail: 6, total: 64 },
    { type: '3-bed', avail: 4, total: 36 },
  ]},
  { name: 'PG Hostel', gender: 'Postgraduate', funder: 'Postgraduate', price: 75000, rooms: [
    { type: '2-bed', avail: 5, total: 40 },
    { type: '1-bed studio', avail: 2, total: 12 },
  ]},
];

const RESERVATIONS = [
  { ref: 'RST-7F3A21', student: 'Chidi Okeke', reg: '20211234567', hostel: 'NDDC Hostel', room: '4-bed · Bed 2', rrr: '270054118832', amount: 62500, status: 'PAID', date: 'Jun 5 2026' },
  { ref: 'RST-4B19C0', student: 'Chidera Okafor', reg: '20191234501', hostel: 'Hostel C', room: '6-bed · Bed 4', rrr: '270061230099', amount: 45000, status: 'PAID', date: 'Jun 4 2026' },
  { ref: 'RST-9A22E1', student: 'Emeka Eze', reg: '20211298877', hostel: 'Hostel A', room: '8-bed · Bed 7', rrr: '270070456712', amount: 42000, status: 'PENDING', date: 'Jun 6 2026' },
  { ref: 'RST-2C77F4', student: 'Aisha Bello', reg: '20201145623', hostel: 'TETFund Hostel', room: '4-bed · Bed 1', rrr: '270048990021', amount: 90000, status: 'PAID', date: 'Jun 3 2026' },
  { ref: 'RST-1D55A8', student: 'Ngozi Udeh', reg: '20191100432', hostel: 'NDDC Hostel', room: '3-bed · Bed 1', rrr: '270055667788', amount: 62500, status: 'CANCELLED', date: 'Sep 14 2025' },
];

let QUEUE = [
  { reg: '20231104567', name: 'Favour Adeyemi', level: '100 Level', requested: 'Hostel A' },
  { reg: '20231109934', name: 'Ifeoma Nwosu', level: '100 Level', requested: 'Hostel C' },
  { reg: '20191203345', name: 'Tobi Lawal', level: 'Final Year', requested: 'Hostel B' },
  { reg: '20221156782', name: 'Samuel Obi', level: '300 Level', requested: 'NDDC Hostel' },
  { reg: '20191188210', name: 'Blessing Eze', level: 'Final Year', requested: 'TETFund Hostel' },
  { reg: '20221177450', name: 'Daniel Uche', level: '200 Level', requested: 'Hostel A' },
];

const ALLOCATED = [];

/* ---------------- HELPERS ---------------- */

const $ = (sel, root = document) => root.querySelector(sel);

function naira(n) { return '₦' + n.toLocaleString('en-NG'); }

function bedsFor(hostel) {
  let avail = 0, total = 0;
  hostel.rooms.forEach(r => { avail += r.avail; total += r.total; });
  return { avail, total, occupied: total - avail };
}

// Status rule: 0 => FULL, <=6 => LIMITED, else AVAILABLE
function hostelStatus(avail) {
  if (avail === 0) return 'FULL';
  if (avail <= 6) return 'LIMITED';
  return 'AVAILABLE';
}

function pill(text) {
  const map = {
    AVAILABLE: 'pill-positive',
    LIMITED:   'pill-warning',
    FULL:      'pill-neutral',
    PAID:      'pill-positive',
    RESERVED:  'pill-accent',
    PENDING:   'pill-neutral',
    CANCELLED: 'pill-negative',
    ALLOCATED: 'pill-positive',
  };
  const cls = map[text] || 'pill-neutral';
  return `<span class="pill ${cls}">${text}</span>`;
}

function isPriority(level) {
  return /100 Level/i.test(level) || /Final Year/i.test(level);
}

/* ---------------- RENDER: OVERVIEW ---------------- */

function renderOverview() {
  let totalBeds = 0, availBeds = 0, revenue = 0;
  HOSTELS.forEach(h => {
    const b = bedsFor(h);
    totalBeds += b.total;
    availBeds += b.avail;
    revenue += b.occupied * h.price; // rough session revenue from occupied beds
  });
  const occupied = totalBeds - availBeds;
  const occPct = Math.round((occupied / totalBeds) * 100);

  const stats = [
    { label: 'Total beds', value: totalBeds.toLocaleString(), hint: HOSTELS.length + ' hostels' },
    { label: 'Occupied beds', value: occupied.toLocaleString(), hint: occPct + '% of capacity' },
    { label: 'Available beds', value: availBeds.toLocaleString(), hint: 'open for booking' },
    { label: 'Occupancy', value: occPct + '%', hint: 'this session' },
    { label: 'Revenue', value: naira(revenue), hint: 'projected (occupied)' },
  ];

  $('#statGrid').innerHTML = stats.map(s => `
    <div class="stat-card">
      <div class="stat-label">${s.label}</div>
      <div class="stat-value">${s.value}</div>
      <div class="stat-hint">${s.hint}</div>
    </div>`).join('');

  // Occupancy by hostel
  $('#occList').innerHTML = HOSTELS.map(h => {
    const b = bedsFor(h);
    const pct = Math.round((b.occupied / b.total) * 100);
    const hot = pct > 90 ? ' hot' : '';
    return `
      <div class="occ-row">
        <div>
          <div class="occ-name">${h.name}</div>
          <div class="occ-funder">${h.funder} · ${h.gender}</div>
        </div>
        <div class="occ-count">${b.occupied} / ${b.total} beds · ${pct}%</div>
        <div class="occ-bar-wrap">
          <div class="bar"><div class="bar-fill${hot}" style="width:${pct}%"></div></div>
        </div>
      </div>`;
  }).join('');

  // Recent reservations (most recent 5 as seeded)
  $('#recentBody').innerHTML = RESERVATIONS.map(r => `
    <tr>
      <td>
        <div class="cell-strong">${r.student}</div>
        <div class="cell-sub">${r.reg}</div>
      </td>
      <td>${r.hostel}</td>
      <td>${r.room}</td>
      <td class="amount">${naira(r.amount)}</td>
      <td>${pill(r.status)}</td>
      <td>${r.date}</td>
    </tr>`).join('');
}

/* ---------------- RENDER: HOSTELS ---------------- */

function renderHostels() {
  $('#hostelBody').innerHTML = HOSTELS.map(h => {
    const b = bedsFor(h);
    const status = hostelStatus(b.avail);
    return `
      <tr>
        <td>
          <div class="cell-strong">${h.name}</div>
          <div class="cell-sub">${h.funder}</div>
        </td>
        <td>${h.gender}</td>
        <td>${h.rooms.length}</td>
        <td><span class="cell-strong">${b.avail}</span> / ${b.total}</td>
        <td class="amount">${naira(h.price)}</td>
        <td>${pill(status)}</td>
      </tr>`;
  }).join('');
}

/* ---------------- RENDER: RESERVATIONS ---------------- */

let activeFilter = 'all';

function renderReservations() {
  const rows = RESERVATIONS.filter(r => activeFilter === 'all' || r.status === activeFilter);
  if (!rows.length) {
    $('#resBody').innerHTML = `<tr><td colspan="8" class="empty">No reservations for this filter.</td></tr>`;
    return;
  }
  $('#resBody').innerHTML = rows.map(r => `
    <tr>
      <td class="cell-strong">${r.ref}</td>
      <td>
        <div class="cell-strong">${r.student}</div>
        <div class="cell-sub">${r.reg}</div>
      </td>
      <td>${r.hostel}</td>
      <td>${r.room}</td>
      <td class="mono">${r.rrr}</td>
      <td class="amount">${naira(r.amount)}</td>
      <td>${pill(r.status)}</td>
      <td>${r.date}</td>
    </tr>`).join('');
}

/* ---------------- RENDER: ALLOCATION ---------------- */

function hostelOptions(selected) {
  return HOSTELS.map(h => {
    const b = bedsFor(h);
    const sel = h.name === selected ? ' selected' : '';
    const label = b.avail > 0 ? `${h.name} (${b.avail} free)` : `${h.name} (full)`;
    return `<option value="${h.name}"${sel}${b.avail === 0 ? ' disabled' : ''}>${label}</option>`;
  }).join('');
}

function renderAllocation() {
  $('#pendingCount').textContent = QUEUE.length;
  $('#allocatedCount').textContent = ALLOCATED.length;

  if (!QUEUE.length) {
    $('#queueList').innerHTML = `<div class="empty">No pending requests. All caught up.</div>`;
  } else {
    $('#queueList').innerHTML = QUEUE.map((q, i) => `
      <div class="queue-item">
        <div class="qi-head">
          <span class="qi-name">${q.name}</span>
          ${isPriority(q.level) ? '<span class="priority-tag">Priority</span>' : ''}
        </div>
        <div class="qi-meta">${q.reg} · ${q.level} · requested ${q.requested}</div>
        <div class="qi-actions">
          <select class="qi-select" id="sel-${i}">${hostelOptions(q.requested)}</select>
          <button class="btn btn-primary btn-sm" data-allocate="${i}">Allocate</button>
        </div>
      </div>`).join('');
  }

  if (!ALLOCATED.length) {
    $('#allocatedList').innerHTML = `<div class="empty">Allocated students will appear here.</div>`;
  } else {
    $('#allocatedList').innerHTML = ALLOCATED.map(a => `
      <div class="queue-item">
        <div class="qi-head">
          <span class="qi-name">${a.name}</span>
          ${pill('ALLOCATED')}
        </div>
        <div class="qi-meta">${a.reg} · ${a.level} · assigned to ${a.assigned}</div>
      </div>`).join('');
  }
}

function allocate(index) {
  if (window.RoostAdmin && RoostAdmin.isLive()) { RoostAdmin.allocateLive(index); return; }
  const sel = document.getElementById('sel-' + index);
  const assigned = sel ? sel.value : QUEUE[index].requested;
  const student = QUEUE.splice(index, 1)[0];
  ALLOCATED.unshift({ ...student, assigned });

  // Reflect the bed taken: decrement first room with availability in the assigned hostel
  const hostel = HOSTELS.find(h => h.name === assigned);
  if (hostel) {
    const room = hostel.rooms.find(r => r.avail > 0);
    if (room) room.avail -= 1;
  }
  renderAllocation();
}

/* ---------------- NAVIGATION ---------------- */

function showPage(page) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  const target = document.getElementById('page-' + page);
  if (target) target.classList.add('active');

  document.querySelectorAll('.nav-item').forEach(n => {
    n.classList.toggle('active', n.dataset.page === page);
  });
  window.scrollTo(0, 0);
}

/* ---------------- WIRING ---------------- */

document.addEventListener('DOMContentLoaded', () => {
  // initial render
  renderOverview();
  renderHostels();
  renderReservations();
  renderAllocation();

  // sidebar nav
  $('#nav').addEventListener('click', e => {
    const item = e.target.closest('.nav-item');
    if (item) showPage(item.dataset.page);
  });

  // "go to" buttons in headers
  document.querySelectorAll('[data-goto]').forEach(b => {
    b.addEventListener('click', () => showPage(b.dataset.goto));
  });

  // reservation filters
  $('#filterRow').addEventListener('click', e => {
    const btn = e.target.closest('.filter-btn');
    if (!btn) return;
    activeFilter = btn.dataset.filter;
    document.querySelectorAll('.filter-btn').forEach(b => b.classList.toggle('active', b === btn));
    renderReservations();
  });

  // allocation buttons (event delegation)
  $('#queueList').addEventListener('click', e => {
    const btn = e.target.closest('[data-allocate]');
    if (btn) allocate(Number(btn.dataset.allocate));
  });

  // modal
  const scrim = $('#modalScrim');
  const openModal = () => { scrim.hidden = false; };
  const closeModal = () => { scrim.hidden = true; $('#hostelForm').reset(); };

  $('#addHostelBtn').addEventListener('click', openModal);
  $('#modalClose').addEventListener('click', closeModal);
  $('#modalCancel').addEventListener('click', closeModal);
  scrim.addEventListener('click', e => { if (e.target === scrim) closeModal(); });

  $('#hostelForm').addEventListener('submit', e => {
    e.preventDefault();
    const f = e.target;
    const capacity = parseInt(f.capacity.value, 10) || 0;
    HOSTELS.push({
      name: f.name.value.trim(),
      gender: f.gender.value,
      funder: f.funder.value.trim(),
      price: parseInt(f.price.value, 10) || 0,
      rooms: [{ type: 'standard', avail: capacity, total: capacity }],
    });
    closeModal();
    renderHostels();
    renderOverview();
  });

  // Kick off live backend integration (no-op in demo mode). Falls back to the
  // seed data already rendered above if the API is unreachable.
  if (window.RoostAdmin) RoostAdmin.boot();
});
