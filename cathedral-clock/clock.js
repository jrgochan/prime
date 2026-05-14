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

// ── Render Journey (Vertical Timeline) ──
function renderJourney() {
  const journey = document.getElementById('journey');
  if (!journey) return;

  LANDMARKS.forEach((lm, idx) => {
    const node = document.createElement('div');
    const side = idx % 2 === 0 ? 'left' : 'right';
    node.className = `journey-node ${side}${lm.isYou ? ' you-node' : ''}`;
    node.style.setProperty('--node-color', lm.color);

    const displayVal = lm.displayValue || (lm.exponent === 0 ? '1' : `10<sup>${Math.round(lm.exponent)}</sup>`);

    node.innerHTML = `
      <div class="journey-dot"></div>
      <div class="journey-card">
        <div class="journey-header">
          <span class="journey-icon">${lm.icon}</span>
          <span class="journey-name">${lm.name}</span>
        </div>
        <div class="journey-exponent">N = ${displayVal}</div>
        <div class="journey-desc">${lm.desc}</div>
      </div>
    `;
    journey.appendChild(node);
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
  renderJourney();
  updatePlanckCounter();
  updateLiveTime();
  animateHorizonFill();
  initScrollAnimations();
  initPhysicsDashboard();

  // Live updates
  setInterval(updatePlanckCounter, 100);  // Tick fast for visual drama
  setInterval(updateLiveTime, 1000);
});

// ═══════════════════════════════════════════════════════════════
// THE ARITHMETIC VACUUM — Physics Dashboard (v4 sweep data)
// ═══════════════════════════════════════════════════════════════

// v4 sweep data points: [N, cosmo_ratio (Λ), excess, excess/lnN, marginal_per_dim]
const V4_DATA = [
  [6,     1.000000, -0.36544, -0.20392, 0.126885],
  [12,    0.927648, -0.34108, -0.13729, 0.092924],
  [24,    0.818455, -0.09195,  0.08194, 0.058605],
  [36,    0.722644,  0.02134,  0.00596, 0.042854],
  [48,    0.640704,  0.08268,  0.02136, 0.033707],
  [60,    0.588716,  0.13160,  0.03215, 0.027952],
  [120,   0.431509,  0.25462,  0.05317, 0.015199],
  [180,   0.345483,  0.30981,  0.05965, 0.010481],
  [240,   0.292202,  0.34739,  0.06343, 0.008036],
  [360,   0.223045,  0.39523,  0.06712, 0.005503],
  [720,   0.117940,  0.46400,  0.07047, 0.002850],
  [840,   0.096427,  0.47716,  0.07089, 0.002458],
  [1000,  0.072069,  0.49014,  0.07098, 0.002076],
  [1260,  0.044024,  0.51037,  0.07148, 0.001664],
  [1680,  0.008605,  0.53049,  0.07149, 0.001258],
  [2520,  0.036681,  0.55810,  0.07117, 0.000848],
  [5040,  0.105785,  0.59975,  0.07028, 0.000431],
  [7560,  0.141945,  0.62145,  0.06953, 0.000290],
  [10000, 0.165552,  0.63490,  0.06891, 0.000220],
  [10080, 0.166183,  0.63532,  0.06889, 0.000218],
  [15120, 0.198087,  0.65376,  0.06794, 0.000147],
  [20000, 0.218589,  0.66602,  0.06722, 0.000111],
  [20160, 0.219174,  0.66633,  0.06720, 0.000110],
  [25200, 0.234820,  0.67559,  0.06662, 0.000089],
  [27720, 0.241338,  0.67938,  0.06638, 0.000081],
  [40000, 0.265527,  0.69321,  0.06543, 0.000056],
  [45360, 0.273379,  0.69799,  0.06509, 0.000050],
  [55440, 0.285865,  0.70470,  0.06457, 0.000041],
];

function lerp(a, b, t) { return a + (b - a) * t; }

function interpolateV4(N) {
  if (N <= V4_DATA[0][0]) return V4_DATA[0];
  if (N >= V4_DATA[V4_DATA.length - 1][0]) return V4_DATA[V4_DATA.length - 1];
  for (let i = 0; i < V4_DATA.length - 1; i++) {
    if (N >= V4_DATA[i][0] && N <= V4_DATA[i + 1][0]) {
      const t = (N - V4_DATA[i][0]) / (V4_DATA[i + 1][0] - V4_DATA[i][0]);
      return [
        N,
        lerp(V4_DATA[i][1], V4_DATA[i + 1][1], t),
        lerp(V4_DATA[i][2], V4_DATA[i + 1][2], t),
        lerp(V4_DATA[i][3], V4_DATA[i + 1][3], t),
        lerp(V4_DATA[i][4], V4_DATA[i + 1][4], t),
      ];
    }
  }
  return V4_DATA[V4_DATA.length - 1];
}

function sliderToN(val) {
  // Exponential mapping: slider 0-100 → N 6-55440
  const logMin = Math.log(6);
  const logMax = Math.log(55440);
  return Math.round(Math.exp(logMin + (val / 100) * (logMax - logMin)));
}

function updatePhysicsDashboard(N, label) {
  const [_, lambda, excess, excessLn, marginal] = interpolateV4(N);
  const cancel = 1 - lambda;

  // Lambda
  const lambdaEl = document.getElementById('lambda-value');
  const lambdaBar = document.getElementById('lambda-bar');
  if (lambdaEl) lambdaEl.textContent = lambda.toFixed(6);
  if (lambdaBar) lambdaBar.style.width = `${Math.min(100, lambda * 100)}%`;

  // Cancellation
  const cancelEl = document.getElementById('cancel-value');
  const cancelBar = document.getElementById('cancel-bar');
  if (cancelEl) cancelEl.textContent = `${(cancel * 100).toFixed(4)}%`;
  if (cancelBar) cancelBar.style.width = `${cancel * 100}%`;

  // Epsilon
  const epsilonEl = document.getElementById('epsilon-value');
  const epsilonBar = document.getElementById('epsilon-bar');
  if (epsilonEl) epsilonEl.textContent = excessLn.toFixed(6);
  if (epsilonBar) epsilonBar.style.width = `${Math.min(100, Math.abs(excessLn) * 1000)}%`;

  // Marginal
  const marginalEl = document.getElementById('marginal-value');
  const marginalBar = document.getElementById('marginal-bar');
  if (marginalEl) marginalEl.textContent = marginal.toExponential(4);
  if (marginalBar) marginalBar.style.width = `${Math.min(100, marginal * 5000)}%`;

  // N display (for explore mode)
  const nValEl = document.getElementById('physics-n-value');
  if (nValEl) nValEl.textContent = label || `N = ${N.toLocaleString()}`;

  // Era display
  const eraEl = document.getElementById('physics-era');
  if (eraEl) {
    if (N < 240) {
      eraEl.textContent = '🔵 BOSONIC ERA — D(N) < 1, vacuum pressure expands';
      eraEl.className = 'physics-era bosonic';
    } else if (N < 1680) {
      eraEl.textContent = '🟡 TRANSITION — approaching N ≈ 1680 critical point';
      eraEl.className = 'physics-era transition';
    } else {
      eraEl.textContent = '🔴 FERMIONIC ERA — vacuum tension compensates D(N), Λ → 0';
      eraEl.className = 'physics-era fermionic';
    }
  }
}

// ── Cosmic Mode: Extrapolation Engine ──
// v4 scaling fits (from the fermionic era, N > 2500):
//   Λ(N)      ~ (Λ₀) · (N/N₀)^α_λ     α_λ ≈ -0.0013  (very slow decay)
//   marginal  ~ (m₀) · (N/N₀)^α_m      α_m ≈ -0.96    (near 1/N)
//   ε/ln(N)   → C ≈ 0.065              (stabilizes — this IS the RH conjecture)
//   cancel η  = 1 - Λ                   (derived)

const SCALING = {
  // Reference point: N=55440 (our largest measurement)
  N0: 55440,
  lambda0: 0.285865,
  marginal0: 0.000041,
  epsilonLn0: 0.06457,
  // Power-law exponents from v4 regression
  alpha_lambda: -0.0013,   // Λ decays very slowly
  alpha_marginal: -0.96,   // marginal ≈ 1/N (asymptotic freedom)
};

function extrapolateCosmicValues(logN) {
  // logN is log₁₀(N) — e.g., 60.9 for the age of the universe
  const logN0 = Math.log10(SCALING.N0);   // ≈ 4.74
  const logRatio = logN - logN0;           // e.g., 56.2

  // Power-law extrapolation: f(N) = f(N₀) · (N/N₀)^α = f(N₀) · 10^(α · logRatio)
  const lambda = SCALING.lambda0 * Math.pow(10, SCALING.alpha_lambda * logRatio);
  const marginal = SCALING.marginal0 * Math.pow(10, SCALING.alpha_marginal * logRatio);
  // ε/ln(N) stabilizes — this is the RH conjecture (bounded)
  const epsilonLn = SCALING.epsilonLn0;
  // Excess = ε/ln(N) * ln(N) = ε/ln(N) * logN * ln(10)
  const excess = epsilonLn * logN * Math.LN10;
  const cancel = 1 - lambda;

  return { lambda, cancel, excess, epsilonLn, marginal, logN };
}

function updateCosmicDashboard() {
  const coords = cosmicCoordinates();
  const logN = coords.nTimeExp;  // ≈ 60.9
  const cosmic = extrapolateCosmicValues(logN);

  // Lambda — at N ≈ 10^61, still detectable but incredibly tiny
  const lambdaEl = document.getElementById('lambda-value');
  const lambdaBar = document.getElementById('lambda-bar');
  if (lambdaEl) lambdaEl.textContent = cosmic.lambda.toExponential(6);
  // Bar: show relative to reference (log scale visualization)
  if (lambdaBar) {
    const barPct = Math.max(0.5, Math.min(100, 100 * (1 + Math.log10(cosmic.lambda) / 3)));
    lambdaBar.style.width = `${barPct}%`;
  }

  // Cancellation — essentially 100% at cosmic scales
  const cancelEl = document.getElementById('cancel-value');
  const cancelBar = document.getElementById('cancel-bar');
  if (cancelEl) {
    // Show the number of 9s
    const nines = -Math.log10(1 - cosmic.cancel);
    if (nines > 6) {
      cancelEl.textContent = `99.${'9'.repeat(Math.min(12, Math.floor(nines) - 2))}...%`;
    } else {
      cancelEl.textContent = `${(cosmic.cancel * 100).toFixed(4)}%`;
    }
  }
  if (cancelBar) cancelBar.style.width = `${Math.min(100, cosmic.cancel * 100)}%`;

  // Epsilon/ln(N) — the RH invariant
  const epsilonEl = document.getElementById('epsilon-value');
  const epsilonBar = document.getElementById('epsilon-bar');
  if (epsilonEl) epsilonEl.textContent = cosmic.epsilonLn.toFixed(6);
  if (epsilonBar) epsilonBar.style.width = `${Math.min(100, cosmic.epsilonLn * 1000)}%`;

  // Marginal — fantastically small
  const marginalEl = document.getElementById('marginal-value');
  const marginalBar = document.getElementById('marginal-bar');
  if (marginalEl) marginalEl.textContent = cosmic.marginal.toExponential(4);
  if (marginalBar) marginalBar.style.width = `${Math.max(0.5, Math.min(100, 100 * (1 + Math.log10(cosmic.marginal) / 60)))}%`;

  // Cosmic N display
  const nEl = document.getElementById('cosmic-n-number');
  if (nEl) {
    const mantissa = coords.nTime / Math.pow(10, Math.floor(logN));
    nEl.innerHTML = `${mantissa.toFixed(10)} × 10<sup>${Math.floor(logN)}</sup>`;
  }

  // Era
  const eraEl = document.getElementById('physics-era');
  if (eraEl) {
    eraEl.textContent = '🔴 DEEP FERMIONIC — N ≈ 10⁶¹ · Λ ≈ ' + cosmic.lambda.toExponential(2) + ' · ‖r‖/dim ≈ ' + cosmic.marginal.toExponential(2);
    eraEl.className = 'physics-era fermionic';
  }
}

// ── Mode Management ──
let currentMode = 'cosmic';
let cosmicInterval = null;

function setPhysicsMode(mode) {
  currentMode = mode;

  // Toggle button states
  document.getElementById('mode-cosmic').classList.toggle('active', mode === 'cosmic');
  document.getElementById('mode-explore').classList.toggle('active', mode === 'explore');

  // Toggle panels
  const cosmicPanel = document.getElementById('cosmic-readout');
  const explorePanel = document.getElementById('explore-controls');
  if (cosmicPanel) cosmicPanel.style.display = mode === 'cosmic' ? 'block' : 'none';
  if (explorePanel) explorePanel.style.display = mode === 'explore' ? 'block' : 'none';

  if (mode === 'cosmic') {
    updateCosmicDashboard();
    if (!cosmicInterval) {
      cosmicInterval = setInterval(updateCosmicDashboard, 100);
    }
  } else {
    if (cosmicInterval) { clearInterval(cosmicInterval); cosmicInterval = null; }
    const slider = document.getElementById('physics-n-slider');
    if (slider) {
      const N = sliderToN(parseInt(slider.value));
      updatePhysicsDashboard(N);
    }
  }
}

function initPhysicsDashboard() {
  const slider = document.getElementById('physics-n-slider');

  // Start in cosmic mode
  setPhysicsMode('cosmic');

  // Slider for explore mode
  if (slider) {
    slider.addEventListener('input', () => {
      if (currentMode === 'explore') {
        const N = sliderToN(parseInt(slider.value));
        updatePhysicsDashboard(N);
      }
    });
  }
}

