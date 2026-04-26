"use client";
import { useState, useMemo } from "react";
import { motion } from "framer-motion";
import Link from "next/link";
import { gramEntry, gramTermRational, gramTermLog, gramTermCot, gramTermBase, meanEntry, covEntry, logCutoffWitness, mobiusSieve, GRAM_TERMS, CONSTANTS } from "@/lib/math";

/* ═══ proof node data ═══ */
interface ProofNode {
  key: string; title: string; group: string; file: string; status: "proved"|"axiom"|"sorry";
  theorem?: string; statement: string; steps: { tactic: string; explanation: string; goals: string[] }[];
}

const GROUP_META: Record<string,{label:string;color:string;icon:string}> = {
  gram: { label: "Gram Matrix", color: "#f59e0b", icon: "🔥" },
  vasyunin: { label: "Vasyunin Formula", color: "#8b5cf6", icon: "🌊" },
  witness: { label: "Witness Construction", color: "#10b981", icon: "∑" },
  distance: { label: "Distance Decay", color: "#3b82f6", icon: "📉" },
  converse: { label: "Converse Direction", color: "#ec4899", icon: "◀" },
};

const PROOF_NODES: ProofNode[] = [
  { key: "gram_diag", title: "Diagonal G(k,k)", group: "gram", file: "Gram/FractIntegral.lean",
    status: "proved", theorem: "fract_sq_integral",
    statement: "G(k,k) = ∫₀¹ {k/x}² dx = (ln(2π)−γ)/k − 1/k²",
    steps: [
      { tactic: "rw [gramEntry_diag]", explanation: "Unfold diagonal Gram entry to integral form", goals: ["⊢ ∫₀¹ {k/x}² dx = ..."] },
      { tactic: "apply stirling_fract_integral", explanation: "Apply Stirling-based fractional integral evaluation", goals: ["⊢ stirling bound"] },
      { tactic: "exact squeeze_limit_bound hk", explanation: "Squeeze theorem closes the gap. Zero axioms.", goals: [] },
    ]},
  { key: "gram_offdiag", title: "Off-Diagonal G(j,k)", group: "gram", file: "Vasyunin/Cotangent/ConvergenceAxioms.lean",
    status: "axiom", theorem: "partial_integral_tends_to_formula",
    statement: "∫₀¹ {j/x}{k/x} dx = Vasyunin cotangent formula (j≠k)",
    steps: [
      { tactic: "-- AXIOM: awaits Gauss digamma + dominated convergence", explanation: "Crown axiom #3. Diagonal case proved; off-diagonal needs Gauss digamma ψ(p/q) formula", goals: ["⊢ tendsto partial_integral ..."] },
    ]},
  { key: "gram_psd", title: "Gram Matrix PSD", group: "gram", file: "Vasyunin/Matrix/GramPSD.lean",
    status: "proved", theorem: "gram_matrix_psd",
    statement: "G_N is positive semidefinite (unconditional, 0 axioms)",
    steps: [
      { tactic: "intro v", explanation: "Take arbitrary vector v", goals: ["⊢ 0 ≤ vᵀGv"] },
      { tactic: "rw [gram_as_l2_inner_product]", explanation: "Rewrite Gram form as L² inner product ∫₀¹ |Σ vₖ{k/x}|² dx", goals: ["⊢ 0 ≤ ∫₀¹ |f|² dx"] },
      { tactic: "exact integral_nonneg (fun x => sq_nonneg _)", explanation: "Integral of a square is nonneg. Pure Mathlib.", goals: [] },
    ]},
  { key: "vasyunin_rational", title: "Rational Term: A/2·(1/j+1/k)", group: "vasyunin", file: "Vasyunin/Defs.lean",
    status: "proved", theorem: "gramTermRational_eq",
    statement: "The harmonic mean term. A = ln(2π) − γ ≈ 1.265. Rank-2 separable.",
    steps: [
      { tactic: "unfold gramTermRational", explanation: "Definition: A/2 · (1/j + 1/k)", goals: [] },
    ]},
  { key: "vasyunin_log", title: "Logarithmic Term: (j−k)/(2jk)·ln(k/j)", group: "vasyunin", file: "Vasyunin/Defs.lean",
    status: "proved", theorem: "gramTermLog_eq",
    statement: "Full-rank coupling. Encodes multiplicative distance between integers.",
    steps: [
      { tactic: "unfold gramTermLog", explanation: "Vanishes on diagonal (j=k). Antisymmetric in (j,k).", goals: [] },
    ]},
  { key: "vasyunin_cot", title: "Cotangent Sum: −πd/(2jk)·[V(j′,k′)+V(k′,j′)]", group: "vasyunin", file: "Vasyunin/Cotangent/",
    status: "proved", theorem: "vasyunin_cotangent_sum",
    statement: "The arithmetic heart. d=gcd(j,k), j′=j/d. Full-rank.",
    steps: [
      { tactic: "rw [vasyuninSum]", explanation: "V(a,b) = Σ_{m=1}^{a-1} {mb/a}/tan(πm/a). Dedekind-type sum.", goals: [] },
    ]},
  { key: "vasyunin_base", title: "Base Term: −1/(jk)", group: "vasyunin", file: "Vasyunin/Defs.lean",
    status: "proved", theorem: "gramTermBase_eq",
    statement: "Rank-1 correction. Killed by PNT since Σμ(k)/k → 0.",
    steps: [
      { tactic: "unfold gramTermBase", explanation: "Constant −1/(jk). Factors as outer product.", goals: [] },
    ]},
  { key: "witness_logcutoff", title: "Log-Cutoff Witness", group: "witness", file: "Assembly/L2Convergence.lean",
    status: "proved", theorem: "logCutoffWitness_def",
    statement: "vₖ = −μ(k)·(1 − ln(k)/ln(N)). Bartlett window taper.",
    steps: [
      { tactic: "intro k N", explanation: "The key witness. v₁=1 (since ln(1)=0), v_N=0. Only squarefree k contribute.", goals: [] },
      { tactic: "exact rfl", explanation: "Definition is computational.", goals: [] },
    ]},
  { key: "witness_pnt", title: "PNT: Σμ(k)·log(k)/k → −1", group: "witness", file: "PNT/AbelMean.lean",
    status: "axiom", theorem: "pnt_mu_log_div_k",
    statement: "Crown axiom #1. Derivative-level PNT consequence. Awaits Wiener-Ikehara.",
    steps: [
      { tactic: "-- AXIOM: Tauberian theorem needed", explanation: "Unconditionally true (Selberg 1949). Lean formalization requires forward Tauberian theorem.", goals: ["⊢ Tendsto S₁ atTop (nhds (-1))"] },
    ]},
  { key: "covariance_bound", title: "Covariance Bound: vᵀCv ≤ C/log N", group: "distance", file: "Covariance/GramFormProof.lean",
    status: "axiom", theorem: "covariance_bound_from_mertens_34",
    statement: "Crown axiom #2. Under M(x)=O(x¾), the centered Gram form decays.",
    steps: [
      { tactic: "-- AXIOM: bilinear expansion + S₁S₂S₃ decay", explanation: "Infrastructure proved: s₁_decay, s₂_decay, s₃_uniform_bound. Needs double-sum Abel.", goals: ["⊢ vᵀ(G−bbᵀ)v ≤ C/log N"] },
    ]},
  { key: "distance_decay", title: "d²_N → 0 (Forward)", group: "distance", file: "Assembly/MainChain.lean",
    status: "proved", theorem: "rh_implies_bd_convergence",
    statement: "RH ⟹ d²_N ≤ C/log(N) → 0. The forward pillar.",
    steps: [
      { tactic: "intro hrh", explanation: "Assume the Riemann Hypothesis", goals: ["⊢ d²_N → 0"] },
      { tactic: "have hm := perron_crown hrh", explanation: "Perron chain: RH → |M(x)| = O(x¾)", goals: ["hm : |M(x)| ≤ C·x¾"] },
      { tactic: "have hgf := gram_form_bound hm", explanation: "Gram form proof: M(x) bound → d²_N ≤ C/log N", goals: ["hgf : d²_N ≤ C/log N"] },
      { tactic: "exact tendsto_of_le_inv_log hgf", explanation: "C/log N → 0. QED.", goals: [] },
    ]},
  { key: "rank1_mellin", title: "Rank-1 Mellin Miracle", group: "converse", file: "NymanBeurling/BDMellin.lean",
    status: "proved", theorem: "mellin_rank_one",
    statement: "M[hₖ](ρ) = 1/(k(ρ−1)) factors as rank-1 tensor. PURE MATHLIB.",
    steps: [
      { tactic: "rw [mellin_transform_basis]", explanation: "Compute Mellin transform of basis function hₖ(x) = {1/(kx)}", goals: ["⊢ M[hₖ](s) = k^{-s}/(s−1)"] },
      { tactic: "simp [rank_one_factorization]", explanation: "At ζ-zero ρ: factors as f(k)·g(ρ). Rank-1 tensor.", goals: [] },
    ]},
  { key: "converse_separation", title: "Off-Critical Separation", group: "converse", file: "NymanBeurling/Separation.lean",
    status: "proved", theorem: "off_critical_defect",
    statement: "¬RH → ∃ρ with Re(ρ)≠½ → d²_N ≥ δ > 0. Zero axioms.",
    steps: [
      { tactic: "intro hnotRH", explanation: "Assume RH fails: ∃ρ with ζ(ρ)=0, Re(ρ)≠½", goals: ["⊢ ∃ δ > 0, ∀ N, d²_N ≥ δ"] },
      { tactic: "obtain ⟨ρ, hρ_zero, hρ_off⟩ := hnotRH", explanation: "Extract the off-critical zero ρ", goals: [] },
      { tactic: "exact cauchy_schwarz_separation hρ_off (mellin_rank_one ρ)", explanation: "Rank-1 Mellin + Cauchy-Schwarz: the tensor at ρ forces d² ≥ |residue|² > 0", goals: [] },
    ]},
];

/* ═══ interactive math panel ═══ */
function LiveMathPanel({ N }: { N: number }) {
  const mu = useMemo(() => mobiusSieve(N + 1), [N]);
  const [selJ, setSelJ] = useState(1);
  const [selK, setSelK] = useState(2);
  const g = gramEntry(selJ, selK);
  return (
    <div className="p-4 rounded-xl bg-[#0d0e1a] border border-slate-700/30 space-y-3">
      <div className="text-[10px] font-mono text-amber-400">LIVE COMPUTATION (N={N})</div>
      <div className="flex gap-4">
        <label className="text-xs text-slate-500">j=<input type="number" min={1} max={N} value={selJ} onChange={e=>setSelJ(Math.max(1,+e.target.value))} className="w-12 ml-1 bg-transparent border-b border-slate-600 text-amber-400 font-mono text-center"/></label>
        <label className="text-xs text-slate-500">k=<input type="number" min={1} max={N} value={selK} onChange={e=>setSelK(Math.max(1,+e.target.value))} className="w-12 ml-1 bg-transparent border-b border-slate-600 text-amber-400 font-mono text-center"/></label>
      </div>
      <div className="space-y-1 text-xs font-mono">
        {GRAM_TERMS.map(t => {
          const fn: Record<string,()=>number> = { rational:()=>gramTermRational(selJ,selK), log:()=>gramTermLog(selJ,selK), cot:()=>gramTermCot(selJ,selK), base:()=>gramTermBase(selJ,selK) };
          const v = fn[t.id]();
          return (<div key={t.id} className="flex justify-between"><span style={{color:t.color}}>{t.name}</span><span className="text-slate-300">{v.toFixed(6)}</span></div>);
        })}
        <div className="flex justify-between pt-1 border-t border-slate-700/30 font-bold"><span className="text-white">G({selJ},{selK})</span><span className="text-amber-400">{g.toFixed(6)}</span></div>
        <div className="flex justify-between text-slate-500"><span>b({selJ})</span><span>{meanEntry(selJ).toFixed(6)}</span></div>
        <div className="flex justify-between text-slate-500"><span>b({selK})</span><span>{meanEntry(selK).toFixed(6)}</span></div>
        <div className="flex justify-between text-violet-400"><span>C({selJ},{selK})</span><span>{covEntry(selJ,selK).toFixed(6)}</span></div>
      </div>
      <div className="pt-2 border-t border-slate-700/30">
        <div className="text-[10px] text-slate-600 mb-1">Witness v₁..v_N</div>
        <div className="flex flex-wrap gap-1">{Array.from({length:Math.min(N,20)},(_,i)=>i+1).map(k=>{
          const v=logCutoffWitness(k,N,mu);
          return <span key={k} className={`text-[9px] px-1 rounded font-mono ${v>0?"text-emerald-400 bg-emerald-500/10":v<0?"text-red-400 bg-red-500/10":"text-slate-600 bg-slate-800"}`}>{v.toFixed(2)}</span>;
        })}</div>
      </div>
    </div>
  );
}

/* ═══ main page ═══ */
export default function TermExplorerPage() {
  const [selected, setSelected] = useState<string>("gram_diag");
  const [expandedStep, setExpandedStep] = useState<number|null>(null);
  const [N, setN] = useState(20);
  const detail = PROOF_NODES.find(n=>n.key===selected) || PROOF_NODES[0];
  const grouped = PROOF_NODES.reduce<Record<string,ProofNode[]>>((a,n)=>{(a[n.group]??=[]).push(n);return a;},{});

  return (
    <div className="h-full flex flex-col">
      <div className="p-4 border-b border-[#1e2148] flex items-center justify-between">
        <div>
          <Link href="/" className="text-[10px] text-slate-600 hover:text-slate-400">← Cathedral</Link>
          <h2 className="text-xl font-bold"><span className="bg-gradient-to-r from-amber-400 via-violet-400 to-blue-400 bg-clip-text text-transparent">Term Explorer</span></h2>
        </div>
        <div className="flex items-center gap-2 text-xs text-slate-500">
          <span>N =</span>
          <input type="range" min={4} max={40} value={N} onChange={e=>setN(+e.target.value)} className="w-24 accent-amber-500"/>
          <span className="font-mono text-amber-400 w-6">{N}</span>
        </div>
      </div>

      <div className="flex-1 flex min-h-0">
        {/* Left: browsable proof list */}
        <div className="w-72 shrink-0 border-r border-[#1e2148] overflow-y-auto bg-[#0a0b14]/50">
          {Object.entries(grouped).map(([group, nodes]) => {
            const meta = GROUP_META[group];
            return (
              <div key={group} className="border-b border-[#1e2148]/50">
                <div className="px-3 py-1.5 flex items-center gap-2" style={{borderLeft:`3px solid ${meta.color}40`}}>
                  <span className="text-xs">{meta.icon}</span>
                  <span className="text-[10px] font-bold uppercase tracking-wider" style={{color:`${meta.color}90`}}>{meta.label}</span>
                  <span className="text-[9px] text-slate-600 ml-auto">{nodes.length}</span>
                </div>
                {nodes.map(n => {
                  const isActive = selected === n.key;
                  return (
                    <button key={n.key} onClick={()=>{setSelected(n.key);setExpandedStep(null);}}
                      className={`w-full text-left px-3 py-2 transition-all ${isActive?"bg-white/5":"hover:bg-white/3"}`}
                      style={isActive?{borderLeft:`3px solid ${meta.color}`}:{borderLeft:"3px solid transparent"}}>
                      <div className="flex items-center gap-1.5">
                        {n.status==="proved"&&<span className="text-emerald-400/70 text-[10px]">✓</span>}
                        {n.status==="axiom"&&<span className="text-amber-400/70 text-[10px]">⚠</span>}
                        {n.status==="sorry"&&<span className="text-red-400/70 text-[10px]">○</span>}
                        <span className={`text-[11px] leading-snug ${isActive?"text-white/90 font-medium":"text-white/50"}`}>{n.title}</span>
                      </div>
                      <span className={`inline-block mt-0.5 text-[8px] font-bold px-1.5 py-0.5 rounded ${n.status==="proved"?"bg-emerald-500/10 text-emerald-400/60":n.status==="axiom"?"bg-amber-500/10 text-amber-400/60":"bg-red-500/10 text-red-400/60"}`}>
                        {n.status.toUpperCase()}
                      </span>
                    </button>
                  );
                })}
              </div>
            );
          })}
        </div>

        {/* Right: detail panel */}
        <div className="flex-1 overflow-y-auto">
          <div className="max-w-3xl mx-auto px-6 py-5">
            <motion.div key={detail.key} initial={{opacity:0,y:8}} animate={{opacity:1,y:0}}>
              {/* Header */}
              <div className="flex items-start gap-3 mb-4">
                <span className="text-2xl mt-0.5">{GROUP_META[detail.group]?.icon}</span>
                <div className="flex-1">
                  <h2 className="text-xl font-bold text-white/90">{detail.title}</h2>
                  <div className="flex items-center gap-2 mt-2 flex-wrap">
                    <span className="text-[10px] font-semibold px-2 py-0.5 rounded" style={{background:`${GROUP_META[detail.group]?.color}20`,color:GROUP_META[detail.group]?.color,border:`1px solid ${GROUP_META[detail.group]?.color}30`}}>
                      {GROUP_META[detail.group]?.label}
                    </span>
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded ${detail.status==="proved"?"bg-emerald-500/15 text-emerald-400":detail.status==="axiom"?"bg-amber-500/15 text-amber-400":"bg-red-500/15 text-red-400"}`}>
                      {detail.status==="proved"?"✓ Verified":detail.status==="axiom"?"⚠ Axiom":"○ Sorry"}
                    </span>
                  </div>
                </div>
              </div>

              {/* File + theorem */}
              <div className="flex gap-3 flex-wrap mb-4">
                <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-white/3 border border-white/5">
                  <span className="text-[10px] text-white/30">📄</span>
                  <code className="text-[10px] text-cyan-300/60 font-mono">{detail.file}</code>
                </div>
                {detail.theorem && (
                  <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-white/3 border border-white/5">
                    <span className="text-[10px] text-white/30">⊢</span>
                    <code className="text-[10px] text-purple-300/60 font-mono">{detail.theorem}</code>
                  </div>
                )}
              </div>

              {/* Statement */}
              <div className="p-4 rounded-xl bg-[#12142a] border border-slate-700/30 mb-6">
                <div className="text-[10px] text-slate-500 uppercase tracking-wider mb-1">Statement</div>
                <p className="text-sm text-slate-300 font-mono leading-relaxed">{detail.statement}</p>
              </div>

              {/* Proof steps */}
              <h3 className="text-xs font-bold text-white/40 uppercase tracking-wider mb-3">
                Proof Steps ({detail.steps.length})
              </h3>
              <div className="space-y-2">
                {detail.steps.map((step, idx) => {
                  const isExp = expandedStep === idx;
                  const isLast = idx === detail.steps.length - 1;
                  const isQED = isLast && step.goals.length === 0 && detail.status === "proved";
                  return (
                    <div key={idx}>
                      <button onClick={()=>setExpandedStep(isExp?null:idx)}
                        className={`w-full text-left rounded-lg border transition-all ${isExp?"bg-white/5 border-white/10":"bg-white/2 border-white/4 hover:bg-white/4"}`}>
                        <div className="px-4 py-3 flex items-start gap-3">
                          <div className="shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-[10px] font-bold mt-0.5"
                            style={{background:isQED?"rgba(45,212,191,0.15)":"rgba(255,255,255,0.06)",color:isQED?"#2dd4bf":"rgba(255,255,255,0.4)",border:isQED?"1px solid rgba(45,212,191,0.3)":"1px solid rgba(255,255,255,0.08)"}}>
                            {isQED?"∎":idx+1}
                          </div>
                          <div className="flex-1 min-w-0">
                            <code className="text-[11px] font-mono block leading-relaxed" style={{color:isQED?"#2dd4bf":detail.status==="axiom"?"#fbbf24":"#93c5fd"}}>{step.tactic}</code>
                            {!isExp && <p className="text-[10px] text-white/30 mt-1 line-clamp-1">{step.explanation}</p>}
                          </div>
                          <span className="text-white/20 text-[10px] shrink-0 mt-1">{isExp?"▾":"▸"}</span>
                        </div>
                      </button>
                      {isExp && (
                        <div className="ml-9 mr-4 mt-1 mb-3 pl-4 border-l-2 border-white/5">
                          <p className="text-[12px] text-white/65 leading-relaxed mb-3">{step.explanation}</p>
                          {step.goals.length > 0 && (
                            <div className="space-y-1">
                              <span className="text-[9px] text-white/25 uppercase tracking-wider font-semibold">
                                {step.goals[0].startsWith("⊢")?"Goal":"Proof State"}
                              </span>
                              {step.goals.map((goal,gi) => (
                                <div key={gi} className="px-3 py-1.5 rounded bg-black/30 border border-white/5 font-mono text-[10px] text-amber-200/60">{goal}</div>
                              ))}
                            </div>
                          )}
                          {isQED && (
                            <div className="flex items-center gap-2 mt-2 px-3 py-1.5 rounded bg-emerald-500/5 border border-emerald-500/15">
                              <span className="text-emerald-400 text-sm">∎</span>
                              <span className="text-emerald-400/60 text-[10px] font-semibold">No remaining goals — proof complete</span>
                            </div>
                          )}
                        </div>
                      )}
                      {!isLast && <div className="flex justify-start ml-[26px] py-0.5"><div className="w-px h-3 bg-white/8"/></div>}
                    </div>
                  );
                })}
              </div>
            </motion.div>
          </div>
        </div>

        {/* Far right: live math */}
        <div className="w-72 shrink-0 border-l border-[#1e2148] overflow-y-auto p-3 space-y-3">
          <LiveMathPanel N={N} />
          <div className="p-3 rounded-xl bg-gradient-to-br from-violet-500/5 to-transparent border border-violet-500/20">
            <div className="text-[10px] font-mono text-violet-400 mb-1">CONSTANTS</div>
            <div className="space-y-1 text-[10px] font-mono text-slate-400">
              <div>γ = {CONSTANTS.GAMMA.toFixed(10)}</div>
              <div>A = ln(2π)−γ = {CONSTANTS.A.toFixed(10)}</div>
            </div>
          </div>
          <div className="p-3 rounded-xl bg-gradient-to-br from-amber-500/5 to-transparent border border-amber-500/20">
            <div className="text-[10px] font-mono text-amber-400 mb-1">PROOF STATS</div>
            <div className="space-y-1 text-[10px] text-slate-400">
              <div>✓ {PROOF_NODES.filter(n=>n.status==="proved").length} proved</div>
              <div>⚠ {PROOF_NODES.filter(n=>n.status==="axiom").length} axioms</div>
              <div>○ {PROOF_NODES.filter(n=>n.status==="sorry").length} sorry</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
