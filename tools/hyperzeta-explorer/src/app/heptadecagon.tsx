"use client";

import { useEffect, useRef, useState, useCallback } from "react";

// ═══════════════════════════════════════════════════════════════
// GAUSS'S HEPTADECAGON — THE 17-GON VISUALIZATION
// ═══════════════════════════════════════════════════════════════
//
// Gauss proved at age 19 (1796) that the regular 17-gon is
// constructible with compass and straightedge. The key insight:
// cos(2π/17) is expressible via nested square roots.
//
// The 17-gon connects to the Cathedral's Cayley-Dickson tower:
// 17 - 1 = 16 = 2⁴ vertices, folding as 16 → 8 → 4 → 2 → 1
// Each fold corresponds to: ℝ → ℂ → ℍ → 𝕆 → 𝕊
//
// This visualization shows:
// 1. The constructible 17-gon with animated compass/straightedge
// 2. The quadratic folding cascade (animated pairing of vertices)
// 3. Cayley-Dickson tower level overlay
// 4. The nested square root formula for cos(2π/17)
// ═══════════════════════════════════════════════════════════════

const TAU = 2 * Math.PI;
const N = 17;

// Cayley-Dickson layer names and colors
const CD_LAYERS = [
  { name: "𝕊₁₆", color: "#ff00aa", count: 16, label: "Sedenion (16D)" },
  { name: "𝕆₈", color: "#00ff88", count: 8, label: "Octonion (8D)" },
  { name: "ℍ₄", color: "#ffaa00", count: 4, label: "Quaternion (4D)" },
  { name: "ℂ₂", color: "#00aaff", count: 2, label: "Complex (2D)" },
  { name: "ℝ₁", color: "#ffffff", count: 1, label: "Real (1D)" },
];

// The 17th roots of unity
function getVertices(cx: number, cy: number, r: number): [number, number][] {
  const verts: [number, number][] = [];
  for (let k = 0; k < N; k++) {
    const angle = (TAU * k) / N - Math.PI / 2; // start from top
    verts.push([cx + r * Math.cos(angle), cy + r * Math.sin(angle)]);
  }
  return verts;
}

// Gauss's nested square root formula for cos(2π/17)
const GAUSS_FORMULA = `cos(2π/17) = ¹⁄₁₆(-1 + √17 + √(34-2√17) + 2√(17+3√17 - √(34-2√17) - 2√(34+2√17)))`;

interface HeptadecagonProps {
  width?: number;
  height?: number;
  interactive?: boolean;
}

export default function Heptadecagon({
  width = 700,
  height = 700,
  interactive = true,
}: HeptadecagonProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animRef = useRef<number>(0);
  const timeRef = useRef(0);
  const [foldLevel, setFoldLevel] = useState(0); // 0=full, 1-4=fold stages
  const [showConstruction, setShowConstruction] = useState(false);
  const [autoAnimate, setAutoAnimate] = useState(true);
  const [hoverVertex, setHoverVertex] = useState<number | null>(null);
  const [showFormula, setShowFormula] = useState(true);

  const cx = width / 2;
  const cy = height / 2;
  const R = Math.min(width, height) * 0.35;

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const t = timeRef.current;
    const dpr = window.devicePixelRatio || 1;

    canvas.width = width * dpr;
    canvas.height = height * dpr;
    ctx.scale(dpr, dpr);

    // Clear
    ctx.clearRect(0, 0, width, height);

    // Background glow
    const bgGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, R * 1.8);
    bgGrad.addColorStop(0, "rgba(100, 0, 180, 0.08)");
    bgGrad.addColorStop(0.5, "rgba(0, 100, 255, 0.03)");
    bgGrad.addColorStop(1, "transparent");
    ctx.fillStyle = bgGrad;
    ctx.fillRect(0, 0, width, height);

    const verts = getVertices(cx, cy, R);

    // ── Construction circles (compass) ──
    if (showConstruction) {
      ctx.strokeStyle = "rgba(100, 100, 255, 0.15)";
      ctx.lineWidth = 0.5;
      // The main circle
      ctx.beginPath();
      ctx.arc(cx, cy, R, 0, TAU);
      ctx.stroke();
      // Gauss's construction circles
      const r2 = R * 0.5;
      ctx.beginPath();
      ctx.arc(cx, cy, r2, 0, TAU);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(cx + r2, cy, r2, 0, TAU);
      ctx.stroke();
      // Cross lines
      ctx.beginPath();
      ctx.moveTo(cx - R * 1.2, cy);
      ctx.lineTo(cx + R * 1.2, cy);
      ctx.moveTo(cx, cy - R * 1.2);
      ctx.lineTo(cx, cy + R * 1.2);
      ctx.stroke();
    }

    // ── The 17-gon edges ──
    const activeFold = autoAnimate
      ? Math.floor((t * 0.3) % 6)
      : foldLevel;

    // Draw polygon edges
    ctx.lineWidth = 1.5;
    for (let i = 0; i < N; i++) {
      const j = (i + 1) % N;
      const [x1, y1] = verts[i];
      const [x2, y2] = verts[j];

      // Color edges by which fold group they belong to
      const groupColor = getVertexColor(i, activeFold, t);
      ctx.strokeStyle = groupColor;
      ctx.globalAlpha = 0.6;
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.stroke();
      ctx.globalAlpha = 1;
    }

    // ── Fold pairing arcs ──
    if (activeFold > 0 && activeFold <= 4) {
      drawFoldArcs(ctx, verts, activeFold, t);
    }

    // ── Vertices ──
    for (let k = 0; k < N; k++) {
      const [vx, vy] = verts[k];
      const isCenter = k === 0;
      const vColor = getVertexColor(k, activeFold, t);

      // Glow
      const glowR = isCenter ? 20 : 12;
      const glow = ctx.createRadialGradient(vx, vy, 0, vx, vy, glowR);
      glow.addColorStop(0, withAlpha(vColor, 0.53));
      glow.addColorStop(1, "transparent");
      ctx.fillStyle = glow;
      ctx.fillRect(vx - glowR, vy - glowR, glowR * 2, glowR * 2);

      // Dot
      const dotR = hoverVertex === k ? 6 : isCenter ? 5 : 3.5;
      const pulse = Math.sin(t * 3 + k * 0.5) * 0.3 + 1;
      ctx.beginPath();
      ctx.arc(vx, vy, dotR * pulse, 0, TAU);
      ctx.fillStyle = vColor;
      ctx.fill();

      // Label
      if (hoverVertex === k || !autoAnimate) {
        ctx.font = "bold 11px 'Inter', monospace";
        ctx.fillStyle = "#ffffff";
        ctx.textAlign = "center";
        const labelAngle = (TAU * k) / N - Math.PI / 2;
        const lx = vx + Math.cos(labelAngle) * 20;
        const ly = vy + Math.sin(labelAngle) * 20;
        ctx.fillText(
          isCenter ? "ω⁰ = 1" : `ω${superscript(k)}`,
          lx,
          ly
        );
      }
    }

    // ── Center marker ──
    ctx.font = "bold 13px 'Inter', monospace";
    ctx.fillStyle = "#ffffff88";
    ctx.textAlign = "center";
    ctx.fillText("17", cx, cy + 4);

    // ── Cayley-Dickson tower legend ──
    if (activeFold > 0) {
      drawCDLegend(ctx, activeFold, t);
    }

    // ── Title ──
    ctx.font = "bold 16px 'Inter', sans-serif";
    ctx.fillStyle = "#ffffff";
    ctx.textAlign = "center";
    ctx.fillText("GAUSS'S HEPTADECAGON", cx, 28);

    ctx.font = "12px 'Inter', monospace";
    ctx.fillStyle = "#888888";
    ctx.fillText(
      activeFold === 0
        ? "17 vertices · 16 = 2⁴ roots of unity"
        : `Fold ${activeFold}/4: ${16 / Math.pow(2, activeFold)} → ${16 / Math.pow(2, activeFold - 1)} groups · ${CD_LAYERS[activeFold - 1].label}`,
      cx,
      48
    );

    // ── Formula ──
    if (showFormula) {
      ctx.font = "10px 'Inter', monospace";
      ctx.fillStyle = "#aa88ff";
      ctx.textAlign = "center";
      ctx.fillText(GAUSS_FORMULA, cx, height - 16);
    }
  }, [
    width,
    height,
    cx,
    cy,
    R,
    foldLevel,
    showConstruction,
    autoAnimate,
    hoverVertex,
    showFormula,
  ]);

  // Convert HSL to hex for canvas compatibility
  function hslToHex(h: number, s: number, l: number): string {
    s /= 100;
    l /= 100;
    const a = s * Math.min(l, 1 - l);
    const f = (n: number) => {
      const k = (n + h / 30) % 12;
      const color = l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
      return Math.round(255 * color).toString(16).padStart(2, "0");
    };
    return `#${f(0)}${f(8)}${f(4)}`;
  }

  // Add alpha to a hex color
  function withAlpha(hex: string, alpha: number): string {
    // Ensure hex is 7 chars (#rrggbb)
    const clean = hex.length === 9 ? hex.slice(0, 7) : hex;
    const r = parseInt(clean.slice(1, 3), 16);
    const g = parseInt(clean.slice(3, 5), 16);
    const b = parseInt(clean.slice(5, 7), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }

  function getVertexColor(k: number, fold: number, _t: number): string {
    if (k === 0) return "#ffffff"; // center vertex is always white (the 1)
    const idx = k - 1; // 0-15 for the 16 nontrivial roots

    if (fold === 0) {
      // Full 17-gon: rainbow
      const hue = (idx / 16) * 360;
      return hslToHex(hue, 80, 65);
    }

    // Fold groups: pair indices
    const groupSize = Math.pow(2, 5 - fold); // fold 1→16, fold 2→8, fold 3→4, fold 4→2
    const groupIdx = Math.floor(idx / groupSize);

    // Alternate brightness
    if (groupIdx % 2 === 0) {
      return CD_LAYERS[fold - 1].color;
    } else {
      // Slightly dimmer variant
      const base = CD_LAYERS[fold - 1].color;
      const r = Math.round(parseInt(base.slice(1, 3), 16) * 0.7);
      const g = Math.round(parseInt(base.slice(3, 5), 16) * 0.7);
      const b = Math.round(parseInt(base.slice(5, 7), 16) * 0.7);
      return `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`;
    }
  }

  function drawFoldArcs(
    ctx: CanvasRenderingContext2D,
    verts: [number, number][],
    fold: number,
    t: number
  ) {
    const groupSize = Math.pow(2, 5 - fold);
    const numGroups = 16 / groupSize;
    const color = CD_LAYERS[fold - 1].color;

    const animProgress = Math.min((t * 0.5) % 3, 1); // 0→1 animation

    for (let g = 0; g < numGroups; g++) {
      const startIdx = g * groupSize + 1; // +1 because vertex 0 is the center
      const endIdx = startIdx + groupSize - 1;

      if (startIdx >= N || endIdx >= N) continue;

      const [x1, y1] = verts[startIdx];
      const [x2, y2] = verts[Math.min(endIdx, N - 1)];

      // Draw pairing arc
      const midX = (x1 + x2) / 2;
      const midY = (y1 + y2) / 2;

      ctx.strokeStyle = withAlpha(color, 0.4);
      ctx.lineWidth = 1;
      ctx.setLineDash([4, 4]);

      // Animated dash offset
      ctx.lineDashOffset = -t * 20;

      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.quadraticCurveTo(
        midX + (midX - cx) * 0.3 * animProgress,
        midY + (midY - cy) * 0.3 * animProgress,
        x2,
        y2
      );
      ctx.stroke();
      ctx.setLineDash([]);

      // Group label
      if (animProgress > 0.5) {
        ctx.font = "bold 10px 'Inter', monospace";
        ctx.fillStyle = withAlpha(color, 0.8);
        ctx.textAlign = "center";
        const labelX = midX + (midX - cx) * 0.15;
        const labelY = midY + (midY - cy) * 0.15;
        ctx.fillText(`G${g + 1}`, labelX, labelY);
      }
    }
  }

  function drawCDLegend(
    ctx: CanvasRenderingContext2D,
    fold: number,
    t: number
  ) {
    const x0 = 16;
    const y0 = height - 120;

    for (let i = 0; i < CD_LAYERS.length; i++) {
      const layer = CD_LAYERS[i];
      const isActive = i === fold - 1;
      const y = y0 + i * 20;

      // Dot
      ctx.beginPath();
      ctx.arc(x0 + 8, y, isActive ? 5 : 3, 0, TAU);
      ctx.fillStyle = isActive ? layer.color : withAlpha(layer.color, 0.27);
      ctx.fill();

      if (isActive) {
        const glow = ctx.createRadialGradient(x0 + 8, y, 0, x0 + 8, y, 12);
        glow.addColorStop(0, withAlpha(layer.color, 0.27));
        glow.addColorStop(1, "transparent");
        ctx.fillStyle = glow;
        ctx.fillRect(x0 - 4, y - 12, 24, 24);
      }

      // Label
      ctx.font = isActive ? "bold 11px 'Inter', monospace" : "10px 'Inter', monospace";
      ctx.fillStyle = isActive ? "#ffffff" : "#666666";
      ctx.textAlign = "left";
      ctx.fillText(
        `${layer.name} → ${layer.count} pairs`,
        x0 + 20,
        y + 4
      );

      // Arrow between levels
      if (i < CD_LAYERS.length - 1) {
        ctx.fillStyle = "#333333";
        ctx.font = "8px monospace";
        ctx.fillText("↓ fold", x0 + 2, y + 13);
      }
    }
  }

  // Animation loop
  useEffect(() => {
    let running = true;

    const animate = () => {
      if (!running) return;
      timeRef.current += 0.016;
      draw();
      animRef.current = requestAnimationFrame(animate);
    };

    animate();
    return () => {
      running = false;
      cancelAnimationFrame(animRef.current);
    };
  }, [draw]);

  // Mouse hover detection
  const handleMouseMove = useCallback(
    (e: React.MouseEvent<HTMLCanvasElement>) => {
      if (!interactive) return;
      const canvas = canvasRef.current;
      if (!canvas) return;
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;

      const verts = getVertices(cx, cy, R);
      let closest = -1;
      let minDist = 20;

      for (let k = 0; k < N; k++) {
        const [vx, vy] = verts[k];
        const dist = Math.hypot(mx - vx, my - vy);
        if (dist < minDist) {
          minDist = dist;
          closest = k;
        }
      }

      setHoverVertex(closest >= 0 ? closest : null);
    },
    [cx, cy, R, interactive]
  );

  return (
    <div
      style={{
        position: "relative",
        width,
        height,
        background: "rgba(0, 0, 0, 0.3)",
        borderRadius: "12px",
        border: "1px solid rgba(100, 50, 200, 0.3)",
        overflow: "hidden",
      }}
    >
      <canvas
        ref={canvasRef}
        style={{ width, height, cursor: interactive ? "crosshair" : "default" }}
        onMouseMove={handleMouseMove}
        onMouseLeave={() => setHoverVertex(null)}
      />

      {/* Controls */}
      {interactive && (
        <div
          style={{
            position: "absolute",
            top: 60,
            right: 12,
            display: "flex",
            flexDirection: "column",
            gap: 6,
          }}
        >
          <button
            onClick={() => setAutoAnimate(!autoAnimate)}
            style={btnStyle(autoAnimate)}
          >
            {autoAnimate ? "⏸ Auto" : "▶ Auto"}
          </button>
          <button
            onClick={() => setShowConstruction(!showConstruction)}
            style={btnStyle(showConstruction)}
          >
            {showConstruction ? "⊙ Hide" : "⊙ Show"} Compass
          </button>
          <button
            onClick={() => setShowFormula(!showFormula)}
            style={btnStyle(showFormula)}
          >
            {showFormula ? "f(x) Hide" : "f(x) Show"} Formula
          </button>

          {!autoAnimate && (
            <div style={{ display: "flex", flexDirection: "column", gap: 4, marginTop: 8 }}>
              {[0, 1, 2, 3, 4].map((level) => (
                <button
                  key={level}
                  onClick={() => setFoldLevel(level)}
                  style={{
                    ...btnStyle(foldLevel === level),
                    fontSize: "10px",
                    padding: "3px 8px",
                  }}
                >
                  {level === 0
                    ? "Full 17-gon"
                    : `Fold ${level}: ${CD_LAYERS[level - 1].name}`}
                </button>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function superscript(n: number): string {
  const digits = "⁰¹²³⁴⁵⁶⁷⁸⁹";
  return String(n)
    .split("")
    .map((d) => digits[parseInt(d)])
    .join("");
}

function btnStyle(active: boolean): React.CSSProperties {
  return {
    background: active ? "rgba(100, 50, 200, 0.4)" : "rgba(255,255,255,0.05)",
    color: active ? "#ffffff" : "#888888",
    border: `1px solid ${active ? "rgba(100, 50, 200, 0.6)" : "rgba(255,255,255,0.1)"}`,
    borderRadius: "6px",
    padding: "4px 10px",
    fontSize: "11px",
    fontFamily: "'Inter', monospace",
    cursor: "pointer",
    transition: "all 0.2s ease",
  };
}
