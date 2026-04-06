"use client";
import { useEffect, useRef, useState } from "react";
import * as d3 from "d3";
import { motion } from "framer-motion";

interface ProofNode {
  id: string;
  type: string;
  category: string;
  file: string;
  line: number;
  signature: string;
  x?: number;
  y?: number;
}

interface ProofEdge {
  source: string | ProofNode;
  target: string | ProofNode;
}

interface ProofData {
  nodes: ProofNode[];
  edges: ProofEdge[];
  meta: { totalNodes: number; totalEdges: number; axiomCount: number; theoremCount: number };
}

const COLORS: Record<string, string> = {
  axiom: "#ef4444",
  proved: "#10b981",
  definition: "#3b82f6",
  other: "#64748b",
};

export default function ProofTreePage() {
  const svgRef = useRef<SVGSVGElement>(null);
  const [data, setData] = useState<ProofData | null>(null);
  const [selected, setSelected] = useState<ProofNode | null>(null);
  const [filter, setFilter] = useState<string>("all");

  useEffect(() => {
    fetch("/data/proof-tree.json")
      .then((r) => r.json())
      .then(setData);
  }, []);

  useEffect(() => {
    if (!data || !svgRef.current) return;

    const svg = d3.select(svgRef.current);
    svg.selectAll("*").remove();

    const width = svgRef.current.clientWidth;
    const height = svgRef.current.clientHeight;

    // Filter nodes
    const filteredNodes = filter === "all"
      ? data.nodes
      : data.nodes.filter((n) => n.category === filter);
    const nodeIds = new Set(filteredNodes.map((n) => n.id));
    const filteredEdges = data.edges.filter(
      (e) => nodeIds.has(typeof e.source === "string" ? e.source : e.source.id) &&
             nodeIds.has(typeof e.target === "string" ? e.target : e.target.id)
    );

    const g = svg.append("g");

    // Zoom
    const zoom = d3.zoom<SVGSVGElement, unknown>()
      .scaleExtent([0.1, 4])
      .on("zoom", (event) => g.attr("transform", event.transform));
    svg.call(zoom);

    // Simulation
    const simulation = d3
      .forceSimulation(filteredNodes as d3.SimulationNodeDatum[])
      .force("link", d3.forceLink(filteredEdges).id((d: any) => d.id).distance(40).strength(0.3))
      .force("charge", d3.forceManyBody().strength(-80))
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius(8));

    // Edges
    const link = g
      .append("g")
      .selectAll("line")
      .data(filteredEdges)
      .join("line")
      .attr("stroke", "#1e2148")
      .attr("stroke-width", 0.5)
      .attr("stroke-opacity", 0.4);

    // Nodes
    const node = g
      .append("g")
      .selectAll("circle")
      .data(filteredNodes)
      .join("circle")
      .attr("r", (d) => (d.category === "axiom" ? 8 : d.id === "riemann_hypothesis" ? 12 : 5))
      .attr("fill", (d) => COLORS[d.category] || COLORS.other)
      .attr("stroke", (d) => d.id === "riemann_hypothesis" ? "#f59e0b" : "none")
      .attr("stroke-width", (d) => d.id === "riemann_hypothesis" ? 3 : 0)
      .attr("cursor", "pointer")
      .on("click", (_, d) => setSelected(d))
      .on("mouseenter", function (_, d) {
        d3.select(this).attr("r", (d: any) => (d.category === "axiom" ? 12 : 8));
        // Highlight connected
        const connected = new Set<string>();
        filteredEdges.forEach((e) => {
          const s = typeof e.source === "string" ? e.source : (e.source as ProofNode).id;
          const t = typeof e.target === "string" ? e.target : (e.target as ProofNode).id;
          if (s === d.id) connected.add(t);
          if (t === d.id) connected.add(s);
        });
        node.attr("opacity", (n) => (n.id === d.id || connected.has(n.id) ? 1 : 0.15));
        link.attr("stroke-opacity", (l: any) => {
          const s = typeof l.source === "string" ? l.source : l.source.id;
          const t = typeof l.target === "string" ? l.target : l.target.id;
          return s === d.id || t === d.id ? 0.8 : 0.05;
        });
      })
      .on("mouseleave", function () {
        d3.select(this).attr("r", (d: any) => (d.category === "axiom" ? 8 : d.id === "riemann_hypothesis" ? 12 : 5));
        node.attr("opacity", 1);
        link.attr("stroke-opacity", 0.4);
      })
      .call(d3.drag<SVGCircleElement, ProofNode>()
        .on("start", (event, d: any) => { if (!event.active) simulation.alphaTarget(0.3).restart(); d.fx = d.x; d.fy = d.y; })
        .on("drag", (event, d: any) => { d.fx = event.x; d.fy = event.y; })
        .on("end", (event, d: any) => { if (!event.active) simulation.alphaTarget(0); d.fx = null; d.fy = null; })
      );

    // Labels for axioms and riemann_hypothesis
    const label = g
      .append("g")
      .selectAll("text")
      .data(filteredNodes.filter((n) => n.category === "axiom" || n.id === "riemann_hypothesis"))
      .join("text")
      .text((d) => d.id.replace(/_/g, "_"))
      .attr("font-size", 9)
      .attr("font-family", "var(--font-geist-mono)")
      .attr("fill", (d) => d.category === "axiom" ? "#fca5a5" : "#fcd34d")
      .attr("dx", 12)
      .attr("dy", 4);

    simulation.on("tick", () => {
      link
        .attr("x1", (d: any) => d.source.x)
        .attr("y1", (d: any) => d.source.y)
        .attr("x2", (d: any) => d.target.x)
        .attr("y2", (d: any) => d.target.y);
      node.attr("cx", (d: any) => d.x).attr("cy", (d: any) => d.y);
      label.attr("x", (d: any) => d.x).attr("y", (d: any) => d.y);
    });

    return () => { simulation.stop(); };
  }, [data, filter]);

  return (
    <div className="h-full flex flex-col">
      <div className="p-6 border-b border-[#1e2148] flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-slate-200">Proof Dependency Tree</h2>
          <p className="text-sm text-slate-500 mt-1">
            {data ? `${data.meta.totalNodes} nodes · ${data.meta.totalEdges} edges · ${data.meta.axiomCount} axioms` : "Loading..."}
          </p>
        </div>
        <div className="flex gap-2">
          {["all", "axiom", "proved", "definition"].map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                filter === f
                  ? "bg-[#1e2148] text-amber-400"
                  : "text-slate-500 hover:text-slate-300 hover:bg-[#12142a]"
              }`}
            >
              {f === "all" ? "All" : f.charAt(0).toUpperCase() + f.slice(1) + "s"}
            </button>
          ))}
        </div>
      </div>

      <div className="flex-1 relative">
        <svg ref={svgRef} className="w-full h-full" />

        {/* Legend */}
        <div className="absolute top-4 left-4 bg-[#0d0e1a]/90 backdrop-blur-sm border border-[#1e2148] rounded-lg p-3 text-xs space-y-2">
          {Object.entries(COLORS).map(([cat, color]) => (
            <div key={cat} className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full" style={{ background: color }} />
              <span className="text-slate-400 capitalize">{cat}</span>
            </div>
          ))}
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-amber-500 ring-2 ring-amber-500/50" />
            <span className="text-slate-400">riemann_hypothesis</span>
          </div>
        </div>

        {/* Detail panel */}
        {selected && (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            className="absolute top-4 right-4 w-96 bg-[#0d0e1a]/95 backdrop-blur-sm border border-[#1e2148] rounded-xl p-4"
          >
            <div className="flex justify-between items-start">
              <div>
                <span className={`inline-block px-2 py-0.5 rounded text-xs font-mono mb-2 ${
                  selected.category === "axiom" ? "bg-red-500/20 text-red-400" : "bg-emerald-500/20 text-emerald-400"
                }`}>
                  {selected.type}
                </span>
                <h3 className="text-sm font-bold font-mono text-slate-200">{selected.id}</h3>
              </div>
              <button onClick={() => setSelected(null)} className="text-slate-500 hover:text-slate-300">✕</button>
            </div>
            <p className="text-xs text-slate-500 mt-1">{selected.file}:{selected.line}</p>
            <pre className="mt-3 text-xs text-slate-400 bg-[#0a0b14] rounded-lg p-3 overflow-x-auto font-mono leading-relaxed whitespace-pre-wrap">
              {selected.signature}
            </pre>
          </motion.div>
        )}
      </div>
    </div>
  );
}
