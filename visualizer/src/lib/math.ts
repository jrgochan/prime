/**
 * Cathedral Math Library
 *
 * Pure TypeScript implementations of the core mathematical functions
 * used in the Vasyunin variational proof of the Riemann Hypothesis.
 */

const GAMMA = 0.5772156649015329;
const A_VAL = Math.log(2 * Math.PI) - GAMMA;

// ═══════════════════════════════════════════════
// Arithmetic Functions
// ═══════════════════════════════════════════════

/** Fractional part: {x} = x - floor(x) */
export function frac(x: number): number {
  return x - Math.floor(x);
}

export function gcd(a: number, b: number): number {
  while (b) { [a, b] = [b, a % b]; }
  return a;
}

export function mobiusSieve(N: number): Int8Array {
  const mu = new Int8Array(N + 1);
  mu[1] = 1;
  const isPrime = new Uint8Array(N + 1).fill(1);
  const primes: number[] = [];
  for (let i = 2; i <= N; i++) {
    if (isPrime[i]) { primes.push(i); mu[i] = -1; }
    for (const p of primes) {
      if (i * p > N) break;
      isPrime[i * p] = 0;
      if (i % p === 0) { mu[i * p] = 0; break; }
      else { mu[i * p] = -mu[i] as -1 | 0 | 1; }
    }
  }
  return mu;
}

// ═══════════════════════════════════════════════
// Vasyunin Formula — 4 Terms
// ═══════════════════════════════════════════════

export function vasyuninSum(a: number, b: number): number {
  if (a <= 1) return 0;
  let total = 0;
  for (let m = 1; m < a; m++) {
    const frac = (m * b % a) / a;
    total += frac / Math.tan(Math.PI * m / a);
  }
  return total;
}

export function gramTermRational(j: number, k: number): number {
  return A_VAL / 2 * (1/j + 1/k);
}

export function gramTermLog(j: number, k: number): number {
  if (j === k) return 0;
  return (j - k) / (2 * j * k) * Math.log(k / j);
}

export function gramTermCot(j: number, k: number): number {
  const d = gcd(j, k);
  const jp = j / d, kp = k / d;
  return -Math.PI * d / (2 * j * k) * (vasyuninSum(jp, kp) + vasyuninSum(kp, jp));
}

export function gramTermBase(j: number, k: number): number {
  return -1 / (j * k);
}

export function gramEntry(j: number, k: number): number {
  return gramTermRational(j, k) + gramTermLog(j, k) + gramTermCot(j, k) + gramTermBase(j, k);
}

export function meanEntry(k: number): number {
  return (Math.log(k) + 1 - GAMMA) / k;
}

export function covEntry(j: number, k: number): number {
  return gramEntry(j, k) - meanEntry(j) * meanEntry(k);
}

export function logCutoffWitness(k: number, N: number, mu: Int8Array): number {
  return -mu[k] * (1 - Math.log(k) / Math.log(N));
}

// ═══════════════════════════════════════════════
// Term metadata
// ═══════════════════════════════════════════════

export interface TermInfo {
  id: string;
  name: string;
  latex: string;
  color: string;
  bgColor: string;
  description: string;
  intuition: string;
  rank: string;
}

export const GRAM_TERMS: TermInfo[] = [
  {
    id: 'rational', name: 'Rational',
    latex: '\\frac{A}{2}\\left(\\frac{1}{j}+\\frac{1}{k}\\right)',
    color: '#f59e0b', bgColor: 'rgba(245,158,11,0.1)',
    description: 'The rational harmonic term. A = ln(2\u03c0) \u2212 \u03b3 \u2248 1.265.',
    intuition: 'Rank-2 separable. Killed by PNT as \u03a3\u03bc(k)/k \u2192 0.',
    rank: 'Rank 2',
  },
  {
    id: 'log', name: 'Logarithmic',
    latex: '\\frac{j-k}{2jk}\\ln\\frac{k}{j}',
    color: '#3b82f6', bgColor: 'rgba(59,130,246,0.1)',
    description: 'The logarithmic coupling between j and k.',
    intuition: 'Full-rank. Encodes multiplicative distance between integers.',
    rank: 'Full rank',
  },
  {
    id: 'cot', name: 'Cotangent',
    latex: "-\\frac{\\pi d}{2jk}\\bigl(V(j',k')+V(k',j')\\bigr)",
    color: '#8b5cf6', bgColor: 'rgba(139,92,246,0.1)',
    description: "The Vasyunin cotangent sum. d = gcd(j,k), j' = j/d.",
    intuition: 'Full-rank. The arithmetic heart: encodes prime factorization via gcd.',
    rank: 'Full rank',
  },
  {
    id: 'base', name: 'Base',
    latex: '-\\frac{1}{jk}',
    color: '#ef4444', bgColor: 'rgba(239,68,68,0.1)',
    description: 'The constant base correction.',
    intuition: 'Rank-1. Killed by PNT as \u03a3\u03bc(k)/k \u2192 0.',
    rank: 'Rank 1',
  },
];

export const CONSTANTS = { GAMMA, A: A_VAL };
