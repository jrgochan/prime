"use client";
import { motion } from "framer-motion";
import Link from "next/link";

interface CardInfo {
  href: string;
  title: string;
  description: string;
  icon: string;
  stats: string;
  gradient: string;
  border: string;
}

const CARDS: CardInfo[] = [
  {
    href: "/proof-tree",
    title: "Proof Dependency Tree",
    description: "Interactive force-directed graph of 257 theorems, 23 axioms, and 889 dependencies.",
    icon: "🌳",
    stats: "257 nodes · 889 edges",
    gradient: "from-emerald-500/20 to-teal-500/20",
    border: "border-emerald-500/20",
  },
  {
    href: "/gram-heatmap",
    title: "Gram Matrix Heatmap",
    description: "Visualize the N×N Gram matrix of fractional part inner products. See the structure that makes the proof work.",
    icon: "🔥",
    stats: "N up to 100 · live computation",
    gradient: "from-orange-500/20 to-red-500/20",
    border: "border-orange-500/20",
  },
  {
    href: "/sawtooth",
    title: "Sawtooth Discovery",
    description: "Watch the covariance stabilize instead of decaying — the moment formal verification caught a subtle error.",
    icon: "📐",
    stats: "C∞ ≈ 0.00227",
    gradient: "from-blue-500/20 to-purple-500/20",
    border: "border-blue-500/20",
  },
  {
    href: "/offdiag-margin",
    title: "Off-Diagonal Excess",
    description: "The running sum dives negative while the 3n bound floats enormously above — an 18× safety margin.",
    icon: "📊",
    stats: "18× margin at N=50",
    gradient: "from-amber-500/20 to-yellow-500/20",
    border: "border-amber-500/20",
  },
  {
    href: "/fractional-waves",
    title: "Fractional Part Waves",
    description: "Toggle sawtooth functions {k/x} and their products to see how Gram matrix entries arise from wave interference.",
    icon: "🌊",
    stats: "k = 1 to 8 · interactive",
    gradient: "from-cyan-500/20 to-blue-500/20",
    border: "border-cyan-500/20",
  },
  {
    href: "/hyperplane-trap",
    title: "The Hyperplane Trap",
    description: "3D surface of the Mellin residual showing how spoofing weights create a zero that breaks Cauchy-Schwarz.",
    icon: "🕳️",
    stats: "3D · R3F interactive",
    gradient: "from-red-500/20 to-pink-500/20",
    border: "border-red-500/20",
  },
  {
    href: "/cathedral-3d",
    title: "Cathedral 3D",
    description: "The proof structure as a literal cathedral. Two pillars, Mathlib foundation, theorem bricks, and the golden roof of RH.",
    icon: "⛪",
    stats: "3D · auto-rotates",
    gradient: "from-purple-500/20 to-indigo-500/20",
    border: "border-purple-500/20",
  },
];

export default function HomePage() {
  return (
    <div className="p-8 max-w-6xl mx-auto">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="mb-12"
      >
        <h1 className="text-4xl font-bold mb-3">
          <span className="bg-gradient-to-r from-amber-400 via-orange-400 to-red-400 bg-clip-text text-transparent">
            The Cathedral
          </span>
        </h1>
        <p className="text-lg text-slate-400 max-w-2xl">
          A machine-checked reduction of the Riemann Hypothesis to two explicit axioms in Lean 4.
          Explore the proof architecture through interactive visualizations.
        </p>

        <div className="flex gap-6 mt-6 text-sm">
          {[
            { color: "bg-emerald-500", text: "44 Lean files" },
            { color: "bg-emerald-500", text: "0 sorry" },
            { color: "bg-amber-500", text: "2 axioms" },
            { color: "bg-blue-500", text: "3,444 build jobs" },
          ].map((item) => (
            <div key={item.text} className="flex items-center gap-2">
              <div className={`w-3 h-3 rounded-full ${item.color}`} />
              <span className="text-slate-300">{item.text}</span>
            </div>
          ))}
        </div>
      </motion.div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-12">
        {[
          { label: "PHYSICS PILLAR", name: "offdiag_excess_sum_le", desc: "The off-diagonal Gram excess grows at most linearly. Verified with 18× safety margin." },
          { label: "SPECTRAL PILLAR", name: "zeta_zero_separates", desc: "A rogue zeta zero off the critical line creates an L² obstruction." },
        ].map((axiom, i) => (
          <motion.div
            key={axiom.name}
            initial={{ opacity: 0, x: i === 0 ? -20 : 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.2 + i * 0.1 }}
            className="p-5 rounded-xl bg-gradient-to-br from-red-500/10 to-transparent border border-red-500/20"
          >
            <div className="text-xs font-mono text-red-400 mb-2">{axiom.label}</div>
            <h3 className="text-sm font-bold text-slate-200 mb-1 font-mono">{axiom.name}</h3>
            <p className="text-xs text-slate-500">{axiom.desc}</p>
          </motion.div>
        ))}
      </div>

      <h2 className="text-xl font-bold text-slate-200 mb-4">Explore</h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {CARDS.map((card, i) => (
          <motion.div
            key={card.href}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 + i * 0.1 }}
          >
            <Link
              href={card.href}
              className={`block p-6 rounded-xl bg-gradient-to-br ${card.gradient} border ${card.border} hover:scale-[1.02] transition-transform duration-200`}
            >
              <div className="text-3xl mb-3">{card.icon}</div>
              <h3 className="text-lg font-bold text-slate-200 mb-2">{card.title}</h3>
              <p className="text-sm text-slate-400 mb-3">{card.description}</p>
              <div className="text-xs font-mono text-slate-500">{card.stats}</div>
            </Link>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
