"use client";
import { useEffect, useRef, useState, useCallback } from "react";
import * as d3 from "d3";
import { motion, AnimatePresence } from "framer-motion";

interface ProofNode {
  id: string;
  type: string;
  category: string;
  route: string;
  file: string;
  line: number;
  signature: string;
  x?: number;
  y?: number;
  fx?: number | null;
  fy?: number | null;
}

interface ProofEdge {
  source: string | ProofNode;
  target: string | ProofNode;
}

interface ProofData {
  nodes: ProofNode[];
  edges: ProofEdge[];
  meta: {
    totalNodes: number;
    totalEdges: number;
    axiomCount: number;
    theoremCount: number;
    provedTheorems: number;
    description: string;
    generatedAt: string;
  };
}

const ROUTE_COLORS: Record<string, string> = {
  crown: "#f59e0b",
  geometry: "#f43f5e",
  physics: "#ec4899",
  mellin: "#10b981",
  variational: "#8b5cf6",
  infrastructure: "#3b82f6",
  equivalences: "#06b6d4",
};

const ROUTE_LABELS: Record<string, string> = {
  crown: "Assembly + Oracle (Penta-Crown)",
  geometry: "Geometry · Renormalization · GlassBox",
  physics: "Physics · Dedekind · Standard Model",
  mellin: "Mellin · NB · Perron · PNT",
  variational: "Vasyunin · Spectral · Covariance",
  infrastructure: "Infrastructure · Definitions",
  equivalences: "Robin · Lagarias Equivalences",
};

const CATEGORY_COLORS: Record<string, string> = {
  axiom: "#ef4444",
  sorry: "#f59e0b",
  proved: "#10b981",
  definition: "#3b82f6",
};

function getNodeColor(node: ProofNode, colorMode: string): string {
  if (colorMode === "route") return ROUTE_COLORS[node.route] || "#64748b";
  return CATEGORY_COLORS[node.category] || "#64748b";
}

function getNodeRadius(node: ProofNode): number {
  if (node.id === "riemann_hypothesis") return 16;
  if (node.category === "axiom") return 9;
  if (node.category === "sorry") return 8;
  if (
    node.id === "nyman_beurling_equivalence" ||
    node.id === "lagarias_for_primes"
  )
    return 12;
  if (node.category === "definition") return 5;
  return 6;
}

export default function ProofTreePage() {
  const svgRef = useRef<SVGSVGElement>(null);
  const [data, setData] = useState<ProofData | null>(null);
  const [selected, setSelected] = useState<ProofNode | null>(null);
  const [routeFilter, setRouteFilter] = useState<string>("all");
  const [colorMode, setColorMode] = useState<string>("route");
  const [showLabels, setShowLabels] = useState(true);
  const [highlightPath, setHighlightPath] = useState<Set<string> | null>(null);
  const simulationRef = useRef<d3.Simulation<
    d3.SimulationNodeDatum,
    undefined
  > | null>(null);

  useEffect(() => {
    fetch("/data/proof-tree.json")
      .then((r) => r.json())
      .then(setData);
  }, []);

  const traceAncestors = useCallback(
    (nodeId: string, edges: ProofEdge[]): Set<string> => {
      const ancestors = new Set<string>();
      const queue = [nodeId];
      while (queue.length > 0) {
        const current = queue.shift()!;
        ancestors.add(current);
        edges.forEach((e) => {
          const t =
            typeof e.target === "string"
              ? e.target
              : (e.target as ProofNode).id;
          const s =
            typeof e.source === "string"
              ? e.source
              : (e.source as ProofNode).id;
          if (t === current && !ancestors.has(s)) {
            queue.push(s);
          }
        });
      }
      return ancestors;
    },
    []
  );

  useEffect(() => {
    if (!data || !svgRef.current) return;

    const svg = d3.select(svgRef.current);
    svg.selectAll("*").remove();

    const width = svgRef.current.clientWidth;
    const height = svgRef.current.clientHeight;

    const filteredNodes =
      routeFilter === "all"
        ? data.nodes
        : data.nodes.filter((n) => n.route === routeFilter);
    const nodeIds = new Set(filteredNodes.map((n) => n.id));
    const filteredEdges = data.edges.filter(
      (e) =>
        nodeIds.has(typeof e.source === "string" ? e.source : e.source.id) &&
        nodeIds.has(typeof e.target === "string" ? e.target : e.target.id)
    );

    // Defs for glow effects
    const defs = svg.append("defs");

    // Glow filter
    const glow = defs.append("filter").attr("id", "glow");
    glow
      .append("feGaussianBlur")
      .attr("stdDeviation", "3")
      .attr("result", "coloredBlur");
    const feMerge = glow.append("feMerge");
    feMerge.append("feMergeNode").attr("in", "coloredBlur");
    feMerge.append("feMergeNode").attr("in", "SourceGraphic");

    // Strong glow for RH node
    const glowStrong = defs.append("filter").attr("id", "glow-strong");
    glowStrong
      .append("feGaussianBlur")
      .attr("stdDeviation", "6")
      .attr("result", "coloredBlur");
    const feMerge2 = glowStrong.append("feMerge");
    feMerge2.append("feMergeNode").attr("in", "coloredBlur");
    feMerge2.append("feMergeNode").attr("in", "SourceGraphic");

    // Arrow marker
    defs
      .append("marker")
      .attr("id", "arrowhead")
      .attr("viewBox", "0 0 10 10")
      .attr("refX", 20)
      .attr("refY", 5)
      .attr("markerWidth", 6)
      .attr("markerHeight", 6)
      .attr("orient", "auto")
      .append("path")
      .attr("d", "M 0 0 L 10 5 L 0 10 z")
      .attr("fill", "#1e2148");

    const g = svg.append("g");

    // Zoom
    const zoom = d3
      .zoom<SVGSVGElement, unknown>()
      .scaleExtent([0.1, 6])
      .on("zoom", (event) => g.attr("transform", event.transform));
    svg.call(zoom);

    // Force simulation with route-based clustering
    const simulation = d3
      .forceSimulation(filteredNodes as d3.SimulationNodeDatum[])
      .force(
        "link",
        d3
          .forceLink(filteredEdges)
          .id((d: any) => d.id)
          .distance(60)
          .strength(0.4)
      )
      .force("charge", d3.forceManyBody().strength(-120))
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius(12))
      .force(
        "x",
        d3
          .forceX<any>()
          .x((d: ProofNode) => {
            const positions: Record<string, number> = {
              infrastructure: width * 0.12,
              variational: width * 0.28,
              mellin: width * 0.44,
              geometry: width * 0.58,
              physics: width * 0.72,
              crown: width * 0.85,
              equivalences: width * 0.15,
            };
            return positions[d.route] || width / 2;
          })
          .strength(0.08)
      )
      .force(
        "y",
        d3
          .forceY<any>()
          .y((d: ProofNode) => {
            if (d.id === "riemann_hypothesis") return height * 0.12;
            if (d.category === "axiom") return height * 0.85;
            if (d.category === "definition") return height * 0.75;
            return height * 0.45;
          })
          .strength(0.06)
      );

    simulationRef.current = simulation;

    // Edges
    const link = g
      .append("g")
      .selectAll("line")
      .data(filteredEdges)
      .join("line")
      .attr("stroke", "#1e2148")
      .attr("stroke-width", 1)
      .attr("stroke-opacity", 0.35)
      .attr("marker-end", "url(#arrowhead)");

    // Node groups
    const nodeGroup = g
      .append("g")
      .selectAll<SVGGElement, ProofNode>("g")
      .data(filteredNodes)
      .join("g")
      .attr("cursor", "pointer")
      .on("click", (_, d) => {
        setSelected(d);
        setHighlightPath(traceAncestors(d.id, filteredEdges));
      });

    // Node circles
    nodeGroup
      .append("circle")
      .attr("r", getNodeRadius)
      .attr("fill", (d) => getNodeColor(d, colorMode))
      .attr("stroke", (d) =>
        d.id === "riemann_hypothesis"
          ? "#fbbf24"
          : d.id === "lagarias_for_primes"
            ? "#f59e0b"
            : "transparent"
      )
      .attr("stroke-width", (d) =>
        d.id === "riemann_hypothesis"
          ? 3
          : d.id === "lagarias_for_primes"
            ? 2
            : 0
      )
      .attr("filter", (d) =>
        d.id === "riemann_hypothesis"
          ? "url(#glow-strong)"
          : d.category === "axiom" || d.category === "sorry"
            ? "url(#glow)"
            : "none"
      )
      .attr("opacity", 0.9);

    // Labels
    const label = g
      .append("g")
      .selectAll("text")
      .data(
        filteredNodes.filter(
          (n) =>
            showLabels &&
            (n.category === "axiom" ||
              n.id === "riemann_hypothesis" ||
              n.id === "nyman_beurling_equivalence" ||
              n.id === "lagarias_for_primes" ||
              n.id === "phase_3_chain" ||
              n.id === "nyman_beurling_converse" ||
              n.id === "robin_implies_nyman_beurling" ||
              n.id === "lagarias_implies_nyman_beurling" ||
              n.id === "baezDuarte_separates" ||
              n.id === "rh_weight_construction_derived" ||
              n.id === "rh_from_oracle" ||
              n.id === "oracle_certificates" ||
              n.id === "gram_bound_subseq_implies_rh")
        )
      )
      .join("text")
      .text((d) => {
        const name = d.id.replace(/_/g, "_");
        return name.length > 30 ? name.substring(0, 28) + "…" : name;
      })
      .attr("font-size", (d) =>
        d.id === "riemann_hypothesis" ? 12 : d.category === "axiom" ? 9 : 10
      )
      .attr("font-family", "var(--font-geist-mono)")
      .attr("font-weight", (d) =>
        d.id === "riemann_hypothesis" ? "bold" : "normal"
      )
      .attr("fill", (d) =>
        d.id === "riemann_hypothesis"
          ? "#fbbf24"
          : d.category === "axiom"
            ? "#fca5a5"
            : "#94a3b8"
      )
      .attr("dx", (d) => getNodeRadius(d) + 6)
      .attr("dy", 4)
      .attr("pointer-events", "none");

    // Hover interactions
    nodeGroup
      .on("mouseenter", function (_, d) {
        d3.select(this).select("circle").attr("r", getNodeRadius(d) + 4);

        const connected = new Set<string>();
        filteredEdges.forEach((e) => {
          const s =
            typeof e.source === "string"
              ? e.source
              : (e.source as ProofNode).id;
          const t =
            typeof e.target === "string"
              ? e.target
              : (e.target as ProofNode).id;
          if (s === d.id) connected.add(t);
          if (t === d.id) connected.add(s);
        });

        nodeGroup
          .select("circle")
          .attr("opacity", (n: any) =>
            n.id === d.id || connected.has(n.id) ? 1 : 0.12
          );
        link
          .attr("stroke-opacity", (l: any) => {
            const s = typeof l.source === "string" ? l.source : l.source.id;
            const t = typeof l.target === "string" ? l.target : l.target.id;
            return s === d.id || t === d.id ? 0.9 : 0.03;
          })
          .attr("stroke", (l: any) => {
            const s = typeof l.source === "string" ? l.source : l.source.id;
            const t = typeof l.target === "string" ? l.target : l.target.id;
            return s === d.id || t === d.id
              ? getNodeColor(d, colorMode)
              : "#1e2148";
          })
          .attr("stroke-width", (l: any) => {
            const s = typeof l.source === "string" ? l.source : l.source.id;
            const t = typeof l.target === "string" ? l.target : l.target.id;
            return s === d.id || t === d.id ? 2 : 1;
          });
        label.attr("opacity", (n: any) =>
          n.id === d.id || connected.has(n.id) ? 1 : 0.1
        );
      })
      .on("mouseleave", function () {
        nodeGroup
          .select("circle")
          .attr("r", (d: any) => getNodeRadius(d))
          .attr("opacity", 0.9);
        link
          .attr("stroke-opacity", 0.35)
          .attr("stroke", "#1e2148")
          .attr("stroke-width", 1);
        label.attr("opacity", 1);
      });

    // Drag
    nodeGroup.call(
      d3
        .drag<SVGGElement, ProofNode>()
        .on("start", (event, d: any) => {
          if (!event.active) simulation.alphaTarget(0.3).restart();
          d.fx = d.x;
          d.fy = d.y;
        })
        .on("drag", (event, d: any) => {
          d.fx = event.x;
          d.fy = event.y;
        })
        .on("end", (event, d: any) => {
          if (!event.active) simulation.alphaTarget(0);
          d.fx = null;
          d.fy = null;
        })
    );

    simulation.on("tick", () => {
      link
        .attr("x1", (d: any) => d.source.x)
        .attr("y1", (d: any) => d.source.y)
        .attr("x2", (d: any) => d.target.x)
        .attr("y2", (d: any) => d.target.y);
      nodeGroup.attr("transform", (d: any) => `translate(${d.x},${d.y})`);
      label.attr("x", (d: any) => d.x).attr("y", (d: any) => d.y);
    });

    return () => {
      simulation.stop();
    };
  }, [data, routeFilter, colorMode, showLabels, traceAncestors]);

  const stats = data
    ? {
        axioms: data.nodes.filter((n) => n.category === "axiom").length,
        proved: data.nodes.filter((n) => n.category === "proved").length,
        defs: data.nodes.filter((n) => n.category === "definition").length,
        routes: Object.entries(
          data.nodes.reduce(
            (acc, n) => {
              acc[n.route] = (acc[n.route] || 0) + 1;
              return acc;
            },
            {} as Record<string, number>
          )
        ),
        criticalAxioms: data.nodes.filter(
          (n) =>
            n.category === "axiom" &&
            (n.route === "converse" || n.route === "forward")
        ).length,
        sorry: data.nodes.filter((n) => n.category === "sorry").length,
      }
    : null;

  return (
    <div className="h-full flex flex-col bg-[#0a0b14]">
      {/* Header */}
      <div className="px-6 py-4 border-b border-[#1e2148] flex items-center justify-between flex-shrink-0">
        <div>
          <h2 className="text-2xl font-bold text-slate-200 flex items-center gap-3">
            <span className="text-amber-400">⬡</span>
            Cathedral Proof Architecture
          </h2>
          <p className="text-sm text-slate-500 mt-1">
            {data
              ? `${data.meta.totalNodes} nodes · ${data.meta.totalEdges} edges · ${stats?.axioms} axioms · ${stats?.proved} proved`
              : "Loading..."}
          </p>
        </div>
        <div className="flex items-center gap-4">
          {/* Color mode toggle */}
          <div className="flex rounded-lg overflow-hidden border border-[#1e2148]">
            {["route", "status"].map((mode) => (
              <button
                key={mode}
                onClick={() => setColorMode(mode)}
                className={`px-3 py-1.5 text-xs font-medium transition-colors ${
                  colorMode === mode
                    ? "bg-[#1e2148] text-amber-400"
                    : "text-slate-500 hover:text-slate-300"
                }`}
              >
                {mode === "route" ? "By Route" : "By Status"}
              </button>
            ))}
          </div>
          {/* Label toggle */}
          <button
            onClick={() => setShowLabels(!showLabels)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors border border-[#1e2148] ${
              showLabels ? "text-emerald-400 bg-[#1e2148]" : "text-slate-500"
            }`}
          >
            Labels
          </button>
        </div>
      </div>

      {/* Route filter bar */}
      <div className="px-6 py-2.5 border-b border-[#1e2148]/50 flex gap-2 flex-shrink-0 overflow-x-auto">
        <button
          onClick={() => setRouteFilter("all")}
          className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all whitespace-nowrap ${
            routeFilter === "all"
              ? "bg-[#1e2148] text-white ring-1 ring-slate-600"
              : "text-slate-500 hover:text-slate-300 hover:bg-[#12142a]"
          }`}
        >
          All Routes
        </button>
        {Object.entries(ROUTE_LABELS).map(([key, label]) => {
          const count = data?.nodes.filter((n) => n.route === key).length || 0;
          return (
            <button
              key={key}
              onClick={() => setRouteFilter(key)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all flex items-center gap-2 whitespace-nowrap ${
                routeFilter === key
                  ? "ring-1"
                  : "text-slate-500 hover:text-slate-300 hover:bg-[#12142a]"
              }`}
              style={{
                color: routeFilter === key ? ROUTE_COLORS[key] : undefined,
                borderColor:
                  routeFilter === key ? ROUTE_COLORS[key] : undefined,
                backgroundColor:
                  routeFilter === key ? ROUTE_COLORS[key] + "15" : undefined,
              }}
            >
              <span
                className="w-2 h-2 rounded-full"
                style={{ background: ROUTE_COLORS[key] }}
              />
              {label}
              <span className="text-slate-600 ml-1">({count})</span>
            </button>
          );
        })}
      </div>

      {/* Main area */}
      <div className="flex-1 relative overflow-hidden">
        <svg ref={svgRef} className="w-full h-full" />

        {/* Legend */}
        <div className="absolute bottom-4 left-4 bg-[#0d0e1a]/90 backdrop-blur-md border border-[#1e2148] rounded-xl p-4 text-xs space-y-3">
          <h4 className="text-slate-400 font-semibold uppercase tracking-wider text-[10px] mb-2">
            {colorMode === "route" ? "Routes" : "Status"}
          </h4>
          {colorMode === "route"
            ? Object.entries(ROUTE_COLORS).map(([key, color]) => (
                <div key={key} className="flex items-center gap-2">
                  <div
                    className="w-3 h-3 rounded-full"
                    style={{ background: color }}
                  />
                  <span className="text-slate-400 capitalize">{key}</span>
                </div>
              ))
            : Object.entries(CATEGORY_COLORS).map(([key, color]) => (
                <div key={key} className="flex items-center gap-2">
                  <div
                    className="w-3 h-3 rounded-full"
                    style={{ background: color }}
                  />
                  <span className="text-slate-400 capitalize">{key}</span>
                </div>
              ))}
          <div className="border-t border-[#1e2148] pt-2 mt-2">
            <div className="flex items-center gap-2">
              <div className="w-4 h-4 rounded-full bg-amber-400/30 ring-2 ring-amber-400" />
              <span className="text-amber-400 text-[10px]">
                RiemannHypothesis
              </span>
            </div>
          </div>
        </div>

        {/* Stats panel */}
        {stats && (
          <div className="absolute top-4 left-4 bg-[#0d0e1a]/90 backdrop-blur-md border border-[#1e2148] rounded-xl p-4 text-xs space-y-2 min-w-[200px]">
            <h4 className="text-slate-400 font-semibold uppercase tracking-wider text-[10px] mb-3">
              Cathedral Status
            </h4>
            <div className="flex justify-between">
              <span className="text-slate-500">Proved theorems</span>
              <span className="text-emerald-400 font-mono font-bold">
                {stats.proved}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">Sorry theorems</span>
              <span className="text-amber-400 font-mono font-bold">
                {stats.sorry}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">Axioms</span>
              <span className="text-red-400 font-mono font-bold">
                {stats.axioms}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">Definitions</span>
              <span className="text-blue-400 font-mono font-bold">
                {stats.defs}
              </span>
            </div>
            {/* Progress bar */}
            <div className="mt-3 pt-2 border-t border-[#1e2148]">
              <div className="flex justify-between mb-1">
                <span className="text-slate-500">Proof completion</span>
                <span className="text-emerald-400 font-mono">
                  {Math.round(
                    (stats.proved / (stats.proved + stats.axioms + stats.sorry)) * 100
                  )}
                  %
                </span>
              </div>
              <div className="w-full h-1.5 bg-[#1e2148] rounded-full overflow-hidden">
                <div className="h-full flex">
                  <div
                    className="h-full bg-emerald-500 transition-all duration-500"
                    style={{
                      width: `${(stats.proved / (stats.proved + stats.axioms + stats.sorry)) * 100}%`,
                    }}
                  />
                  <div
                    className="h-full bg-amber-500 transition-all duration-500"
                    style={{
                      width: `${(stats.sorry / (stats.proved + stats.axioms + stats.sorry)) * 100}%`,
                    }}
                  />
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Detail panel */}
        <AnimatePresence>
          {selected && (
            <motion.div
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 20 }}
              className="absolute top-4 right-4 w-[420px] bg-[#0d0e1a]/95 backdrop-blur-md border border-[#1e2148] rounded-xl p-5 shadow-2xl"
            >
              <div className="flex justify-between items-start">
                <div>
                  <div className="flex items-center gap-2 mb-2">
                    <span
                      className={`inline-block px-2 py-0.5 rounded text-[10px] font-semibold uppercase tracking-wider ${
                        selected.category === "axiom"
                          ? "bg-red-500/15 text-red-400 ring-1 ring-red-500/30"
                          : selected.category === "proved"
                            ? "bg-emerald-500/15 text-emerald-400 ring-1 ring-emerald-500/30"
                            : "bg-blue-500/15 text-blue-400 ring-1 ring-blue-500/30"
                      }`}
                    >
                      {selected.category}
                    </span>
                    <span
                      className="inline-block px-2 py-0.5 rounded text-[10px] font-medium"
                      style={{
                        color: ROUTE_COLORS[selected.route],
                        background: ROUTE_COLORS[selected.route] + "15",
                      }}
                    >
                      {selected.route}
                    </span>
                  </div>
                  <h3 className="text-sm font-bold font-mono text-slate-200 break-all">
                    {selected.id}
                  </h3>
                </div>
                <button
                  onClick={() => {
                    setSelected(null);
                    setHighlightPath(null);
                  }}
                  className="text-slate-500 hover:text-slate-300 ml-2 flex-shrink-0 text-lg"
                >
                  ✕
                </button>
              </div>
              <p className="text-xs text-slate-500 mt-2 font-mono">
                {selected.file}:{selected.line}
              </p>
              <pre className="mt-3 text-xs text-slate-300 bg-[#0a0b14] rounded-lg p-3 overflow-x-auto font-mono leading-relaxed whitespace-pre-wrap border border-[#1e2148]">
                {selected.signature}
              </pre>

              {/* Trace path button */}
              {highlightPath && (
                <div className="mt-3 pt-3 border-t border-[#1e2148]">
                  <p className="text-[10px] text-slate-500 uppercase tracking-wider">
                    Dependency chain:{" "}
                    <span className="text-amber-400">
                      {highlightPath.size} nodes
                    </span>
                  </p>
                  <div className="flex flex-wrap gap-1 mt-2 max-h-24 overflow-y-auto">
                    {Array.from(highlightPath).map((id) => {
                      const node = data?.nodes.find((n) => n.id === id);
                      return (
                        <span
                          key={id}
                          className="text-[9px] px-1.5 py-0.5 rounded font-mono"
                          style={{
                            background:
                              (node
                                ? CATEGORY_COLORS[node.category]
                                : "#64748b") + "20",
                            color: node
                              ? CATEGORY_COLORS[node.category]
                              : "#64748b",
                          }}
                        >
                          {id.length > 25 ? id.substring(0, 23) + "…" : id}
                        </span>
                      );
                    })}
                  </div>
                </div>
              )}
            </motion.div>
          )}
        </AnimatePresence>

        {/* Help hint */}
        <div className="absolute bottom-4 right-4 text-[10px] text-slate-600">
          Scroll to zoom · Drag to pan · Click nodes to inspect · Hover to
          highlight
        </div>
      </div>
    </div>
  );
}
