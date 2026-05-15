// ═══════════════════════════════════════════════════════
// SPECTROMETER DATA MODULE
// Spectral Lift Grid: π^n / ζ(k) with physical constant matches
// ═══════════════════════════════════════════════════════

const PI = Math.PI;

// Zeta values at even integers (Bernoulli formula)
export const ZETA: Record<number, number> = {
  2: PI ** 2 / 6,
  4: PI ** 4 / 90,
  6: PI ** 6 / 945,
  8: PI ** 8 / 9450,
  10: PI ** 10 / 93555,
  12: (691 * PI ** 12) / 638512875,
};

export const ZETA_ARGS = [2, 4, 6, 8, 10, 12] as const;
export const PI_POWERS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] as const;

export function gridValue(n: number, k: number): number {
  return PI ** n / ZETA[k];
}

// Category colors (particle physics families)
export const CATEGORY_COLORS: Record<string, string> = {
  NUCLEON: "#00ff88",
  MESON: "#8844ff",
  "QUARK RATIO": "#ff8800",
  COUPLING: "#ffdd00",
  LEPTON: "#00aaff",
  "GAUGE BOSON": "#ff0044",
  "MASS RATIO": "#ff6600",
  BARYON: "#00ffaa",
  "MAGNETIC MOMENT": "#aaaaff",
};

// A match from the spectrometer mapped to grid coordinates
export interface GridMatch {
  symbol: string;
  name: string;
  actual: number;
  formula: string;
  computed: number;
  error: number; // percent
  tier: "Star" | "Lightning" | "Dot";
  category: string;
  // Grid coordinates (when formula is π^n/ζ(k) shaped)
  n?: number;
  k?: number;
  coeff?: number;
}

// Top spectrometer matches with grid positions extracted
export const MATCHES: GridMatch[] = [
  // ⭐ Stars
  { symbol: "m_p/m_e", name: "proton/electron", actual: 1836.153, formula: "π⁷/ζ(2)", computed: 1836.118, error: 0.0019, tier: "Star", category: "NUCLEON", n: 7, k: 2 },
  { symbol: "m_p/m_e", name: "proton/electron", actual: 1836.153, formula: "6·π⁵", computed: 1836.118, error: 0.0019, tier: "Star", category: "NUCLEON", n: 5, coeff: 6 },
  { symbol: "m_p/m_e", name: "proton/electron", actual: 1836.153, formula: "6π⁵·(1+α²/3)", computed: 1836.151, error: 0.00011, tier: "Star", category: "NUCLEON", n: 5, coeff: 6 },

  // ⚡ Lightning
  { symbol: "m_p/m_e", name: "proton/electron", actual: 1836.153, formula: "6·π⁵/ζ(12)", computed: 1835.666, error: 0.026, tier: "Lightning", category: "NUCLEON", n: 5, k: 12, coeff: 6 },
  { symbol: "m_K⁰/m_e", name: "neutral kaon", actual: 973.800, formula: "10·π⁴", computed: 974.091, error: 0.030, tier: "Lightning", category: "MESON", n: 4, coeff: 10 },
  { symbol: "(m_n−m_p)/m_e", name: "n-p mass diff", actual: 2.531, formula: "(5/2)·(1+α·ζ(2))", computed: 2.530, error: 0.039, tier: "Lightning", category: "NUCLEON" },
  { symbol: "m_D/m_e", name: "D meson", actual: 3658.833, formula: "12·π⁵/ζ(8)", computed: 3657.324, error: 0.041, tier: "Lightning", category: "MESON", n: 5, k: 8, coeff: 12 },
  { symbol: "m_b/m_c", name: "bottom/charm", actual: 3.291, formula: "2·ζ(2)", computed: 3.290, error: 0.044, tier: "Lightning", category: "QUARK RATIO", k: 2 },
  { symbol: "m_K±/m_e", name: "charged kaon", actual: 966.102, formula: "ζ(8)·π⁶", computed: 965.309, error: 0.082, tier: "Lightning", category: "MESON", n: 6, k: 8 },
  { symbol: "m_ω/m_e", name: "omega meson", actual: 1531.627, formula: "5·π⁵", computed: 1530.098, error: 0.100, tier: "Lightning", category: "MESON", n: 5, coeff: 5 },

  // · Dots (notable)
  { symbol: "sin²θ_W", name: "Weinberg angle", actual: 0.2312, formula: "1/(4·ζ(4))", computed: 0.2310, error: 0.102, tier: "Dot", category: "COUPLING", k: 4 },
  { symbol: "m_Ω/m_e", name: "Omega baryon", actual: 3272.903, formula: "ζ(4)·π⁷", computed: 3268.934, error: 0.121, tier: "Dot", category: "BARYON", n: 7, k: 4 },
  { symbol: "m_Z/m_p", name: "Z/proton", actual: 97.187, formula: "π⁴/ζ(10)", computed: 97.312, error: 0.129, tier: "Dot", category: "MASS RATIO", n: 4, k: 10 },
  { symbol: "m_H/m_p", name: "Higgs/proton", actual: 133.490, formula: "90·ζ(4)⁵", computed: 133.668, error: 0.133, tier: "Dot", category: "MASS RATIO", k: 4 },
  { symbol: "|μ_n/μ_N|", name: "neutron moment", actual: 1.913, formula: "π/ζ(2)", computed: 1.910, error: 0.166, tier: "Dot", category: "MAGNETIC MOMENT", n: 1, k: 2 },
  { symbol: "m_Z/m_e", name: "Z/electron", actual: 178450, formula: "6·π⁹/ζ(10)", computed: 178677, error: 0.127, tier: "Dot", category: "GAUGE BOSON", n: 9, k: 10, coeff: 6 },
  { symbol: "m_η/m_e", name: "eta meson", actual: 1072.139, formula: "π⁵·glass³", computed: 1074.296, error: 0.201, tier: "Dot", category: "MESON", n: 5 },
  { symbol: "m_d/m_u", name: "down/up quark", actual: 2.162, formula: "2·ζ(4)", computed: 2.165, error: 0.122, tier: "Dot", category: "QUARK RATIO", k: 4 },
];

// Build a lookup: which grid cells (n, k) have matches?
export function getGridMatches(): Map<string, GridMatch[]> {
  const map = new Map<string, GridMatch[]>();
  for (const m of MATCHES) {
    if (m.n != null && m.k != null) {
      const key = `${m.n},${m.k}`;
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(m);
    }
  }
  return map;
}

// The S-Duality Mass Table (confirmed formulas)
export const S_DUALITY_TABLE = [
  { quantity: "m_p/m_e", bare: "6π⁵ = π⁷/ζ(2)", corrected: "6π⁵·(1+α²/3)", error: "0.00011%" },
  { quantity: "(m_n−m_p)/m_e", bare: "5/2 = ζ(2)²/ζ(4)", corrected: "(5/2)·(1+α·ζ(2))", error: "0.039%" },
  { quantity: "sin²θ_W", bare: "1/(4·ζ(4))", corrected: "—", error: "0.098%" },
  { quantity: "m_b/m_c", bare: "2·ζ(2) = π²/3", corrected: "—", error: "0.044%" },
  { quantity: "Q_K (Koide)", bare: "2/3", corrected: "—", error: "0.00085%" },
];
