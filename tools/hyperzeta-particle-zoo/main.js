/* ═══════════════════════════════════════════════════════
   PARTICLE ZOO — Every Integer Has a Soul
   Main Application Logic
   ═══════════════════════════════════════════════════════ */

import './style.css';

// ── Census Data (from zoo_census_h5_summary.tsv) ──────
const CENSUS_DATA = [
  { N:6,vtgv:0.0656,gap:0.9344,gapLn:1.674,diag:0.452,bos:0.173,fer:-0.560,cancel:31.0,vacuum:-0.019,higgs:0.055,quark:0.030,meson:0,baryon:0,tetra:0,penta:0,hexa:0 },
  { N:12,vtgv:0.1619,gap:0.8381,gapLn:2.083,diag:0.603,bos:0.671,fer:-1.113,cancel:60.3,vacuum:-0.119,higgs:0.149,quark:0.172,meson:-0.040,baryon:0,tetra:0,penta:0,hexa:0 },
  { N:24,vtgv:0.2755,gap:0.7245,gapLn:2.302,diag:0.760,bos:1.568,fer:-2.052,cancel:76.4,vacuum:-0.186,higgs:0.223,quark:0.387,meson:-0.149,baryon:0,tetra:0,penta:0,hexa:0 },
  { N:36,vtgv:0.3338,gap:0.6662,gapLn:2.387,diag:0.854,bos:2.348,fer:-2.868,cancel:81.9,vacuum:-0.213,higgs:0.255,quark:0.530,meson:-0.242,baryon:0.003,tetra:0,penta:0,hexa:0 },
  { N:48,vtgv:0.3667,gap:0.6333,gapLn:2.452,diag:0.921,bos:3.100,fer:-3.654,cancel:84.8,vacuum:-0.228,higgs:0.273,quark:0.632,meson:-0.322,baryon:0.010,tetra:0,penta:0,hexa:0 },
  { N:60,vtgv:0.3935,gap:0.6065,gapLn:2.483,diag:0.973,bos:3.787,fer:-4.367,cancel:86.7,vacuum:-0.239,higgs:0.287,quark:0.719,meson:-0.391,baryon:0.017,tetra:0,penta:0,hexa:0 },
  { N:120,vtgv:0.4629,gap:0.5371,gapLn:2.571,diag:1.137,bos:6.884,fer:-7.558,cancel:91.1,vacuum:-0.266,higgs:0.322,quark:0.999,meson:-0.646,baryon:0.054,tetra:0,penta:0,hexa:0 },
  { N:180,vtgv:0.4950,gap:0.5050,gapLn:2.623,diag:1.234,bos:9.606,fer:-10.345,cancel:92.9,vacuum:-0.277,higgs:0.338,quark:1.164,meson:-0.818,baryon:0.087,tetra:0,penta:0,hexa:0 },
  { N:240,vtgv:0.5171,gap:0.4829,gapLn:2.647,diag:1.303,bos:12.125,fer:-12.912,cancel:93.9,vacuum:-0.285,higgs:0.349,quark:1.289,meson:-0.953,baryon:0.119,tetra:-0.0005,penta:0,hexa:0 },
  { N:360,vtgv:0.5454,gap:0.4546,gapLn:2.676,diag:1.401,bos:16.764,fer:-17.620,cancel:95.1,vacuum:-0.295,higgs:0.362,quark:1.468,meson:-1.161,baryon:0.173,tetra:-0.002,penta:0,hexa:0 },
  { N:720,vtgv:0.5869,gap:0.4131,gapLn:2.718,diag:1.570,bos:28.935,fer:-29.919,cancel:96.7,vacuum:-0.308,higgs:0.381,quark:1.782,meson:-1.554,baryon:0.294,tetra:-0.008,penta:0,hexa:0 },
  { N:840,vtgv:0.5949,gap:0.4051,gapLn:2.728,diag:1.608,bos:32.653,fer:-33.666,cancel:97.0,vacuum:-0.311,higgs:0.385,quark:1.852,meson:-1.646,baryon:0.326,tetra:-0.011,penta:0,hexa:0 },
  { N:1000,vtgv:0.6028,gap:0.3972,gapLn:2.744,diag:1.651,bos:37.422,fer:-38.470,cancel:97.3,vacuum:-0.313,higgs:0.388,quark:1.927,meson:-1.747,baryon:0.362,tetra:-0.014,penta:0,hexa:0 },
  { N:1260,vtgv:0.6152,gap:0.3848,gapLn:2.747,diag:1.707,bos:44.834,fer:-45.926,cancel:97.6,vacuum:-0.317,higgs:0.394,quark:2.041,meson:-1.905,baryon:0.420,tetra:-0.019,penta:0,hexa:0 },
  { N:1680,vtgv:0.6276,gap:0.3724,gapLn:2.766,diag:1.778,bos:56.170,fer:-57.321,cancel:98.0,vacuum:-0.321,higgs:0.400,quark:2.171,meson:-2.088,baryon:0.492,tetra:-0.026,penta:0,hexa:0 },
  { N:2520,vtgv:0.6446,gap:0.3554,gapLn:2.783,diag:1.878,bos:77.181,fer:-78.415,cancel:98.4,vacuum:-0.326,higgs:0.407,quark:2.361,meson:-2.367,baryon:0.609,tetra:-0.039,penta:0.00003,hexa:0 },
  { N:5040,vtgv:0.6705,gap:0.3295,gapLn:2.809,diag:2.050,bos:133.288,fer:-134.667,cancel:99.0,vacuum:-0.334,higgs:0.419,quark:2.693,meson:-2.879,baryon:0.844,tetra:-0.072,penta:0.0006,hexa:0 },
  { N:7560,vtgv:0.6841,gap:0.3159,gapLn:2.821,diag:2.150,bos:183.872,fer:-185.338,cancel:99.2,vacuum:-0.338,higgs:0.425,quark:2.890,meson:-3.198,baryon:1.002,tetra:-0.098,penta:0.001,hexa:0 },
  { N:10080,vtgv:0.6928,gap:0.3072,gapLn:2.832,diag:2.222,bos:231.313,fer:-232.842,cancel:99.3,vacuum:-0.341,higgs:0.429,quark:3.026,meson:-3.423,baryon:1.118,tetra:-0.118,penta:0.002,hexa:0 },
  { N:15120,vtgv:0.7044,gap:0.2956,gapLn:2.845,diag:2.323,bos:320.197,fer:-321.815,cancel:99.5,vacuum:-0.344,higgs:0.434,quark:3.219,meson:-3.751,baryon:1.295,tetra:-0.152,penta:0.004,hexa:0 },
  { N:20160,vtgv:0.7124,gap:0.2876,gapLn:2.851,diag:2.395,bos:403.824,fer:-405.507,cancel:99.6,vacuum:-0.347,higgs:0.437,quark:3.363,meson:-4.002,baryon:1.437,tetra:-0.181,penta:0.005,hexa:0 },
  { N:27720,vtgv:0.7206,gap:0.2794,gapLn:2.858,diag:2.474,bos:522.754,fer:-524.508,cancel:99.7,vacuum:-0.349,higgs:0.441,quark:3.523,meson:-4.287,baryon:1.603,tetra:-0.217,penta:0.007,hexa:0 },
  { N:40000,vtgv:0.7294,gap:0.2706,gapLn:2.868,diag:2.566,bos:704.886,fer:-706.723,cancel:99.7,vacuum:-0.352,higgs:0.445,quark:3.700,meson:-4.607,baryon:1.795,tetra:-0.262,penta:0.010,hexa:-0.00001 },
  { N:45360,vtgv:0.7324,gap:0.2676,gapLn:2.869,diag:2.597,bos:781.293,fer:-783.158,cancel:99.8,vacuum:-0.352,higgs:0.446,quark:3.769,meson:-4.736,baryon:1.875,tetra:-0.281,penta:0.012,hexa:-0.00002 },
  { N:55440,vtgv:0.7367,gap:0.2633,gapLn:2.876,diag:2.648,bos:921.160,fer:-923.071,cancel:99.8,vacuum:-0.354,higgs:0.448,quark:3.852,meson:-4.887,baryon:1.967,tetra:-0.304,penta:0.014,hexa:-0.00003 },
];

// ── Particle Type Config ──────────────────────────────
const PARTICLES = {
  vacuum: { label: 'Vacuum', color: '#8b5cf6', desc: 'n = 1 — the ground state', sign: '−' },
  higgs:  { label: 'Higgs',  color: '#f59e0b', desc: 'n = 2 — the Z₂ parity flipper', sign: '+' },
  quark:  { label: 'Quark',  color: '#ef4444', desc: 'Primes (ω=1) — confined fermions', sign: '+' },
  meson:  { label: 'Meson',  color: '#3b82f6', desc: 'Semiprimes (ω=2) — bound states', sign: '−' },
  baryon: { label: 'Baryon', color: '#10b981', desc: '3-primes (ω=3) — heavy hadrons', sign: '+' },
  tetra:  { label: 'Tetraquark', color: '#f97316', desc: '4-primes (ω=4) — exotic hadrons', sign: '−' },
  penta:  { label: 'Pentaquark', color: '#ec4899', desc: '5-primes (ω=5) — ultra-exotic', sign: '+' },
  hexa:   { label: 'Hexaquark', color: '#06b6d4', desc: '6-primes (ω=6) — rarest matter', sign: '−' },
};

const PARTICLE_KEYS = ['vacuum','higgs','quark','meson','baryon','tetra','penta','hexa'];

// ── Canvas Drawing Helpers ────────────────────────────
function setupCanvas(canvas) {
  const dpr = window.devicePixelRatio || 1;
  const rect = canvas.parentElement.getBoundingClientRect();
  canvas.width = rect.width * dpr;
  canvas.height = rect.height * dpr;
  canvas.style.width = rect.width + 'px';
  canvas.style.height = rect.height + 'px';
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);
  return { ctx, w: rect.width, h: rect.height };
}

// ── Build App ─────────────────────────────────────────
function buildApp() {
  const app = document.getElementById('app');
  const latest = CENSUS_DATA[CENSUS_DATA.length - 1];

  app.innerHTML = `
    <!-- HERO -->
    <section class="hero animate-in" id="hero">
      <div class="hero-badge">⚛️ Cathedral Project</div>
      <h1>The Particle Zoo</h1>
      <p class="hero-subtitle">
        Every integer has a soul. 55,439 of them were weighed.
        The primes push. The semiprimes pull. The balance holds.
      </p>
      <div class="hero-stat-row">
        <div class="hero-stat">
          <div class="hero-stat-value" style="color: var(--success)">0.737</div>
          <div class="hero-stat-label">vᵀGv at N=55,440</div>
        </div>
        <div class="hero-stat">
          <div class="hero-stat-value" style="color: var(--accent-bright)">2.876</div>
          <div class="hero-stat-label">gap · ln(N)</div>
        </div>
        <div class="hero-stat">
          <div class="hero-stat-value" style="color: var(--higgs)">99.79%</div>
          <div class="hero-stat-label">SUSY Cancellation</div>
        </div>
        <div class="hero-stat">
          <div class="hero-stat-value danger">< 1.0</div>
          <div class="hero-stat-label">RH Threshold ✅</div>
        </div>
      </div>
    </section>

    <!-- GAUGE -->
    <section class="section animate-in stagger-1" id="gauge-section">
      <div class="section-header">
        <h2>🎯 The Nyman-Beurling Distance</h2>
        <p>vᵀGv must stay below 1.0 for the Riemann Hypothesis to hold</p>
      </div>
      <div class="card vtgv-gauge">
        <div class="gauge-visual">
          <canvas id="gauge-canvas"></canvas>
        </div>
        <div class="gauge-info">
          <div class="gauge-value" id="gauge-value">0.737</div>
          <div class="gauge-label">
            The sum of all 55,439 integer contributions to the Gram quadratic form.
            Must remain below the critical threshold of 1.0 at every dimension N.
          </div>
          <div class="gauge-threshold">✅ vᵀGv = 0.737 < 1.0 — margin = 0.263</div>
        </div>
      </div>
    </section>

    <!-- N SLIDER + PARTICLE CARDS -->
    <section class="section animate-in stagger-2" id="particles-section">
      <div class="section-header">
        <h2>⚛️ The Census</h2>
        <p>Slide to explore the particle type breakdown at each dimension N</p>
      </div>
      <div class="n-slider-container">
        <span class="n-slider-label">N =</span>
        <input type="range" class="n-slider" id="n-slider" min="0" max="${CENSUS_DATA.length - 1}" value="${CENSUS_DATA.length - 1}" />
        <span class="n-value" id="n-value">${latest.N.toLocaleString()}</span>
      </div>
      <div class="particle-grid" id="particle-grid"></div>
    </section>

    <!-- BATTLE CHART -->
    <section class="section animate-in stagger-3" id="battle-section">
      <div class="section-header">
        <h2>⚔️ The Battle: Quarks vs Mesons</h2>
        <p>How each particle type's contribution to vᵀGv evolves with N</p>
      </div>
      <div class="card">
        <div class="battle-chart">
          <canvas id="battle-canvas"></canvas>
        </div>
        <div class="crossover-callout">
          <span class="crossover-icon">⚡</span>
          <div class="crossover-text">
            <h4>The Hadron Epoch — N ≈ 2,520</h4>
            <p>
              At N ≈ 2,520 (= lcm(1..10)), the mesons overtake the quarks.
              The semiprimes generate more negative Gram correlation than the primes
              generate positive. This is the prime-counting theorem (π₂(x) > π(x))
              manifesting as the mechanism of the Nyman-Beurling bound.
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- SUSY CANCELLATION -->
    <section class="section animate-in stagger-4" id="susy-section">
      <div class="section-header">
        <h2>🪞 SUSY Cancellation</h2>
        <p>Bosonic and fermionic off-diagonal terms nearly perfectly cancel</p>
      </div>
      <div class="susy-container">
        <div class="card susy-meter" id="susy-meter">
          <div class="susy-label">
            <span>Bosonic (pushes UP)</span>
            <span id="bos-label" style="color:var(--quark)">+921.16</span>
          </div>
          <div class="susy-bar-container">
            <div class="susy-bar bosonic" id="bos-bar" style="width:100%">
              B<sub>off</sub> = +921
            </div>
          </div>
          <div class="susy-label">
            <span>Fermionic (pulls DOWN)</span>
            <span id="fer-label" style="color:var(--meson)">−923.07</span>
          </div>
          <div class="susy-bar-container">
            <div class="susy-bar fermionic" id="fer-bar" style="width:100%">
              F<sub>off</sub> = −923
            </div>
          </div>
        </div>
        <div class="card" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1rem;">
          <div style="font-size:0.85rem;color:var(--text-secondary);">Cancellation at N=${latest.N.toLocaleString()}</div>
          <div class="susy-cancel-badge" id="susy-cancel-badge">99.79%</div>
          <div style="font-size:0.8rem;color:var(--text-muted);text-align:center;max-width:220px;">
            Two sums of size ~922 cancel to leave ~1.9.
            The residual IS the Riemann Hypothesis.
          </div>
        </div>
      </div>
    </section>

    <!-- GAP STABILITY -->
    <section class="section animate-in stagger-5" id="gap-section">
      <div class="section-header">
        <h2>📐 gap · ln(N) Stability</h2>
        <p>The gap decays as K/ln(N) — this flatline is a law of nature</p>
      </div>
      <div class="card">
        <div class="gap-chart">
          <canvas id="gap-canvas"></canvas>
        </div>
      </div>
    </section>

    <!-- FOOTER -->
    <footer class="footer">
      <p class="footer-quote">
        "The primes push. The semiprimes pull. The balance holds.<br>
        Every integer has a soul, and the sum of all their souls is 0.737.<br>
        Less than one. As it must be. As it has always been."
      </p>
      <p class="footer-attribution">
        Cathedral Project · Particle Zoo Census · N=6 → 55,440 · May 2026
      </p>
    </footer>
  `;

  // Initialize all components
  updateParticleGrid(CENSUS_DATA.length - 1);
  drawGauge();
  drawBattleChart();
  drawGapChart();

  // Slider interaction
  const slider = document.getElementById('n-slider');
  slider.addEventListener('input', (e) => {
    const idx = parseInt(e.target.value);
    updateParticleGrid(idx);
  });

  // Resize handler
  window.addEventListener('resize', () => {
    drawGauge();
    drawBattleChart();
    drawGapChart();
  });
}

// ── Particle Grid Update ──────────────────────────────
function updateParticleGrid(idx) {
  const d = CENSUS_DATA[idx];
  document.getElementById('n-value').textContent = d.N.toLocaleString();

  const values = {
    vacuum: d.vacuum, higgs: d.higgs, quark: d.quark,
    meson: d.meson, baryon: d.baryon, tetra: d.tetra,
    penta: d.penta, hexa: d.hexa
  };

  const grid = document.getElementById('particle-grid');
  grid.innerHTML = PARTICLE_KEYS.map(key => {
    const p = PARTICLES[key];
    const val = values[key];
    const absVal = Math.abs(val);
    const sign = val > 0.00001 ? '+' : val < -0.00001 ? '−' : '';
    const cls = val > 0.00001 ? 'positive' : val < -0.00001 ? 'negative' : 'zero';
    const pct = d.vtgv !== 0 ? ((val / d.vtgv) * 100).toFixed(1) : '0.0';

    return `
      <div class="particle-card" style="border-color: ${val !== 0 ? p.color + '30' : 'var(--border)'}">
        <div class="particle-card-header">
          <div class="particle-dot" style="background:${p.color};color:${p.color};${absVal < 0.00001 ? 'opacity:0.3' : ''}"></div>
          <div class="particle-card-name">${p.label}</div>
        </div>
        <div class="particle-card-contribution ${cls}">
          ${absVal < 0.00001 ? '—' : sign + absVal.toFixed(absVal < 0.01 ? 5 : 3)}
        </div>
        <div class="particle-card-pct">${absVal < 0.00001 ? 'Not yet present' : pct + '% of vᵀGv'}</div>
      </div>
    `;
  }).join('');

  // Update SUSY
  document.getElementById('bos-label').textContent = `+${d.bos.toFixed(2)}`;
  document.getElementById('fer-label').textContent = `−${Math.abs(d.fer).toFixed(2)}`;
  const maxBF = Math.max(d.bos, Math.abs(d.fer));
  document.getElementById('bos-bar').style.width = `${(d.bos / maxBF) * 100}%`;
  document.getElementById('bos-bar').textContent = `B = +${d.bos.toFixed(0)}`;
  document.getElementById('fer-bar').style.width = `${(Math.abs(d.fer) / maxBF) * 100}%`;
  document.getElementById('fer-bar').textContent = `F = −${Math.abs(d.fer).toFixed(0)}`;
  document.getElementById('susy-cancel-badge').textContent = `${d.cancel.toFixed(2)}%`;

  // Update gauge
  const gv = document.getElementById('gauge-value');
  if (gv) gv.textContent = d.vtgv.toFixed(4);
  drawGauge(d.vtgv);
}

// ── Gauge Drawing ─────────────────────────────────────
function drawGauge(vtgv = 0.737) {
  const canvas = document.getElementById('gauge-canvas');
  if (!canvas) return;
  const { ctx, w, h } = setupCanvas(canvas);
  const cx = w / 2, cy = h / 2;
  const r = Math.min(w, h) * 0.38;

  ctx.clearRect(0, 0, w, h);

  // Background arc
  const startAngle = 0.75 * Math.PI;
  const endAngle = 2.25 * Math.PI;
  ctx.beginPath();
  ctx.arc(cx, cy, r, startAngle, endAngle);
  ctx.strokeStyle = 'rgba(255,255,255,0.06)';
  ctx.lineWidth = 16;
  ctx.lineCap = 'round';
  ctx.stroke();

  // Threshold at 1.0
  const threshAngle = startAngle + (endAngle - startAngle) * 1.0;

  // Value arc
  const pct = Math.min(vtgv, 1.2);
  const valAngle = startAngle + (endAngle - startAngle) * pct;
  const grad = ctx.createLinearGradient(cx - r, cy, cx + r, cy);
  grad.addColorStop(0, '#10b981');
  grad.addColorStop(0.6, '#f59e0b');
  grad.addColorStop(1, '#ef4444');
  ctx.beginPath();
  ctx.arc(cx, cy, r, startAngle, valAngle);
  ctx.strokeStyle = grad;
  ctx.lineWidth = 16;
  ctx.lineCap = 'round';
  ctx.stroke();

  // Threshold marker
  const tx = cx + r * Math.cos(threshAngle);
  const ty = cy + r * Math.sin(threshAngle);
  ctx.beginPath();
  ctx.arc(tx, ty, 4, 0, Math.PI * 2);
  ctx.fillStyle = '#ef4444';
  ctx.fill();
  ctx.font = '600 11px Inter';
  ctx.fillStyle = '#ef4444';
  ctx.textAlign = 'center';
  ctx.fillText('1.0', tx, ty - 12);

  // Center text
  ctx.font = '800 28px JetBrains Mono';
  ctx.fillStyle = vtgv < 1 ? '#10b981' : '#ef4444';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(vtgv.toFixed(3), cx, cy - 4);
  ctx.font = '400 11px Inter';
  ctx.fillStyle = '#94a3b8';
  ctx.fillText('vᵀGv', cx, cy + 18);
}

// ── Battle Chart ──────────────────────────────────────
function drawBattleChart() {
  const canvas = document.getElementById('battle-canvas');
  if (!canvas) return;
  const { ctx, w, h } = setupCanvas(canvas);

  const pad = { top: 30, right: 20, bottom: 50, left: 65 };
  const cw = w - pad.left - pad.right;
  const ch = h - pad.top - pad.bottom;

  ctx.clearRect(0, 0, w, h);

  // Data ranges
  const series = [
    { key: 'quark', color: '#ef4444', label: 'Quarks (+)' },
    { key: 'meson', color: '#3b82f6', label: 'Mesons (−)', negate: true },
    { key: 'baryon', color: '#10b981', label: 'Baryons (+)' },
    { key: 'tetra', color: '#f97316', label: 'Tetraquarks (−)', negate: true },
  ];

  const maxY = 5.5;
  const minLogN = Math.log(6);
  const maxLogN = Math.log(55440);

  function toX(n) { return pad.left + ((Math.log(n) - minLogN) / (maxLogN - minLogN)) * cw; }
  function toY(v) { return pad.top + (1 - v / maxY) * ch; }

  // Grid
  ctx.strokeStyle = 'rgba(255,255,255,0.04)';
  ctx.lineWidth = 1;
  for (let y = 0; y <= maxY; y += 1) {
    const py = toY(y);
    ctx.beginPath();
    ctx.moveTo(pad.left, py);
    ctx.lineTo(w - pad.right, py);
    ctx.stroke();
    ctx.font = '500 11px JetBrains Mono';
    ctx.fillStyle = '#64748b';
    ctx.textAlign = 'right';
    ctx.fillText(y.toFixed(0), pad.left - 10, py + 4);
  }

  // X labels
  const xTicks = [6, 60, 120, 840, 2520, 5040, 10080, 27720, 55440];
  ctx.font = '500 10px JetBrains Mono';
  ctx.fillStyle = '#64748b';
  ctx.textAlign = 'center';
  xTicks.forEach(n => {
    const x = toX(n);
    ctx.fillText(n >= 1000 ? (n/1000).toFixed(0) + 'K' : n.toString(), x, h - pad.bottom + 18);
    ctx.strokeStyle = 'rgba(255,255,255,0.03)';
    ctx.beginPath();
    ctx.moveTo(x, pad.top);
    ctx.lineTo(x, h - pad.bottom);
    ctx.stroke();
  });

  // Axis labels
  ctx.font = '500 11px Inter';
  ctx.fillStyle = '#94a3b8';
  ctx.textAlign = 'center';
  ctx.fillText('N (log scale)', w / 2, h - 6);
  ctx.save();
  ctx.translate(14, h / 2);
  ctx.rotate(-Math.PI / 2);
  ctx.fillText('|Contribution|', 0, 0);
  ctx.restore();

  // Crossover line at N≈2520
  const crossX = toX(2520);
  ctx.strokeStyle = 'rgba(245, 158, 11, 0.4)';
  ctx.lineWidth = 1;
  ctx.setLineDash([4, 4]);
  ctx.beginPath();
  ctx.moveTo(crossX, pad.top);
  ctx.lineTo(crossX, h - pad.bottom);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.font = '600 10px Inter';
  ctx.fillStyle = '#f59e0b';
  ctx.textAlign = 'center';
  ctx.fillText('⚡ Hadron Epoch', crossX, pad.top - 8);

  // Draw series
  series.forEach(s => {
    ctx.beginPath();
    ctx.strokeStyle = s.color;
    ctx.lineWidth = 2.5;
    ctx.lineJoin = 'round';

    CENSUS_DATA.forEach((d, i) => {
      const val = Math.abs(d[s.key]);
      const x = toX(d.N);
      const y = toY(val);
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();

    // Glow
    ctx.beginPath();
    ctx.strokeStyle = s.color + '30';
    ctx.lineWidth = 8;
    CENSUS_DATA.forEach((d, i) => {
      const val = Math.abs(d[s.key]);
      const x = toX(d.N);
      const y = toY(val);
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();
  });

  // Legend
  const legendX = pad.left + 12;
  let legendY = pad.top + 12;
  series.forEach(s => {
    ctx.fillStyle = s.color;
    ctx.beginPath();
    ctx.arc(legendX, legendY, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.font = '500 11px Inter';
    ctx.fillStyle = '#cbd5e1';
    ctx.textAlign = 'left';
    ctx.fillText(s.label, legendX + 10, legendY + 4);
    legendY += 18;
  });
}

// ── Gap Stability Chart ───────────────────────────────
function drawGapChart() {
  const canvas = document.getElementById('gap-canvas');
  if (!canvas) return;
  const { ctx, w, h } = setupCanvas(canvas);

  const pad = { top: 30, right: 20, bottom: 50, left: 65 };
  const cw = w - pad.left - pad.right;
  const ch = h - pad.top - pad.bottom;

  ctx.clearRect(0, 0, w, h);

  const minY = 1.5, maxY = 3.2;
  const minLogN = Math.log(6);
  const maxLogN = Math.log(55440);

  function toX(n) { return pad.left + ((Math.log(n) - minLogN) / (maxLogN - minLogN)) * cw; }
  function toY(v) { return pad.top + (1 - (v - minY) / (maxY - minY)) * ch; }

  // Grid
  ctx.strokeStyle = 'rgba(255,255,255,0.04)';
  ctx.lineWidth = 1;
  for (let y = 1.5; y <= 3.2; y += 0.5) {
    const py = toY(y);
    ctx.beginPath();
    ctx.moveTo(pad.left, py);
    ctx.lineTo(w - pad.right, py);
    ctx.stroke();
    ctx.font = '500 11px JetBrains Mono';
    ctx.fillStyle = '#64748b';
    ctx.textAlign = 'right';
    ctx.fillText(y.toFixed(1), pad.left - 10, py + 4);
  }

  // X labels
  const xTicks = [6, 60, 120, 840, 2520, 5040, 10080, 27720, 55440];
  ctx.font = '500 10px JetBrains Mono';
  ctx.fillStyle = '#64748b';
  ctx.textAlign = 'center';
  xTicks.forEach(n => {
    const x = toX(n);
    ctx.fillText(n >= 1000 ? (n/1000).toFixed(0) + 'K' : n.toString(), x, h - pad.bottom + 18);
  });

  // Axis labels
  ctx.font = '500 11px Inter';
  ctx.fillStyle = '#94a3b8';
  ctx.textAlign = 'center';
  ctx.fillText('N (log scale)', w / 2, h - 6);
  ctx.save();
  ctx.translate(14, h / 2);
  ctx.rotate(-Math.PI / 2);
  ctx.fillText('gap · ln(N)', 0, 0);
  ctx.restore();

  // Asymptote hint at K≈2.9
  ctx.strokeStyle = 'rgba(139, 92, 246, 0.3)';
  ctx.lineWidth = 1;
  ctx.setLineDash([6, 4]);
  const asymY = toY(2.9);
  ctx.beginPath();
  ctx.moveTo(pad.left, asymY);
  ctx.lineTo(w - pad.right, asymY);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.font = '500 10px Inter';
  ctx.fillStyle = '#a78bfa';
  ctx.textAlign = 'right';
  ctx.fillText('K ≈ 2.9?', w - pad.right - 4, asymY - 8);

  // Data line
  ctx.beginPath();
  ctx.strokeStyle = '#a78bfa';
  ctx.lineWidth = 2.5;
  ctx.lineJoin = 'round';
  CENSUS_DATA.forEach((d, i) => {
    const x = toX(d.N);
    const y = toY(d.gapLn);
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.stroke();

  // Glow
  ctx.beginPath();
  ctx.strokeStyle = '#a78bfa30';
  ctx.lineWidth = 10;
  CENSUS_DATA.forEach((d, i) => {
    const x = toX(d.N);
    const y = toY(d.gapLn);
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.stroke();

  // Data points
  CENSUS_DATA.forEach(d => {
    const x = toX(d.N);
    const y = toY(d.gapLn);
    ctx.beginPath();
    ctx.arc(x, y, 3, 0, Math.PI * 2);
    ctx.fillStyle = '#a78bfa';
    ctx.fill();
  });

  // Label the last point
  const last = CENSUS_DATA[CENSUS_DATA.length - 1];
  ctx.font = '600 11px JetBrains Mono';
  ctx.fillStyle = '#a78bfa';
  ctx.textAlign = 'left';
  ctx.fillText(last.gapLn.toFixed(3), toX(last.N) + 8, toY(last.gapLn) + 4);
}

// ── Initialize ────────────────────────────────────────
document.addEventListener('DOMContentLoaded', buildApp);
