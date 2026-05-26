// ═══════════════════════════════════════════════════════
// PARTICLE ZOO DATA — Census results embedded
// ═══════════════════════════════════════════════════════

export interface CensusPoint {
  N: number;
  vtgv: number;
  gap: number;
  gapLn: number;
  diag: number;
  bos: number;
  fer: number;
  cancel: number;
  vacuum: number;
  higgs: number;
  quark: number;
  meson: number;
  baryon: number;
  tetra: number;
  penta: number;
  hexa: number;
}

export const CENSUS_DATA: CensusPoint[] = [
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

// ── Particle Type Definitions ─────────────────────────

export interface ParticleTypeDef {
  key: string;
  label: string;
  color: string;
  glowColor: string;
  desc: string;
  omega: number;     // number of distinct prime factors
  sign: '+' | '-';   // contribution sign to vᵀGv
}

export const PARTICLE_TYPES: ParticleTypeDef[] = [
  { key: 'vacuum', label: 'Vacuum',      color: '#8b5cf6', glowColor: '#a78bfa', desc: 'n = 1 — the ground state',           omega: 0, sign: '-' },
  { key: 'higgs',  label: 'Higgs',       color: '#f59e0b', glowColor: '#fbbf24', desc: 'n = 2 — the Z₂ parity flipper',      omega: 1, sign: '+' },
  { key: 'quark',  label: 'Quark',       color: '#ef4444', glowColor: '#f87171', desc: 'Primes (ω=1) — confined fermions',    omega: 1, sign: '+' },
  { key: 'meson',  label: 'Meson',       color: '#3b82f6', glowColor: '#60a5fa', desc: 'Semiprimes (ω=2) — bound states',     omega: 2, sign: '-' },
  { key: 'baryon', label: 'Baryon',      color: '#10b981', glowColor: '#34d399', desc: '3-primes (ω=3) — heavy hadrons',      omega: 3, sign: '+' },
  { key: 'tetra',  label: 'Tetraquark',  color: '#f97316', glowColor: '#fb923c', desc: '4-primes (ω=4) — exotic hadrons',     omega: 4, sign: '-' },
  { key: 'penta',  label: 'Pentaquark',  color: '#ec4899', glowColor: '#f472b6', desc: '5-primes (ω=5) — ultra-exotic',       omega: 5, sign: '+' },
  { key: 'hexa',   label: 'Hexaquark',   color: '#06b6d4', glowColor: '#22d3ee', desc: '6-primes (ω=6) — rarest matter',      omega: 6, sign: '-' },
  { key: 'excluded',label:'Excluded',    color: '#1e293b', glowColor: '#334155', desc: 'Non-squarefree (μ=0) — dark matter',   omega: -1, sign: '-' },
];

export const PARTICLE_COLOR_MAP: Record<string, string> = {};
PARTICLE_TYPES.forEach(p => { PARTICLE_COLOR_MAP[p.key] = p.color; });

// ── Integer Classification ────────────────────────────

/** Sieve primes up to n */
function sievePrimes(n: number): boolean[] {
  const is = new Array(n + 1).fill(true);
  is[0] = is[1] = false;
  for (let i = 2; i * i <= n; i++) {
    if (!is[i]) continue;
    for (let j = i * i; j <= n; j += i) is[j] = false;
  }
  return is;
}

/** Compute Möbius function table */
function mobiusTable(n: number): Int8Array {
  const mu = new Int8Array(n + 1);
  mu[1] = 1;
  const is = sievePrimes(n);
  const primes: number[] = [];
  for (let i = 2; i <= n; i++) if (is[i]) primes.push(i);

  // Initialize all as having mu = ±1
  const omega = new Uint8Array(n + 1); // distinct prime factors
  const sqfree = new Uint8Array(n + 1).fill(1);

  for (const p of primes) {
    for (let m = p; m <= n; m += p) {
      omega[m]++;
    }
    const p2 = p * p;
    for (let m = p2; m <= n; m += p2) {
      sqfree[m] = 0;
    }
  }

  for (let i = 1; i <= n; i++) {
    if (!sqfree[i]) {
      mu[i] = 0;
    } else {
      mu[i] = (omega[i] % 2 === 0) ? 1 : -1;
    }
  }

  return mu;
}

/** Compute small omega (distinct prime factors) table */
function omegaTable(n: number): Uint8Array {
  const omega = new Uint8Array(n + 1);
  const is = sievePrimes(n);
  for (let p = 2; p <= n; p++) {
    if (!is[p]) continue;
    for (let m = p; m <= n; m += p) omega[m]++;
  }
  return omega;
}

export type ParticleClass = 'vacuum' | 'higgs' | 'quark' | 'meson' | 'baryon' | 'tetra' | 'penta' | 'hexa' | 'excluded';

/** Classify a single integer */
function classifyOne(k: number, mu: number, omega: number): ParticleClass {
  if (k === 1) return 'vacuum';
  if (mu === 0) return 'excluded';
  if (k === 2) return 'higgs';
  switch (omega) {
    case 1: return 'quark';
    case 2: return 'meson';
    case 3: return 'baryon';
    case 4: return 'tetra';
    case 5: return 'penta';
    case 6: return 'hexa';
    default: return 'excluded';
  }
}

export interface IntegerParticle {
  k: number;
  type: ParticleClass;
  mu: number;
  omega: number;
}

/** Classify all integers 1..N */
export function classifyAll(N: number): IntegerParticle[] {
  const mu = mobiusTable(N);
  const omega = omegaTable(N);
  const particles: IntegerParticle[] = [];

  for (let k = 1; k <= N; k++) {
    particles.push({
      k,
      type: classifyOne(k, mu[k], omega[k]),
      mu: mu[k],
      omega: omega[k],
    });
  }

  return particles;
}

// ── Interpolation Helpers ─────────────────────────────

/** Find the census bracket for a given N and interpolate, or extrapolate beyond data */
export function interpolateCensus(N: number): CensusPoint & { extrapolated: boolean } {
  if (N <= CENSUS_DATA[0].N) return { ...CENSUS_DATA[0], extrapolated: false };

  // Within data range: interpolate
  if (N <= CENSUS_DATA[CENSUS_DATA.length - 1].N) {
    let lo = 0, hi = CENSUS_DATA.length - 1;
    for (let i = 0; i < CENSUS_DATA.length - 1; i++) {
      if (CENSUS_DATA[i].N <= N && CENSUS_DATA[i + 1].N > N) {
        lo = i; hi = i + 1; break;
      }
    }
    const a = CENSUS_DATA[lo], b = CENSUS_DATA[hi];
    const t = (Math.log(N) - Math.log(a.N)) / (Math.log(b.N) - Math.log(a.N));
    const lerp = (x: number, y: number) => x + (y - x) * t;
    return {
      N, extrapolated: false,
      vtgv: lerp(a.vtgv, b.vtgv), gap: lerp(a.gap, b.gap),
      gapLn: lerp(a.gapLn, b.gapLn), diag: lerp(a.diag, b.diag),
      bos: lerp(a.bos, b.bos), fer: lerp(a.fer, b.fer),
      cancel: lerp(a.cancel, b.cancel), vacuum: lerp(a.vacuum, b.vacuum),
      higgs: lerp(a.higgs, b.higgs), quark: lerp(a.quark, b.quark),
      meson: lerp(a.meson, b.meson), baryon: lerp(a.baryon, b.baryon),
      tetra: lerp(a.tetra, b.tetra), penta: lerp(a.penta, b.penta),
      hexa: lerp(a.hexa, b.hexa),
    };
  }

  // Beyond data: EXTRAPOLATE using fitted asymptotic trends
  // Core: gap·ln(N) → K ≈ 2.9 (observed approaching from below)
  const lnN = Math.log(N);
  const K = 2.9; // asymptotic constant
  const gapLn = K - (K - 2.876) * Math.exp(-(lnN - Math.log(55440)) * 0.3);
  const gap = gapLn / lnN;
  const vtgv = 1 - gap;

  // Diagonal grows as ~C·ln(N)
  const diag = 2.648 * (lnN / Math.log(55440));

  // Bos/Fer grow roughly linearly with N, cancellation → 100%
  const nRatio = N / 55440;
  const bos = 921.16 * nRatio;
  const fer = -923.07 * nRatio;
  const cancel = Math.min(99.99, 99.8 + 0.2 * (1 - Math.exp(-Math.log(nRatio))));

  // Individual contributions: fit from last few data points via ln(N) scaling
  const lnRatio = lnN / Math.log(55440);
  const vacuum = -0.354 * lnRatio;
  const higgs = 0.448 * lnRatio;
  const quark = 3.852 * lnRatio;
  const meson = -4.887 * lnRatio;
  const baryon = 1.967 * lnRatio;
  const tetra = -0.304 * lnRatio;
  const penta = 0.014 * Math.pow(lnRatio, 2);
  const hexa = -0.00003 * Math.pow(lnRatio, 3);

  return {
    N, extrapolated: true,
    vtgv, gap, gapLn, diag, bos, fer, cancel,
    vacuum, higgs, quark, meson, baryon, tetra, penta, hexa,
  };
}

// ── Journey milestones ────────────────────────────────

export interface Milestone {
  N: number;
  label: string;
  desc: string;
  color: string;
}

export const MILESTONES: Milestone[] = [
  { N: 30,    label: 'First Baryon',     desc: '30 = 2·3·5 — the first integer with 3 distinct prime factors', color: '#10b981' },
  { N: 2520,  label: 'Hadron Epoch',     desc: 'Mesons overtake quarks — lcm(1..10)', color: '#f59e0b' },
  { N: 2310,  label: 'First Pentaquark', desc: '2310 = 2·3·5·7·11 — 5 distinct prime factors', color: '#ec4899' },
  { N: 5040,  label: '99% SUSY',         desc: 'Bosonic/Fermionic cancellation exceeds 99%', color: '#a78bfa' },
  { N: 30030, label: 'First Hexaquark',  desc: '30030 = 2·3·5·7·11·13 — 6 distinct prime factors', color: '#06b6d4' },
  { N: 55440, label: 'Census Peak',      desc: 'Maximum observed N — 55,439 particles classified', color: '#f1f5f9' },
];
