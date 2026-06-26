"use client";
import { useState, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";

/* ─── types ─── */

interface Particle {
  name: string;
  symbol: string;
  kind: "fermion" | "boson" | "graviton";
  generation?: number;
  force?: string;
  charge?: string;
  arithmeticEntity: string;
  arithmeticFormula: string;
  module: string;
  status: "proved" | "axiom" | "mockup";
  detail: string;
  color: string;
}

/* ─── data ─── */

const PARTICLES: Particle[] = [
  // ═══ FERMIONS: Generation 1 ═══
  {
    name: "Electron",
    symbol: "e⁻",
    kind: "fermion",
    generation: 1,
    charge: "-1",
    arithmeticEntity: "Squarefree n with μ(n) = -1, ω(n) = 1",
    arithmeticFormula: "μ(p) = -1 for primes p",
    module: "ArithmeticPauli + ArithmeticGenerations",
    status: "proved",
    detail:
      "Primes are the Generation 1 fermions. Each contributes μ(p) = -1, the fundamental negative charge of number theory. They are stable, lightest, and the building blocks of all composites.",
    color: "#22c55e",
  },
  {
    name: "Electron neutrino",
    symbol: "νₑ",
    kind: "fermion",
    generation: 1,
    charge: "0",
    arithmeticEntity: "Vacuum state n = 1",
    arithmeticFormula: "μ(1) = +1, δ_{n,1}",
    module: "ArithmeticU1",
    status: "proved",
    detail:
      "The vacuum state n=1 is the only integer with no prime factors. It contributes μ(1) = +1. Like the neutrino, it is neutral and nearly invisible — but essential for conservation laws.",
    color: "#22c55e",
  },
  {
    name: "Up quark",
    symbol: "u",
    kind: "fermion",
    generation: 1,
    charge: "+2/3",
    arithmeticEntity: "Prime p ≥ 5 (confined)",
    arithmeticFormula: "p never HC for p ≥ 5",
    module: "ArithmeticSU3",
    status: "proved",
    detail:
      "Primes p ≥ 5 are permanently confined — they are never highly composite numbers. Like quarks, they only exist inside composites (hadrons). Quark confinement is PROVED for all p ≥ 5.",
    color: "#22c55e",
  },
  {
    name: "Down quark",
    symbol: "d",
    kind: "fermion",
    generation: 1,
    charge: "-1/3",
    arithmeticEntity: "Prime p ≥ 5 (confined, μ = -1)",
    arithmeticFormula: "p never HC, μ(p) = -1",
    module: "ArithmeticSU3",
    status: "proved",
    detail:
      "Same as up quark in the arithmetic dictionary — both are confined primes. The up/down distinction maps to the isospin symmetry: G(6,6) ≈ G(10,10) (proton ≈ neutron mass).",
    color: "#22c55e",
  },

  // ═══ FERMIONS: Generation 2 ═══
  {
    name: "Muon",
    symbol: "μ⁻",
    kind: "fermion",
    generation: 2,
    charge: "-1",
    arithmeticEntity: "Semiprime p·q with μ = +1",
    arithmeticFormula: "μ(pq) = (-1)² = +1",
    module: "ArithmeticGenerations",
    status: "proved",
    detail:
      "Semiprimes are Generation 2: products of two distinct primes. They carry μ = +1 (opposite sign to Gen 1). Heavier, less stable, and they COUNTERACT the prime layer — the first correction in the alternating Möbius wave.",
    color: "#3b82f6",
  },
  {
    name: "Muon neutrino",
    symbol: "νμ",
    kind: "fermion",
    generation: 2,
    charge: "0",
    arithmeticEntity: "p=3 coprime fiber",
    arithmeticFormula: "Coprime fiber weight at p=3",
    module: "ArithmeticMixing",
    status: "axiom",
    detail:
      "The p=3 coprime fiber oscillates relative to the p=2 fiber as N grows. This oscillation is the arithmetic analog of neutrino flavor mixing: νₑ ↔ νμ oscillation.",
    color: "#3b82f6",
  },
  {
    name: "Charm quark",
    symbol: "c",
    kind: "fermion",
    generation: 2,
    charge: "+2/3",
    arithmeticEntity: "Semiprime component (heavier composite)",
    arithmeticFormula: "pq with p,q ≥ 5",
    module: "ArithmeticGenerations",
    status: "proved",
    detail:
      "Charm quarks are the Gen 2 quarks — semiprimes like 35 = 5·7 where both factors are ≥ 5. They carry +1 charge and are heavier than the fundamental primes.",
    color: "#3b82f6",
  },
  {
    name: "Strange quark",
    symbol: "s",
    kind: "fermion",
    generation: 2,
    charge: "-1/3",
    arithmeticEntity: "Semiprime with p=3 factor",
    arithmeticFormula: "3·p with p ≥ 5, μ = +1",
    module: "ArithmeticGenerations + ArithmeticSU3",
    status: "proved",
    detail:
      "Strange quarks involve the color carrier p=3. Semiprimes like 15 = 3·5 have μ(15) = +1 and bridge the SU(3) and Generation 2 structures.",
    color: "#3b82f6",
  },

  // ═══ FERMIONS: Generation 3 ═══
  {
    name: "Tau",
    symbol: "τ⁻",
    kind: "fermion",
    generation: 3,
    charge: "-1",
    arithmeticEntity: "3-almost-prime p·q·r, μ = -1",
    arithmeticFormula: "μ(pqr) = (-1)³ = -1",
    module: "ArithmeticGenerations",
    status: "proved",
    detail:
      "3-almost-primes are the heaviest squarefree composites that contribute significantly. Like the tau lepton, they are rare and short-lived. Their μ = -1 provides the final fine-tuning correction to the Möbius wave.",
    color: "#a855f7",
  },
  {
    name: "Tau neutrino",
    symbol: "ντ",
    kind: "fermion",
    generation: 3,
    charge: "0",
    arithmeticEntity: "p=5 coprime fiber",
    arithmeticFormula: "Coprime fiber weight at p=5",
    module: "ArithmeticMixing",
    status: "axiom",
    detail:
      "The p=5 coprime fiber has the smallest contribution of the three neutrino flavors. Its weight oscillates but never dominates — the lightest neutrino mass eigenstate.",
    color: "#a855f7",
  },
  {
    name: "Top quark",
    symbol: "t",
    kind: "fermion",
    generation: 3,
    charge: "+2/3",
    arithmeticEntity: "3-almost-prime (heaviest squarefree)",
    arithmeticFormula: "pqr with p,q,r ≥ 5",
    module: "ArithmeticGenerations",
    status: "proved",
    detail:
      "The top quark is the heaviest known fermion. In the Cathedral, 3-almost-primes like 385 = 5·7·11 are the heaviest squarefree integers that still contribute to the Möbius sum. Layer 4 (the hypothetical 4th generation) is too sparse.",
    color: "#a855f7",
  },
  {
    name: "Bottom quark",
    symbol: "b",
    kind: "fermion",
    generation: 3,
    charge: "-1/3",
    arithmeticEntity: "3-almost-prime with color factor",
    arithmeticFormula: "3·p·q, μ = -1",
    module: "ArithmeticGenerations + ArithmeticSU3",
    status: "proved",
    detail:
      "Bottom quarks bridge Generation 3 and color confinement. Products like 30 = 2·3·5 are the first baryon (μ(30) = -1) — a fermion bound state of all three gauge sectors.",
    color: "#a855f7",
  },

  // ═══ GAUGE BOSONS ═══
  {
    name: "Photon",
    symbol: "γ",
    kind: "boson",
    force: "Electromagnetic",
    arithmeticEntity: "L(λ,s) = ζ(2s)/ζ(s)",
    arithmeticFormula: "λ(mn) = λ(m)·λ(n)",
    module: "ArithmeticU1",
    status: "proved",
    detail:
      "The Liouville function λ is completely multiplicative — it satisfies charge conservation. The photon is the force carrier that preserves this U(1) symmetry. L(λ,s) = ζ(2s)/ζ(s) is the Dirichlet series of λ.",
    color: "#eab308",
  },
  {
    name: "W⁺ boson",
    symbol: "W⁺",
    kind: "boson",
    force: "Weak (charged)",
    arithmeticEntity: "μ(2n) = -μ(n) parity flip",
    arithmeticFormula: "Multiplication by Higgs (p=2) flips sign",
    module: "ArithmeticSU2",
    status: "proved",
    detail:
      "The W⁺ boson mediates charged weak interactions. In arithmetic, multiplying by the Higgs (p=2) flips the Möbius sign: μ(2n) = -μ(n) for odd squarefree n. This is the parity transformation.",
    color: "#f97316",
  },
  {
    name: "W⁻ boson",
    symbol: "W⁻",
    kind: "boson",
    force: "Weak (charged)",
    arithmeticEntity: "μ(n/2) = -μ(n) inverse flip",
    arithmeticFormula: "Division by 2 (when 2|n) flips sign",
    module: "ArithmeticSU2",
    status: "proved",
    detail:
      "The W⁻ is the antiparticle of W⁺. In arithmetic, removing the factor of 2 reverses the parity flip. Together W⁺ and W⁻ generate the SU(2) electroweak symmetry.",
    color: "#f97316",
  },
  {
    name: "Z⁰ boson",
    symbol: "Z⁰",
    kind: "boson",
    force: "Weak (neutral)",
    arithmeticEntity: "n ↦ 4n (double Higgs → μ = 0)",
    arithmeticFormula: "μ(4n) = 0 for all n > 0",
    module: "ArithmeticMixing",
    status: "proved",
    detail:
      "The Z⁰ boson is the neutral weak current. Applying the Higgs twice (n ↦ 4n) always produces a non-squarefree integer: 4 = 2² divides 4n. So μ(4n) = 0 — the Z⁰ interaction annihilates the fermion. This is the 'invisible width': Z⁰ → Pauli-excluded void.",
    color: "#f97316",
  },
  {
    name: "Gluon (×8)",
    symbol: "g",
    kind: "boson",
    force: "Strong",
    arithmeticEntity: "G(p,q) off-diagonal Gram coupling",
    arithmeticFormula: "8 independent color states ↔ 8 prime pairs",
    module: "ArithmeticSU3",
    status: "proved",
    detail:
      "Gluons carry color charge and mediate the strong force. In the Gram matrix, the off-diagonal entries G(p,q) couple different primes — these are the arithmetic gluons. There are 8 independent generators of SU(3), matching the 8 gluon color states.",
    color: "#ef4444",
  },
  {
    name: "Higgs boson",
    symbol: "H⁰",
    kind: "boson",
    force: "Higgs field",
    arithmeticEntity: "p = 2 (unique even prime)",
    arithmeticFormula: "∃! p prime, Even p → p = 2",
    module: "ArithmeticSU2",
    status: "proved",
    detail:
      "There is exactly one even prime: p = 2. There is exactly one Higgs boson. Both statements express the uniqueness of the symmetry-breaking mechanism. G(2,2) ≈ 0.380 anchors the spectral mass scale.",
    color: "#ec4899",
  },

  // ═══ GRAVITON ═══
  {
    name: "Graviton",
    symbol: "G",
    kind: "graviton",
    force: "Gravity",
    arithmeticEntity: "G(j,k) symmetric bilinear form",
    arithmeticFormula: "G(k,k) = (ln2π-γ)/k - 1/k²",
    module: "ArithmeticGravity",
    status: "axiom",
    detail:
      "The Gram matrix is a symmetric bilinear form with TWO indices — like the metric tensor g_{μν} in general relativity (spin-2). It couples ALL particles universally: G(j,k) ≠ 0 for all j,k. The diagonal decay G(k,k) ~ 1/k creates the mass hierarchy. Gravity is weak because the coupling decays algebraically — no fine-tuning needed.",
    color: "#6366f1",
  },
];

const FORCES = [
  {
    name: "U(1) — Electromagnetic",
    description: "Complete multiplicativity of λ",
    carrier: "Photon γ",
    color: "#eab308",
  },
  {
    name: "SU(2) — Weak",
    description: "Parity breaking at p = 2",
    carrier: "W±, Z⁰, H⁰",
    color: "#f97316",
  },
  {
    name: "SU(3) — Strong",
    description: "Color confinement at p = 3",
    carrier: "8 Gluons",
    color: "#ef4444",
  },
  {
    name: "Gravity",
    description: "Diagonal Gram decay G(k,k) ~ 1/k",
    carrier: "Graviton G",
    color: "#6366f1",
  },
];

/* ─── helpers ─── */

type FilterKind = "all" | "fermion" | "boson" | "graviton";

function statusBadge(s: Particle["status"]) {
  if (s === "proved")
    return (
      <span className="text-[9px] px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/20 font-mono">
        PROVED ✅
      </span>
    );
  if (s === "axiom")
    return (
      <span className="text-[9px] px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-400 border border-amber-500/20 font-mono">
        AXIOM
      </span>
    );
  return (
    <span className="text-[9px] px-1.5 py-0.5 rounded bg-slate-500/20 text-slate-400 border border-slate-500/20 font-mono">
      MOCKUP
    </span>
  );
}

function genBadge(g?: number) {
  if (!g) return null;
  const colors = ["", "#22c55e", "#3b82f6", "#a855f7"];
  return (
    <span
      className="text-[9px] px-1.5 py-0.5 rounded font-mono font-bold"
      style={{
        color: colors[g],
        background: `${colors[g]}20`,
        border: `1px solid ${colors[g]}30`,
      }}
    >
      Gen {g}
    </span>
  );
}

/* ─── page ─── */

export default function StandardModelPage() {
  const [filter, setFilter] = useState<FilterKind>("all");
  const [selected, setSelected] = useState<number | null>(null);

  const filtered = useMemo(
    () =>
      filter === "all"
        ? PARTICLES
        : PARTICLES.filter((p) => p.kind === filter),
    [filter]
  );

  const stats = useMemo(() => {
    const proved = PARTICLES.filter((p) => p.status === "proved").length;
    const axiom = PARTICLES.filter((p) => p.status === "axiom").length;
    const fermions = PARTICLES.filter((p) => p.kind === "fermion").length;
    const bosons = PARTICLES.filter((p) => p.kind === "boson").length;
    return { proved, axiom, fermions, bosons };
  }, []);

  return (
    <div className="p-8 max-w-6xl mx-auto">
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
        <Link
          href="/"
          className="text-xs text-slate-600 hover:text-slate-400 transition-colors"
        >
          &larr; Back to Cathedral
        </Link>
        <h1 className="text-3xl font-bold mt-3">
          <span className="bg-gradient-to-r from-emerald-400 via-blue-400 to-violet-400 bg-clip-text text-transparent">
            Arithmetic Standard Model
          </span>
        </h1>
        <p className="text-slate-400 mt-2 max-w-2xl">
          The integers are the theory. The primes are the particles. Every
          Standard Model particle has an arithmetic analog — and the Riemann
          Hypothesis is the statement that this theory is consistent.
        </p>

        {/* ─── stats row ─── */}
        <div className="flex gap-6 mt-4 text-sm flex-wrap">
          {[
            { n: stats.fermions, label: "Fermions", color: "bg-emerald-500" },
            { n: stats.bosons + 1, label: "Bosons + Graviton", color: "bg-amber-500" },
            { n: stats.proved, label: "Proved", color: "bg-blue-500" },
            { n: stats.axiom, label: "Axioms", color: "bg-orange-500" },
            { n: 0, label: "Free parameters", color: "bg-red-500" },
          ].map((s) => (
            <div key={s.label} className="flex items-center gap-2">
              <div className={`w-2.5 h-2.5 rounded-full ${s.color}`} />
              <span className="text-slate-400">
                {s.n} {s.label}
              </span>
            </div>
          ))}
        </div>

        {/* ─── force cards ─── */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-6">
          {FORCES.map((f) => (
            <div
              key={f.name}
              className="rounded-xl p-4 border border-slate-700/30 bg-[#0d0e1a]/80"
            >
              <div
                className="text-xs font-bold mb-1"
                style={{ color: f.color }}
              >
                {f.name}
              </div>
              <div className="text-[10px] text-slate-500">{f.description}</div>
              <div className="text-[10px] text-slate-600 mt-1">
                Carrier: {f.carrier}
              </div>
            </div>
          ))}
        </div>
      </motion.div>

      {/* ─── filter tabs ─── */}
      <div className="flex gap-2 mt-8 mb-4">
        {(["all", "fermion", "boson", "graviton"] as FilterKind[]).map((k) => (
          <button
            key={k}
            onClick={() => {
              setFilter(k);
              setSelected(null);
            }}
            className={`px-3 py-1.5 text-xs rounded-lg border transition-all ${
              filter === k
                ? "bg-[#1e2148] border-blue-500/40 text-blue-400"
                : "bg-[#0d0e1a] border-slate-700/30 text-slate-500 hover:text-slate-300"
            }`}
          >
            {k === "all"
              ? `All (${PARTICLES.length})`
              : k === "fermion"
              ? `Fermions (${stats.fermions})`
              : k === "boson"
              ? `Bosons (${stats.bosons})`
              : "Graviton (1)"}
          </button>
        ))}
      </div>

      {/* ─── particle table ─── */}
      <div className="space-y-2">
        {filtered.map((p, i) => {
          const globalIdx = PARTICLES.indexOf(p);
          const isOpen = selected === globalIdx;
          return (
            <motion.div
              key={p.name}
              initial={{ opacity: 0, x: -10 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: i * 0.03 }}
            >
              <div
                onClick={() => setSelected(isOpen ? null : globalIdx)}
                className={`rounded-xl p-4 border cursor-pointer transition-all duration-200 ${
                  isOpen
                    ? "bg-gradient-to-r from-[#12142a] to-[#0d0e1a] shadow-lg"
                    : "bg-[#0d0e1a]/50 hover:bg-[#12142a]/50"
                }`}
                style={{
                  borderColor: isOpen ? `${p.color}50` : "#1e214830",
                }}
              >
                {/* row */}
                <div className="flex items-center gap-4">
                  <div
                    className="w-10 h-10 rounded-lg flex items-center justify-center text-lg font-bold flex-shrink-0"
                    style={{
                      background: `${p.color}20`,
                      color: p.color,
                      border: `1px solid ${p.color}30`,
                    }}
                  >
                    {p.symbol}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-bold text-slate-200">
                        {p.name}
                      </span>
                      {genBadge(p.generation)}
                      {statusBadge(p.status)}
                    </div>
                    <div className="text-[11px] text-slate-500 mt-0.5 truncate">
                      {p.arithmeticEntity}
                    </div>
                  </div>
                  <div className="text-right flex-shrink-0 hidden sm:block">
                    <code className="text-[10px] text-slate-600">
                      {p.module}
                    </code>
                  </div>
                </div>

                {/* detail */}
                <AnimatePresence>
                  {isOpen && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: "auto", opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.2 }}
                    >
                      <div className="mt-4 pt-3 border-t border-slate-700/30 space-y-3">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                          <div>
                            <div className="text-[10px] text-slate-600 uppercase tracking-wider mb-1">
                              Arithmetic Formula
                            </div>
                            <code className="text-xs text-amber-400 bg-amber-500/10 px-2 py-1 rounded">
                              {p.arithmeticFormula}
                            </code>
                          </div>
                          <div>
                            <div className="text-[10px] text-slate-600 uppercase tracking-wider mb-1">
                              Force / Charge
                            </div>
                            <span className="text-xs text-slate-300">
                              {p.force || `Generation ${p.generation}`}
                              {p.charge && ` · Q = ${p.charge}`}
                            </span>
                          </div>
                        </div>
                        <p className="text-xs text-slate-400 leading-relaxed">
                          {p.detail}
                        </p>
                        <div className="text-[10px] text-slate-600">
                          Module:{" "}
                          <code className="text-slate-500">{p.module}</code>
                        </div>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </motion.div>
          );
        })}
      </div>

      {/* ─── footer: why 3 generations ─── */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.5 }}
        className="mt-10 p-6 rounded-xl border border-violet-500/20 bg-gradient-to-r from-violet-500/5 to-transparent"
      >
        <h3 className="text-sm font-bold text-violet-400 mb-2">
          Why 3 Generations?
        </h3>
        <p className="text-xs text-slate-400 leading-relaxed">
          The Erdős-Kac theorem (1940) says ω(n) is normally distributed
          with mean log log N. For all observable scales (N ≤ 10⁸⁰),
          log(log(10⁸⁰)) ≈ 5.3 — so Fermi layers 1-3 dominate the
          Möbius sum weight. The 4th generation exists arithmetically
          (4-almost-primes) but is exponentially suppressed. The Standard
          Model has 3 generations because the integers have 3 dominant
          squarefree layers. Zero free parameters.
        </p>
        <div className="mt-3 flex gap-6">
          {[
            { gen: 1, ex: "Primes: 2, 3, 5, 7, ...", sign: "μ = -1" },
            { gen: 2, ex: "Semiprimes: 6, 10, 15, ...", sign: "μ = +1" },
            { gen: 3, ex: "3-almost: 30, 42, 66, ...", sign: "μ = -1" },
          ].map((g) => (
            <div key={g.gen} className="text-center">
              <div
                className="text-lg font-bold"
                style={{
                  color: ["", "#22c55e", "#3b82f6", "#a855f7"][g.gen],
                }}
              >
                Gen {g.gen}
              </div>
              <div className="text-[10px] text-slate-500">{g.ex}</div>
              <div className="text-[10px] text-slate-600">{g.sign}</div>
            </div>
          ))}
        </div>
      </motion.div>

      {/* ─── gravity footer ─── */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.6 }}
        className="mt-4 p-6 rounded-xl border border-indigo-500/20 bg-gradient-to-r from-indigo-500/5 to-transparent"
      >
        <h3 className="text-sm font-bold text-indigo-400 mb-2">
          The Hierarchy Problem — Solved
        </h3>
        <p className="text-xs text-slate-400 leading-relaxed">
          Why is gravity 10³⁶ times weaker than electromagnetism? In the
          Cathedral: electromagnetic coupling (λ) is exact and never decays.
          Gravitational coupling G(k,k) ~ 1/k decays algebraically. The
          weakness of gravity is not fine-tuning — it is a <em>theorem</em>{" "}
          about the Gram matrix diagonal. For k ~ 10¹⁸ (the Planck/weak
          hierarchy), G(k,k) ≈ 10⁻¹⁸. Q.E.D.
        </p>
        <div className="mt-3 flex gap-4 text-center">
          {[
            { k: 1, label: "G(1,1)", val: "≈ 0.26", desc: "Planck mass" },
            { k: 2, label: "G(2,2)", val: "≈ 0.38", desc: "Higgs mass" },
            { k: 10, label: "G(10,10)", val: "≈ 0.12", desc: "Meson scale" },
            {
              k: 100,
              label: "G(100,100)",
              val: "≈ 0.013",
              desc: "Deep infrared",
            },
          ].map((e) => (
            <div
              key={e.k}
              className="flex-1 p-2 rounded-lg bg-[#0d0e1a] border border-slate-700/20"
            >
              <div className="text-xs font-mono text-indigo-400">
                {e.label}
              </div>
              <div className="text-sm font-bold text-slate-200">{e.val}</div>
              <div className="text-[9px] text-slate-600">{e.desc}</div>
            </div>
          ))}
        </div>
      </motion.div>
    </div>
  );
}
