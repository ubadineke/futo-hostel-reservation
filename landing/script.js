/* ───────── Roost landing — interactions ───────── */

// ── EDIT THESE TWO LINES to wire up the real demo ──
const CONFIG = {
  // Paste your Appetize.io public app link here to stream the real app in-browser.
  appetizeUrl: '',
  // Paste a YouTube/Loom EMBED url here (e.g. https://www.youtube.com/embed/XXXX).
  videoEmbedUrl: '',
  // Fallback for "View live" when no Appetize link is set: the local web build.
  webAppUrl: '../app/build/web/index.html',
};

// The eight FUTO hostels (mirrors the app's data).
const HOSTELS = [
  { name:'Hostel A', funder:'School', gender:'Male', room:'8–10 / room', price:100, beds:12, total:88, a:'#1E3A8A', b:'#2563EB', lat:5.3869, lng:7.0341 },
  { name:'Hostel B', funder:'School', gender:'Male', room:'8–10 / room', price:42000, beds:5, total:98, a:'#312E81', b:'#4F46E5', lat:5.3872, lng:7.0347 },
  { name:'Hostel C', funder:'School', gender:'Female', room:'6–8 / room', price:45000, beds:13, total:84, a:'#0F766E', b:'#0EA5A4', lat:5.3858, lng:7.0359 },
  { name:'Hostel D', funder:'School', gender:'Female', room:'6–8 / room', price:45000, beds:2, total:68, a:'#155E75', b:'#0891B2', lat:5.3855, lng:7.0364 },
  { name:'Hostel E', funder:'School', gender:'Male', room:'8–10 / room', price:42000, beds:0, total:64, a:'#1E293B', b:'#334155', lat:5.3877, lng:7.0338 },
  { name:'TETFund Hostel', funder:'TETFund', gender:'Mixed', room:'4 / room', price:90000, beds:8, total:80, a:'#1D4ED8', b:'#3B82F6', lat:5.3851, lng:7.0366 },
  { name:'NDDC Hostel', funder:'NDDC', gender:'Mixed', room:'3–4 / room', price:62500, beds:10, total:100, a:'#134E4A', b:'#0D9488', lat:5.3848, lng:7.0371 },
  { name:'PG Hostel', funder:'Postgraduate', gender:'Postgraduate', room:'1–2 / room', price:75000, beds:7, total:52, a:'#4C1D95', b:'#6D28D9', lat:5.3845, lng:7.0331 },
];

const naira = (n) => '₦' + n.toLocaleString('en-NG');
const BLD = '<svg viewBox="0 0 24 24" class="bld"><path fill="currentColor" d="M3 21V7l6-4 6 4v14H3zm12 0V10h6v11h-6zM6 11h2v2H6v-2zm0 4h2v2H6v-2zm4-4h2v2h-2v-2zm0 4h2v2h-2v-2z"/></svg>';

function statusPill(beds) {
  if (beds === 0) return '<span class="pill full">FULL</span>';
  if (beds <= 6) return '<span class="pill warn">LIMITED</span>';
  return '<span class="pill pos">AVAILABLE</span>';
}

function renderHostels() {
  const grid = document.getElementById('hostelGrid');
  grid.innerHTML = HOSTELS.map((h) => `
    <article class="hcard reveal">
      <div class="hcard-cover" style="background:linear-gradient(135deg,${h.a},${h.b})">
        <span class="hcard-chip">${h.funder}</span>
        ${statusPill(h.beds)}
        ${BLD}
      </div>
      <div class="hcard-body">
        <div class="hcard-row"><h3>${h.name}</h3><span class="hcard-price">${naira(h.price)}</span></div>
        <p class="hcard-sub">${h.gender} · ${h.room} · ${h.beds} of ${h.total} beds open</p>
        <a class="hcard-map" target="_blank" rel="noopener"
           href="https://www.google.com/maps/search/?api=1&query=${h.lat},${h.lng}">View on map ›</a>
      </div>
    </article>`).join('');
  observeReveals();
}

// ── actions ──
function viewLive() {
  const url = CONFIG.appetizeUrl || CONFIG.webAppUrl;
  window.open(url, '_blank', 'noopener');
}

function openVideo() {
  const modal = document.getElementById('videoModal');
  const slot = document.getElementById('modalVideo');
  slot.innerHTML = CONFIG.videoEmbedUrl
    ? `<iframe src="${CONFIG.videoEmbedUrl}" allow="autoplay; fullscreen" allowfullscreen></iframe>`
    : `<div class="modal-placeholder"><b>Demo video goes here</b>Paste your YouTube or Loom embed link into <code>CONFIG.videoEmbedUrl</code> in script.js, then this opens the walkthrough.</div>`;
  modal.hidden = false;
}
function closeVideo() {
  const modal = document.getElementById('videoModal');
  modal.hidden = true;
  document.getElementById('modalVideo').innerHTML = '';
}

document.addEventListener('click', (e) => {
  const action = e.target.closest('[data-action]')?.dataset.action;
  if (!action) return;
  if (action === 'live') viewLive();
  if (action === 'watch') openVideo();
  if (action === 'close-modal') closeVideo();
});
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeVideo(); });

// ── nav shadow on scroll ──
const nav = document.getElementById('nav');
const onScroll = () => nav.classList.toggle('scrolled', window.scrollY > 8);
window.addEventListener('scroll', onScroll, { passive: true });

// ── reveal on scroll ──
let _observer;
function observeReveals() {
  _observer = _observer || new IntersectionObserver((entries) => {
    entries.forEach((en) => { if (en.isIntersecting) { en.target.classList.add('in'); _observer.unobserve(en.target); } });
  }, { threshold: 0.12 });
  document.querySelectorAll('.reveal:not(.in)').forEach((el) => _observer.observe(el));
}

renderHostels();
observeReveals();
onScroll();
