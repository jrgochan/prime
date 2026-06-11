"use client";
import { useState, useMemo, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import dynamic from "next/dynamic";
import {
  gramEntry, gramTermRational, gramTermLog, gramTermCot, gramTermBase,
  meanEntry, covEntry, logCutoffWitness, mobiusSieve, GRAM_TERMS, CONSTANTS,
} from "@/lib/math";

// Lazy-load the matrix explorer tab
const TermExplorer = dynamic(() => import("./TermExplorer"), { ssr: false });

/* ═══ types ═══ */
interface ProofStep { tactic: string; explanation: string; goals: string[] }
interface ProofNode {
  key: string; title: string; group: string; file: string; line: number;
  status: "proved"|"axiom"|"sorry"|"definition";
  theorem: string; statement: string; latex: string;
  steps: ProofStep[]; source: "curated"|"auto"; signature: string;
}
interface GroupMeta { label: string; color: string; icon: string; order: number }
interface ProofNodesData {
  groups: Record<string, GroupMeta>;
  nodes: ProofNode[];
  meta: { totalNodes: number; curatedNodes: number; autoNodes: number; proved: number; axioms: number; sorry: number };
}

/* ═══ live math panel (right sidebar) ═══ */
function LiveMathPanel({ N }: { N: number }) {
  const mu = useMemo(() => mobiusSieve(N + 1), [N]);
  const [selJ, setSelJ] = useState(1);
  const [selK, setSelK] = useState(2);
  const g = gramEntry(selJ, selK);
  return (
    <div className="space-y-3">
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
      <div className="p-3 rounded-xl bg-gradient-to-br from-violet-500/5 to-transparent border border-violet-500/20">
        <div className="text-[10px] font-mono text-violet-400 mb-1">CONSTANTS</div>
        <div className="space-y-1 text-[10px] font-mono text-slate-400">
          <div>γ = {CONSTANTS.GAMMA.toFixed(10)}</div>
          <div>A = ln(2π)−γ = {CONSTANTS.A.toFixed(10)}</div>
        </div>
      </div>
    </div>
  );
}

/* ═══ main page ═══ */
export default function TermExplorerPage() {
  const [tab, setTab] = useState<"chain"|"matrix">("chain");
  const [data, setData] = useState<ProofNodesData | null>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const [expandedStep, setExpandedStep] = useState<number|null>(null);
  const [N, setN] = useState(20);
  const [searchQuery, setSearchQuery] = useState("");
  const [showAuto, setShowAuto] = useState(true);
  const [groupFilter, setGroupFilter] = useState<string>("all");

  // Load data
  useEffect(() => {
    fetch("/data/proof-nodes.json").then(r => r.json()).then((d: ProofNodesData) => {
      setData(d);
      // Select first curated node
      const first = d.nodes.find(n => n.source === "curated");
      if (first) setSelected(first.key);
    });
  }, []);

  // Filter nodes
  const filteredNodes = useMemo(() => {
    if (!data) return [];
    return data.nodes.filter(n => {
      if (!showAuto && n.source === "auto") return false;
      if (groupFilter !== "all" && n.group !== groupFilter) return false;
      if (searchQuery) {
        const q = searchQuery.toLowerCase();
        return n.title.toLowerCase().includes(q) ||
               n.theorem.toLowerCase().includes(q) ||
               n.file.toLowerCase().includes(q) ||
               n.statement.toLowerCase().includes(q);
      }
      return true;
    });
  }, [data, showAuto, groupFilter, searchQuery]);

  // Group nodes
  const grouped = useMemo(() => {
    const groups: Record<string, ProofNode[]> = {};
    filteredNodes.forEach(n => { (groups[n.group] ??= []).push(n); });
    return groups;
  }, [filteredNodes]);

  // Sort groups by order
  const sortedGroups = useMemo(() => {
    if (!data) return [];
    return Object.entries(grouped).sort(([a], [b]) => {
      const oa = data.groups[a]?.order ?? 99;
      const ob = data.groups[b]?.order ?? 99;
      return oa - ob;
    });
  }, [grouped, data]);

  const detail = data?.nodes.find(n => n.key === selected) || null;

  if (!data) return (
    <div className="h-full flex items-center justify-center text-slate-500">
      <div className="text-center">
        <div className="text-2xl mb-2 animate-pulse">⟐</div>
        <div className="text-sm">Loading proof nodes...</div>
      </div>
    </div>
  );

  return (
    <div className="h-full flex flex-col">
      {/* Header */}
      <div className="p-4 border-b border-[#1e2148] flex items-center justify-between flex-shrink-0">
        <div>
          <Link href="/" className="text-[10px] text-slate-600 hover:text-slate-400">← Cathedral</Link>
          <h2 className="text-xl font-bold">
            <span className="bg-gradient-to-r from-amber-400 via-violet-400 to-blue-400 bg-clip-text text-transparent">
              Term Explorer
            </span>
          </h2>
        </div>
        <div className="flex items-center gap-3">
          {/* Tab switcher */}
          <div className="flex rounded-lg overflow-hidden border border-[#1e2148]">
            {(["chain", "matrix"] as const).map(t => (
              <button key={t} onClick={() => setTab(t)}
                className={`px-3 py-1.5 text-xs font-medium transition-colors ${
                  tab === t ? "bg-[#1e2148] text-amber-400" : "text-slate-500 hover:text-slate-300"
                }`}>
                {t === "chain" ? "🔗 Proof Chain" : "🔥 Matrix Explorer"}
              </button>
            ))}
          </div>
          {tab === "chain" && (
            <div className="flex items-center gap-2 text-xs text-slate-500">
              <span>N =</span>
              <input type="range" min={4} max={40} value={N} onChange={e=>setN(+e.target.value)} className="w-16 accent-amber-500"/>
              <span className="font-mono text-amber-400 w-6">{N}</span>
            </div>
          )}
        </div>
      </div>

      {/* Tab content */}
      {tab === "matrix" ? (
        <div className="flex-1 overflow-auto">
          <TermExplorer />
        </div>
      ) : (
        <div className="flex-1 flex min-h-0">
          {/* Left: browsable node list */}
          <div className="w-72 shrink-0 border-r border-[#1e2148] overflow-y-auto bg-[#0a0b14]/50 flex flex-col">
            {/* Search + filters */}
            <div className="p-2 border-b border-[#1e2148]/50 space-y-2 shrink-0">
              <input type="text" placeholder="Search theorems..."
                value={searchQuery} onChange={e => setSearchQuery(e.target.value)}
                className="w-full px-2 py-1.5 rounded-lg bg-[#0d0e1a] border border-[#1e2148] text-xs text-slate-300 placeholder-slate-600 focus:outline-none focus:border-amber-500/50"
              />
              <div className="flex items-center gap-2">
                <select value={groupFilter} onChange={e => setGroupFilter(e.target.value)}
                  className="flex-1 px-2 py-1 rounded bg-[#0d0e1a] border border-[#1e2148] text-[10px] text-slate-400">
                  <option value="all">All groups</option>
                  {Object.entries(data.groups).sort(([,a],[,b]) => a.order - b.order).map(([key, g]) => (
                    <option key={key} value={key}>{g.icon} {g.label}</option>
                  ))}
                </select>
                <button onClick={() => setShowAuto(!showAuto)}
                  className={`px-2 py-1 rounded text-[10px] font-medium border transition-colors ${
                    showAuto ? "border-cyan-500/50 text-cyan-400 bg-cyan-500/10" : "border-[#1e2148] text-slate-600"
                  }`}>
                  {showAuto ? `All (${filteredNodes.length})` : `Curated (${filteredNodes.length})`}
                </button>
              </div>
            </div>

            {/* Node list */}
            <div className="flex-1 overflow-y-auto">
              {sortedGroups.map(([group, nodes]) => {
                const meta = data.groups[group] || { label: group, color: "#64748b", icon: "📄", order: 99 };
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
                            {n.source === "curated" && <span className="text-[8px] text-amber-500/40 ml-auto">★</span>}
                          </div>
                          <span className={`inline-block mt-0.5 text-[8px] font-bold px-1.5 py-0.5 rounded ${
                            n.status==="proved"?"bg-emerald-500/10 text-emerald-400/60":
                            n.status==="axiom"?"bg-amber-500/10 text-amber-400/60":
                            "bg-red-500/10 text-red-400/60"}`}>
                            {n.status.toUpperCase()}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                );
              })}
            </div>
          </div>

          {/* Center: detail panel */}
          <div className="flex-1 overflow-y-auto">
            <div className="max-w-3xl mx-auto px-6 py-5">
              {detail ? (
                <motion.div key={detail.key} initial={{opacity:0,y:8}} animate={{opacity:1,y:0}}>
                  {/* Header */}
                  <div className="flex items-start gap-3 mb-4">
                    <span className="text-2xl mt-0.5">{data.groups[detail.group]?.icon || "📄"}</span>
                    <div className="flex-1">
                      <h2 className="text-xl font-bold text-white/90">{detail.title}</h2>
                      <div className="flex items-center gap-2 mt-2 flex-wrap">
                        <span className="text-[10px] font-semibold px-2 py-0.5 rounded"
                          style={{background:`${data.groups[detail.group]?.color || "#64748b"}20`,
                                  color:data.groups[detail.group]?.color || "#64748b",
                                  border:`1px solid ${data.groups[detail.group]?.color || "#64748b"}30`}}>
                          {data.groups[detail.group]?.label || detail.group}
                        </span>
                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded ${
                          detail.status==="proved"?"bg-emerald-500/15 text-emerald-400":
                          detail.status==="axiom"?"bg-amber-500/15 text-amber-400":
                          "bg-red-500/15 text-red-400"}`}>
                          {detail.status==="proved"?"✓ Verified":detail.status==="axiom"?"⚠ Axiom":"○ Gap"}
                        </span>
                        {detail.source === "curated" && (
                          <span className="text-[10px] px-2 py-0.5 rounded bg-amber-500/10 text-amber-400/60 border border-amber-500/20">★ Curated</span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* File + theorem */}
                  <div className="flex gap-3 flex-wrap mb-4">
                    <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-white/3 border border-white/5">
                      <span className="text-[10px] text-white/30">📄</span>
                      <code className="text-[10px] text-cyan-300/60 font-mono">{detail.file}{detail.line > 0 ? `:${detail.line}` : ""}</code>
                    </div>
                    {detail.theorem && (
                      <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-white/3 border border-white/5">
                        <span className="text-[10px] text-white/30">⊢</span>
                        <code className="text-[10px] text-purple-300/60 font-mono">{detail.theorem}</code>
                      </div>
                    )}
                  </div>

                  {/* Statement */}
                  {detail.statement && (
                    <div className="p-4 rounded-xl bg-[#12142a] border border-slate-700/30 mb-4">
                      <div className="text-[10px] text-slate-500 uppercase tracking-wider mb-1">Statement</div>
                      <p className="text-sm text-slate-300 font-mono leading-relaxed">{detail.statement}</p>
                    </div>
                  )}

                  {/* LaTeX formula */}
                  {detail.latex && (
                    <div className="p-4 rounded-xl bg-[#0d0e1a] border border-violet-500/20 mb-4 text-center">
                      <code className="text-sm text-violet-300 font-mono">{detail.latex}</code>
                    </div>
                  )}

                  {/* Signature (auto-extracted) */}
                  {detail.signature && (
                    <div className="mb-4">
                      <div className="text-[10px] text-slate-500 uppercase tracking-wider mb-1">Lean Signature</div>
                      <pre className="p-3 rounded-lg bg-[#0a0b14] border border-[#1e2148] text-[11px] text-slate-400 font-mono overflow-x-auto whitespace-pre-wrap">{detail.signature}</pre>
                    </div>
                  )}

                  {/* Proof steps */}
                  {detail.steps.length > 0 && (
                    <>
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
                                    style={{background:isQED?"rgba(45,212,191,0.15)":"rgba(255,255,255,0.06)",
                                            color:isQED?"#2dd4bf":"rgba(255,255,255,0.4)",
                                            border:isQED?"1px solid rgba(45,212,191,0.3)":"1px solid rgba(255,255,255,0.08)"}}>
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
                                      <span className="text-[9px] text-white/25 uppercase tracking-wider font-semibold">Goal</span>
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
                            </div>
                          );
                        })}
                      </div>
                    </>
                  )}
                </motion.div>
              ) : (
                <div className="text-center text-slate-600 mt-20">
                  <div className="text-3xl mb-3">⟐</div>
                  <div className="text-sm">Select a proof node to inspect</div>
                </div>
              )}
            </div>
          </div>

          {/* Right: live math */}
          <div className="w-72 shrink-0 border-l border-[#1e2148] overflow-y-auto p-3 space-y-3">
            <LiveMathPanel N={N} />
            <div className="p-3 rounded-xl bg-gradient-to-br from-amber-500/5 to-transparent border border-amber-500/20">
              <div className="text-[10px] font-mono text-amber-400 mb-1">PROOF STATS</div>
              <div className="space-y-1 text-[10px] text-slate-400">
                <div>✓ {data.meta.proved} proved</div>
                <div>⚠ {data.meta.axioms} axioms</div>
                <div>○ {data.meta.sorry} gaps</div>
                <div className="pt-1 border-t border-slate-700/30 text-slate-600">
                  ★ {data.meta.curatedNodes} curated · {data.meta.autoNodes} auto-scanned
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
