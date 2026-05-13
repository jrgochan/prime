/* ═══════════════════════════════════════════════════════════════
   THE CATHEDRAL CLOCK — Engine
   Cosmological Coordinates of Reality on the Nyman-Beurling Lattice
   ═══════════════════════════════════════════════════════════════ */

// ── Physical Constants ──
const CONSTANTS = {
  // Age of universe in seconds (13.8 billion years)
  AGE_UNIVERSE_S: 13.8e9 * 365.25 * 24 * 3600,   // ≈ 4.354e17 s
  // Planck time
  T_PLANCK: 5.391e-44,
  // Observable universe radius in meters (46.5 billion light-years)
  RADIUS_M: 46.5e9 * 9.461e15,
  // Planck length
  L_PLANCK: 1.616e-35,
  // f64 max
  F64_MAX_EXP: 308,
  // Skewes' number exponent
  SKEWES_EXP: 316,
  // Seconds per year
  SEC_PER_YEAR: 365.25 * 24 * 3600,
};

// ── Cosmological Calculator ──
function cosmicCoordinates() {
  const now = Date.now() / 1000;   // Unix epoch seconds
  // Time since Big Bang (current best estimate)
  const ageSeconds = CONSTANTS.AGE_UNIVERSE_S + now;
  const nTime = ageSeconds / CONSTANTS.T_PLANCK;
  const nTimeExp = Math.log10(nTime);

  // Holographic bound: S = 4πR²/l_p²
  const rOverLp = CONSTANTS.RADIUS_M / CONSTANTS.L_PLANCK;
  const nHolographic = 4 * Math.PI * rOverLp * rOverLp;
  const nHoloExp = Math.log10(nHolographic);

  return {
    ageSeconds,
    nTime,
    nTimeExp,           // ≈ 60.9
    nHolographic,
    nHoloExp,           // ≈ 122.7
  };
}

// ── Timeline Landmarks ──
const LANDMARKS = [
  {
    id: 'planck',
    name: 'PLANCK EPOCH',
    exponent: 0,
    icon: '⚛️',
    color: '#4ef080',
    desc: 'N = 1. The first Planck tick. The universe is one irreducible quantum of time old.',
  },
  {
    id: 'gpu',
    name: 'GPU MATRIX',
    exponent: Math.log10(55440),
    icon: '⚙️',
    color: '#ff8844',
    desc: 'N = 55,440. Tonight\'s Rust/GPU Gram matrix computation in Los Alamos.',
    displayValue: '55,440',
  },
  {
    id: 'cosmic-age',
    name: 'YOU ARE HERE',
    exponent: 60.9,
    icon: '🌍',
    color: '#4eeaff',
    desc: 'N ≈ 8.07 × 10⁶⁰. The age of our physical universe in Planck ticks.',
    isYou: true,
  },
  {
    id: 'googol',
    name: 'GOOGOL',
    exponent: 100,
    icon: '🔢',
    color: '#a855f7',
    desc: 'N = 10¹⁰⁰. The classic large number. The universe hasn\'t reached this yet.',
  },
  {
    id: 'holographic',
    name: 'HOLOGRAPHIC LIMIT',
    exponent: 122,
    icon: '🌌',
    color: '#f0c040',
    desc: 'N ≈ 10¹²². The maximum information (Bekenstein-Hawking entropy) the observable universe can ever hold.',
  },
  {
    id: 'silicon',
    name: 'SILICON HORIZON',
    exponent: 308,
    icon: '🖥️',
    color: '#ff8844',
    desc: 'N = 1.79 × 10³⁰⁸. Maximum f64 value. Beyond this, the CPU returns INFINITY.',
  },
  {
    id: 'skewes',
    name: 'SKEWES\' SINGULARITY',
    exponent: 316,
    icon: '💥',
    color: '#ff3344',
    desc: 'N ≈ 1.39 × 10³¹⁶. Where π(x) first exceeds li(x). The arithmetic false vacuum decays.',
  },
];

// Scale: exponent 0–400 → 0%–100%
const TIMELINE_MAX = 400;
function expToPercent(exp) {
  return Math.max(0, Math.min(100, (exp / TIMELINE_MAX) * 100));
}

// ── Render Timeline ──
function renderTimeline() {
  const track = document.getElementById('timeline-track');
  if (!track) return;

  // Stagger heights to prevent label overlap
  const heights = [140, 100, 180, 120, 160, 90, 130];
  const labelPositions = ['top', 'top', 'top', 'top', 'top', 'top', 'top'];

  LANDMARKS.forEach((lm, idx) => {
    const pct = expToPercent(lm.exponent);
    const marker = document.createElement('div');
    marker.className = `tl-marker${lm.isYou ? ' you-are-here' : ''}`;
    marker.style.left = `${pct}%`;
    marker.style.setProperty('--marker-color', lm.color);

    const lineHeight = lm.isYou ? 180 : heights[idx % heights.length];
    const labelOffset = -(lineHeight + 18);

    marker.innerHTML = `
      <div class="tl-marker-label" style="top: ${labelOffset}px;">${lm.name}</div>
      <div class="tl-marker-dot"></div>
      <div class="tl-marker-line" style="height: ${lineHeight}px;"></div>
      <div class="tl-marker-value">10<sup>${Math.round(lm.exponent)}</sup></div>
    `;
    track.appendChild(marker);
  });

  // Axis labels
  const axisLabels = document.getElementById('axis-labels');
  if (axisLabels) {
    for (let e = 0; e <= TIMELINE_MAX; e += 50) {
      const label = document.createElement('span');
      label.innerHTML = `10<sup>${e}</sup>`;
      axisLabels.appendChild(label);
    }
  }
}

// ── Render Landmark Cards ──
function renderLandmarkCards() {
  const grid = document.getElementById('landmarks-grid');
  if (!grid) return;

  LANDMARKS.forEach(lm => {
    const card = document.createElement('div');
    card.className = 'landmark-card';
    card.style.setProperty('--card-accent', lm.color);

    const displayVal = lm.displayValue || (lm.exponent === 0 ? '1' : `10<sup>${Math.round(lm.exponent)}</sup>`);

    card.innerHTML = `
      <div class="landmark-icon">${lm.icon}</div>
      <div class="landmark-name">${lm.name}</div>
      <div class="landmark-value">N = ${displayVal}</div>
      <div class="landmark-desc">${lm.desc}</div>
    `;
    grid.appendChild(card);
  });
}

// ── Planck Counter ──
function updatePlanckCounter() {
  const coords = cosmicCoordinates();

  // Format: 8.0700000... × 10^60
  const mantissa = coords.nTime / Math.pow(10, Math.floor(coords.nTimeExp));
  const exponent = Math.floor(coords.nTimeExp);

  // Show many digits for the live-ticking effect
  const mantissaStr = mantissa.toFixed(14);

  const counterEl = document.getElementById('planck-value');
  if (counterEl) {
    counterEl.innerHTML = `${mantissaStr} × 10<sup>${exponent}</sup>`;
  }

  const ageEl = document.getElementById('age-seconds');
  if (ageEl) {
    ageEl.textContent = coords.ageSeconds.toExponential(6);
  }
}

// ── Live Clock ──
function updateLiveTime() {
  const el = document.getElementById('live-time');
  if (!el) return;
  const now = new Date();
  const opts = {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    timeZoneName: 'short',
  };
  el.textContent = now.toLocaleDateString('en-US', opts);
}

// ── Starfield ──
function initStarfield() {
  const canvas = document.getElementById('stars-canvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');

  let width, height;
  const stars = [];
  const STAR_COUNT = 300;

  function resize() {
    width = canvas.width = window.innerWidth;
    height = canvas.height = window.innerHeight;
  }

  function createStars() {
    stars.length = 0;
    for (let i = 0; i < STAR_COUNT; i++) {
      stars.push({
        x: Math.random() * width,
        y: Math.random() * height,
        r: Math.random() * 1.5 + 0.3,
        alpha: Math.random() * 0.8 + 0.2,
        speed: Math.random() * 0.02 + 0.005,
        phase: Math.random() * Math.PI * 2,
        // Some stars are colored
        hue: Math.random() > 0.85 ? (Math.random() > 0.5 ? 180 : 45) : 0,
        sat: Math.random() > 0.85 ? 80 : 0,
      });
    }
  }

  let time = 0;
  function draw() {
    ctx.clearRect(0, 0, width, height);
    time += 0.016;

    for (const star of stars) {
      const twinkle = 0.5 + 0.5 * Math.sin(time * star.speed * 60 + star.phase);
      const a = star.alpha * twinkle;

      if (star.hue > 0) {
        ctx.fillStyle = `hsla(${star.hue}, ${star.sat}%, 80%, ${a})`;
      } else {
        ctx.fillStyle = `rgba(220, 220, 255, ${a})`;
      }

      ctx.beginPath();
      ctx.arc(star.x, star.y, star.r, 0, Math.PI * 2);
      ctx.fill();
    }

    requestAnimationFrame(draw);
  }

  resize();
  createStars();
  draw();

  window.addEventListener('resize', () => {
    resize();
    createStars();
  });
}

// ── Horizon Fill Animation ──
function animateHorizonFill() {
  const fill = document.getElementById('horizon-fill');
  if (!fill) return;
  // Our universe at 10^61 on a 10^400 scale → about 15.25%
  setTimeout(() => {
    fill.style.width = '15.25%';
  }, 500);
}

// ── Entry point animation (Intersection Observer) ──
function initScrollAnimations() {
  const sections = document.querySelectorAll('section');
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.style.opacity = '1';
        entry.target.style.transform = 'translateY(0)';
      }
    });
  }, { threshold: 0.1 });

  sections.forEach(section => {
    section.style.opacity = '0';
    section.style.transform = 'translateY(30px)';
    section.style.transition = 'opacity 0.8s ease, transform 0.8s ease';
    observer.observe(section);
  });
}

// ── Init ──
document.addEventListener('DOMContentLoaded', () => {
  initStarfield();
  renderTimeline();
  renderLandmarkCards();
  updatePlanckCounter();
  updateLiveTime();
  animateHorizonFill();
  initScrollAnimations();

  // Live updates
  setInterval(updatePlanckCounter, 100);  // Tick fast for visual drama
  setInterval(updateLiveTime, 1000);
});
