import * as THREE from 'three';

// ──────────────────────────────────────────────
// Color map definitions
// ──────────────────────────────────────────────

export type ColorMode = 'magnitude' | 'gcd' | 'prime' | 'sign' | 'diagonal';

export interface GramPoint {
  j: number;
  k: number;
  v: number;  // G(j,k) value
  g: number;  // gcd(j,k)
  p: number;  // prime flag: 0=neither, 1=one prime, 2=both prime
}

/**
 * Inferno color map — perceptually uniform, dark-to-bright.
 * Approximation of matplotlib's inferno.
 */
function inferno(t: number): [number, number, number] {
  // Clamp
  t = Math.max(0, Math.min(1, t));

  // Piecewise linear approximation of inferno
  const r = Math.min(1, Math.max(0,
    t < 0.25 ? t * 1.2
    : t < 0.55 ? 0.3 + (t - 0.25) * 2.67
    : t < 0.8 ? 1.0 - (t - 0.8) * 0.5
    : 0.99
  ));

  const g = Math.min(1, Math.max(0,
    t < 0.3 ? t * 0.1
    : t < 0.7 ? (t - 0.3) * 1.5
    : 0.6 + (t - 0.7) * 1.33
  ));

  const b = Math.min(1, Math.max(0,
    t < 0.15 ? t * 2.0
    : t < 0.4 ? 0.3 + (t - 0.15) * 1.2
    : t < 0.65 ? 0.6 - (t - 0.4) * 2.0
    : (t - 0.65) * 0.5
  ));

  return [r, g, b];
}

/**
 * Map a normalized value [0,1] to inferno color.
 */
function valueToInferno(value: number, min: number, max: number): THREE.Color {
  const range = max - min;
  const t = range > 0 ? (value - min) / range : 0.5;
  const [r, g, b] = inferno(t);
  return new THREE.Color(r, g, b);
}

/**
 * Map GCD to a cyclic hue.
 */
function gcdToColor(gcd: number): THREE.Color {
  const hue = (gcd * 0.618033988749895) % 1.0; // golden ratio spacing
  return new THREE.Color().setHSL(hue, 0.85, 0.55);
}

/**
 * Map prime flag to color.
 */
function primeToColor(primeFlag: number): THREE.Color {
  switch (primeFlag) {
    case 2: return new THREE.Color(1.0, 0.85, 0.1);   // both prime: gold
    case 1: return new THREE.Color(0.3, 0.8, 1.0);     // one prime: cyan
    default: return new THREE.Color(0.25, 0.15, 0.35);  // neither: dark purple
  }
}

/**
 * Map sign to warm/cool.
 */
function signToColor(value: number): THREE.Color {
  if (value > 0) {
    const t = Math.min(1, value * 3); // scale for visibility
    return new THREE.Color(0.9 + 0.1 * t, 0.3 * (1 - t), 0.1);
  } else {
    const t = Math.min(1, -value * 3);
    return new THREE.Color(0.1, 0.3 * (1 - t), 0.8 + 0.2 * t);
  }
}

/**
 * Map diagonal distance |j-k| to color.
 */
function diagonalDistToColor(j: number, k: number, maxDist: number): THREE.Color {
  const dist = Math.abs(j - k);
  const t = maxDist > 0 ? dist / maxDist : 0;
  // Near diagonal: warm gold, far: cool blue
  const h = 0.1 + t * 0.55; // 0.1 (gold) to 0.65 (blue)
  return new THREE.Color().setHSL(h, 0.8, 0.5 + 0.2 * (1 - t));
}

/**
 * Get color for a point based on the current color mode.
 */
export function getPointColor(
  point: GramPoint,
  mode: ColorMode,
  globalMin: number,
  globalMax: number,
  maxDist: number,
): THREE.Color {
  switch (mode) {
    case 'magnitude':
      return valueToInferno(Math.abs(point.v), Math.abs(globalMin), Math.abs(globalMax));
    case 'gcd':
      return gcdToColor(point.g);
    case 'prime':
      return primeToColor(point.p);
    case 'sign':
      return signToColor(point.v);
    case 'diagonal':
      return diagonalDistToColor(point.j, point.k, maxDist);
    default:
      return valueToInferno(Math.abs(point.v), Math.abs(globalMin), Math.abs(globalMax));
  }
}

/**
 * Color mode labels for the UI.
 */
export const COLOR_MODE_LABELS: Record<ColorMode, string> = {
  magnitude: 'Value Magnitude (Inferno)',
  gcd: 'GCD Stratum',
  prime: 'Prime Sectors',
  sign: 'Sign (±)',
  diagonal: 'Diagonal Distance',
};
