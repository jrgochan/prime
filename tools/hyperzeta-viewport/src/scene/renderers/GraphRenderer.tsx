"use client";

import { useRef, useEffect, useCallback, useState } from "react";
import {
  CATHEDRAL_NODES,
  CATHEDRAL_EDGES,
  computeGraphLayout,
  ProofNode,
} from "../../content/cathedral-map";

// ── Colors by status ──
const STATUS_COLORS: Record<string, { fill: string; glow: string; stroke: string }> = {
  proved: { fill: "#00ff88", glow: "rgba(0, 255, 136, 0.3)", stroke: "#00ff88" },
  axiom: { fill: "#ffd700", glow: "rgba(255, 215, 0, 0.4)", stroke: "#ffd700" },
  kernel: { fill: "rgba(255,255,255,0.4)", glow: "rgba(255,255,255,0.1)", stroke: "rgba(255,255,255,0.3)" },
};

const BG = "rgba(8, 12, 18, 0.95)";
const EDGE_COLOR = "rgba(255, 255, 255, 0.08)";
const TEXT_COLOR = "rgba(224, 232, 240, 0.7)";
const TEXT_DIM = "rgba(224, 232, 240, 0.4)";

/**
 * GraphRenderer — Canvas 2D force-directed proof dependency graph.
 * Renders the Cathedral's axiom tree with status-colored nodes.
 */
export function GraphRenderer() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animRef = useRef(0);
  const [hoveredNode, setHoveredNode] = useState<ProofNode | null>(null);
  const layoutRef = useRef(computeGraphLayout());

  const draw = useCallback(
    (ctx: CanvasRenderingContext2D, w: number, h: number, t: number) => {
      const layout = layoutRef.current;

      ctx.clearRect(0, 0, w, h);

      // Scale layout to canvas
      const scaleX = w / 800;
      const scaleY = h / 560;
      const sx = (x: number) => x * scaleX;
      const sy = (y: number) => y * scaleY;

      // ── Draw edges ──
      ctx.lineWidth = 1.5;
      CATHEDRAL_EDGES.forEach((edge) => {
        const from = layout.get(edge.from);
        const to = layout.get(edge.to);
        if (!from || !to) return;

        ctx.strokeStyle = EDGE_COLOR;
        ctx.beginPath();
        ctx.moveTo(sx(from.x), sy(from.y));

        // Curved edges for depth
        const midX = (from.x + to.x) / 2;
        const midY = (from.y + to.y) / 2 - 10;
        ctx.quadraticCurveTo(sx(midX), sy(midY), sx(to.x), sy(to.y));
        ctx.stroke();

        // Arrow tip
        const angle = Math.atan2(sy(to.y) - sy(midY), sx(to.x) - sx(midX));
        const arrowLen = 6;
        ctx.fillStyle = EDGE_COLOR;
        ctx.beginPath();
        ctx.moveTo(sx(to.x), sy(to.y));
        ctx.lineTo(
          sx(to.x) - arrowLen * Math.cos(angle - 0.4),
          sy(to.y) - arrowLen * Math.sin(angle - 0.4)
        );
        ctx.lineTo(
          sx(to.x) - arrowLen * Math.cos(angle + 0.4),
          sy(to.y) - arrowLen * Math.sin(angle + 0.4)
        );
        ctx.fill();
      });

      // ── Draw nodes ──
      CATHEDRAL_NODES.forEach((node) => {
        const pos = layout.get(node.id);
        if (!pos) return;

        const x = sx(pos.x);
        const y = sy(pos.y);
        const colors = STATUS_COLORS[node.status] ?? STATUS_COLORS.proved;
        const isHovered = hoveredNode?.id === node.id;
        const radius = node.status === "kernel" ? 6 : isHovered ? 14 : 10;

        // Glow
        ctx.fillStyle = colors.glow;
        ctx.beginPath();
        ctx.arc(x, y, radius + 8, 0, Math.PI * 2);
        ctx.fill();

        // Pulsing for axiom nodes
        if (node.status === "axiom") {
          const pulse = 1 + 0.15 * Math.sin(t * 3);
          ctx.fillStyle = colors.glow;
          ctx.beginPath();
          ctx.arc(x, y, radius * pulse + 4, 0, Math.PI * 2);
          ctx.fill();
        }

        // Node circle
        ctx.fillStyle = colors.fill;
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, Math.PI * 2);
        ctx.fill();

        // Border
        ctx.strokeStyle = colors.stroke;
        ctx.lineWidth = isHovered ? 2.5 : 1.5;
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, Math.PI * 2);
        ctx.stroke();

        // Label
        ctx.fillStyle = isHovered ? "#ffffff" : TEXT_COLOR;
        ctx.font = `${isHovered ? "bold " : ""}10px 'Geist Mono', monospace`;
        ctx.textAlign = "center";
        ctx.textBaseline = "top";
        ctx.fillText(node.label, x, y + radius + 6);
      });

      // ── Title ──
      ctx.fillStyle = "#ffd700";
      ctx.font = "bold 14px 'Geist Mono', monospace";
      ctx.textAlign = "left";
      ctx.textBaseline = "top";
      ctx.fillText("🏛️ Cathedral Proof Dependency Graph", 16, 12);

      // ── Legend ──
      const legendY = h - 24;
      ctx.font = "9px 'Geist Mono', monospace";
      const items = [
        { color: "#00ff88", label: "Proved" },
        { color: "#ffd700", label: "Crown Axiom" },
        { color: "rgba(255,255,255,0.4)", label: "Lean Kernel" },
      ];
      let lx = 16;
      items.forEach((item) => {
        ctx.fillStyle = item.color;
        ctx.beginPath();
        ctx.arc(lx + 5, legendY, 4, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = TEXT_DIM;
        ctx.textAlign = "left";
        ctx.fillText(item.label, lx + 14, legendY + 3);
        lx += ctx.measureText(item.label).width + 30;
      });

      // ── Hover tooltip ──
      if (hoveredNode) {
        const pos = layout.get(hoveredNode.id);
        if (pos) {
          const tx = sx(pos.x) + 20;
          const ty = sy(pos.y) - 10;
          const padding = 8;
          const lines = [hoveredNode.leanFile, hoveredNode.description];
          const maxW = Math.max(...lines.map((l) => ctx.measureText(l).width)) + padding * 2;

          ctx.fillStyle = "rgba(5, 5, 8, 0.95)";
          ctx.strokeStyle = STATUS_COLORS[hoveredNode.status]?.stroke ?? "#00ff88";
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.roundRect(tx, ty, maxW, 42, 6);
          ctx.fill();
          ctx.stroke();

          ctx.fillStyle = "#00ccff";
          ctx.font = "bold 10px 'Geist Mono', monospace";
          ctx.textAlign = "left";
          ctx.fillText(hoveredNode.leanFile, tx + padding, ty + 14);

          ctx.fillStyle = TEXT_DIM;
          ctx.font = "9px 'Geist Mono', monospace";
          ctx.fillText(hoveredNode.description.slice(0, 60), tx + padding, ty + 30);
        }
      }
    },
    [hoveredNode]
  );

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d")!;
    const startTime = performance.now();

    const animate = () => {
      const dpr = window.devicePixelRatio || 1;
      const rect = canvas.getBoundingClientRect();
      canvas.width = rect.width * dpr;
      canvas.height = rect.height * dpr;
      ctx.scale(dpr, dpr);

      const t = (performance.now() - startTime) / 1000;
      draw(ctx, rect.width, rect.height, t);
      animRef.current = requestAnimationFrame(animate);
    };

    animRef.current = requestAnimationFrame(animate);
    return () => cancelAnimationFrame(animRef.current);
  }, [draw]);

  // Mouse hover detection
  const handleMouseMove = useCallback(
    (e: React.MouseEvent<HTMLCanvasElement>) => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;
      const scaleX = rect.width / 800;
      const scaleY = rect.height / 560;
      const layout = layoutRef.current;

      let found: ProofNode | null = null;
      for (const node of CATHEDRAL_NODES) {
        const pos = layout.get(node.id);
        if (!pos) continue;
        const dx = mx - pos.x * scaleX;
        const dy = my - pos.y * scaleY;
        if (dx * dx + dy * dy < 20 * 20) {
          found = node;
          break;
        }
      }
      setHoveredNode(found);
    },
    []
  );

  return (
    <canvas
      ref={canvasRef}
      className="chart-canvas"
      style={{ width: "100%", height: "100%", display: "block", cursor: hoveredNode ? "pointer" : "default" }}
      onMouseMove={handleMouseMove}
      onMouseLeave={() => setHoveredNode(null)}
    />
  );
}
