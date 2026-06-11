"use client";
import { useState, useRef, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import Link from "next/link";

/* ───────── constants ───────── */

const EULER_GAMMA = 0.5772156649015329;
const L1 = -EULER_GAMMA - Math.log(4 * Math.PI);  // ≈ -3.108
const BD_COEFF = 1.005;  // d² ≈ 1.005/ln(N)

/* ───────── math helpers ───────── */

/** Approximate F(N) = (vᵀGv - 1)·ln(N) — the running coupling */
function gramEnergy(N: number): number {
  if (N < 2) return 0;
  const s = Math.log(N);
  // Model: F(s) = L₁ + A/s^α where A ≈ 3.5, α ≈ 0.82
  return L1 + 3.5 / Math.pow(s, 0.82);
}

/** Beta function: dF/ds ≈ -1.76/s^1.82 */
function betaFunction(s: number): number {
  if (s < 1) return 0;
  return -1.76 / Math.pow(s, 1.82);
}

/** d² ≈ 1.005/ln(N) — the BD distance */
function bdDistance(N: number): number {
  if (N < 2) return 1;
  return BD_COEFF / Math.log(N);
}

/** Coprime fraction of energy (approximate) */
function coprimeFraction(N: number): number {
  // Approaches 6/π² ≈ 0.6079 — the probability two random integers are coprime
  const base = 6 / (Math.PI * Math.PI);
  return base + (1 - base) * Math.exp(-Math.log(N) / 3);
}

/* ───────── canvas drawing ───────── */

function drawRGFlow(
  canvas: HTMLCanvasElement,
  currentN: number,
  animPhase: number,
) {
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  const W = canvas.width;
  const H = canvas.height;
  const pad = { top: 40, right: 30, bottom: 50, left: 60 };
  const plotW = W - pad.left - pad.right;
  const plotH = H - pad.top - pad.bottom;

  // Clear
  ctx.fillStyle = "#0a0b14";
  ctx.fillRect(0, 0, W, H);

  // s range: 1 to 12 (N = e to e^12 ≈ 162,000)
  const sMin = 1, sMax = 12;
  // F range: L1-0.5 to 2
  const fMin = L1 - 0.5, fMax = 2;

  const toX = (s: number) => pad.left + ((s - sMin) / (sMax - sMin)) * plotW;
  const toY = (f: number) => pad.top + ((fMax - f) / (fMax - fMin)) * plotH;

  // Grid lines
  ctx.strokeStyle = "#1e2148";
  ctx.lineWidth = 1;
  for (let f = -3; f <= 2; f++) {
    const y = toY(f);
    ctx.beginPath();
    ctx.moveTo(pad.left, y);
    ctx.lineTo(W - pad.right, y);
    ctx.stroke();
  }
  for (let s = 2; s <= 12; s += 2) {
    const x = toX(s);
    ctx.beginPath();
    ctx.moveTo(x, pad.top);
    ctx.lineTo(x, H - pad.bottom);
    ctx.stroke();
  }

  // Fixed point line L₁
  ctx.strokeStyle = "#f59e0b40";
  ctx.lineWidth = 2;
  ctx.setLineDash([8, 6]);
  const yL1 = toY(L1);
  ctx.beginPath();
  ctx.moveTo(pad.left, yL1);
  ctx.lineTo(W - pad.right, yL1);
  ctx.stroke();
  ctx.setLineDash([]);

  // Label L₁
  ctx.fillStyle = "#f59e0b";
  ctx.font = "bold 11px monospace";
  ctx.textAlign = "left";
  ctx.fillText(`L₁ = ${L1.toFixed(3)}`, pad.left + 4, yL1 - 6);

  // F = 0 line
  ctx.strokeStyle = "#ffffff15";
  ctx.lineWidth = 1;
  const y0 = toY(0);
  ctx.beginPath();
  ctx.moveTo(pad.left, y0);
  ctx.lineTo(W - pad.right, y0);
  ctx.stroke();

  // Draw the RG flow curve F(s) — main curve with glow
  const pts: [number, number][] = [];
  for (let px = 0; px <= plotW; px++) {
    const s = sMin + (px / plotW) * (sMax - sMin);
    const N = Math.exp(s);
    const f = gramEnergy(N);
    pts.push([toX(s), toY(f)]);
  }

  // Glow
  ctx.strokeStyle = "#f43f5e30";
  ctx.lineWidth = 8;
  ctx.beginPath();
  pts.forEach(([x, y], i) => (i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)));
  ctx.stroke();

  // Main curve
  const gradient = ctx.createLinearGradient(pad.left, 0, W - pad.right, 0);
  gradient.addColorStop(0, "#f43f5e");
  gradient.addColorStop(0.5, "#f59e0b");
  gradient.addColorStop(1, "#10b981");
  ctx.strokeStyle = gradient;
  ctx.lineWidth = 3;
  ctx.beginPath();
  pts.forEach(([x, y], i) => (i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)));
  ctx.stroke();

  // Fill under curve to L₁ with translucent gradient
  ctx.beginPath();
  pts.forEach(([x, y], i) => (i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)));
  ctx.lineTo(pts[pts.length - 1][0], yL1);
  ctx.lineTo(pts[0][0], yL1);
  ctx.closePath();
  const fillGrad = ctx.createLinearGradient(0, pad.top, 0, yL1);
  fillGrad.addColorStop(0, "#f43f5e10");
  fillGrad.addColorStop(1, "#f59e0b05");
  ctx.fillStyle = fillGrad;
  ctx.fill();

  // Current N marker
  const sN = Math.log(currentN);
  if (sN >= sMin && sN <= sMax) {
    const xN = toX(sN);
    const fN = gramEnergy(currentN);
    const yN = toY(fN);

    // Vertical line
    ctx.strokeStyle = "#ffffff30";
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 4]);
    ctx.beginPath();
    ctx.moveTo(xN, pad.top);
    ctx.lineTo(xN, H - pad.bottom);
    ctx.stroke();
    ctx.setLineDash([]);

    // Glowing dot
    ctx.beginPath();
    ctx.arc(xN, yN, 8 + Math.sin(animPhase * 3) * 2, 0, Math.PI * 2);
    ctx.fillStyle = "#f43f5e30";
    ctx.fill();
    ctx.beginPath();
    ctx.arc(xN, yN, 5, 0, Math.PI * 2);
    ctx.fillStyle = "#f43f5e";
    ctx.fill();
    ctx.strokeStyle = "#fff";
    ctx.lineWidth = 1.5;
    ctx.stroke();

    // Value label
    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 11px monospace";
    ctx.textAlign = "center";
    ctx.fillText(`F = ${fN.toFixed(3)}`, xN, yN - 16);
  }

  // Animated flow arrows (showing direction of RG flow)
  const arrowPhase = (animPhase * 0.5) % 1;
  for (let i = 0; i < 5; i++) {
    const frac = ((arrowPhase + i * 0.2) % 1);
    const s = sMin + frac * (sMax - sMin);
    const N = Math.exp(s);
    const f = gramEnergy(N);
    const x = toX(s);
    const y = toY(f);
    const alpha = Math.sin(frac * Math.PI) * 0.6;

    ctx.fillStyle = `rgba(245, 158, 11, ${alpha})`;
    ctx.beginPath();
    // Small right-pointing arrow
    ctx.moveTo(x + 6, y);
    ctx.lineTo(x - 2, y - 4);
    ctx.lineTo(x - 2, y + 4);
    ctx.closePath();
    ctx.fill();
  }

  // Axes labels
  ctx.fillStyle = "#64748b";
  ctx.font = "12px sans-serif";
  ctx.textAlign = "center";
  ctx.fillText("s = ln N", pad.left + plotW / 2, H - 10);
  ctx.save();
  ctx.translate(16, pad.top + plotH / 2);
  ctx.rotate(-Math.PI / 2);
  ctx.fillText("F(s) = (vᵀGv − 1)·ln N", 0, 0);
  ctx.restore();

  // s-axis tick labels
  ctx.fillStyle = "#475569";
  ctx.font = "10px monospace";
  ctx.textAlign = "center";
  for (let s = 2; s <= 12; s += 2) {
    const N = Math.exp(s);
    ctx.fillText(`${s}`, toX(s), H - pad.bottom + 15);
    ctx.fillStyle = "#334155";
    ctx.fillText(`N≈${N < 1000 ? Math.round(N) : Math.round(N/1000) + "K"}`, toX(s), H - pad.bottom + 27);
    ctx.fillStyle = "#475569";
  }

  // Title
  ctx.fillStyle = "#e2e8f0";
  ctx.font = "bold 14px sans-serif";
  ctx.textAlign = "left";
  ctx.fillText("Renormalization Group Flow", pad.left, 24);
  ctx.fillStyle = "#64748b";
  ctx.font = "11px sans-serif";
  ctx.fillText("F(s) → L₁  (asymptotic freedom)", pad.left + 230, 24);
}

function drawBetaFunction(
  canvas: HTMLCanvasElement,
  currentN: number,
) {
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  const W = canvas.width;
  const H = canvas.height;
  const pad = { top: 30, right: 20, bottom: 40, left: 50 };
  const plotW = W - pad.left - pad.right;
  const plotH = H - pad.top - pad.bottom;

  ctx.fillStyle = "#0a0b14";
  ctx.fillRect(0, 0, W, H);

  const sMin = 1, sMax = 12;
  const bMin = -0.8, bMax = 0.05;

  const toX = (s: number) => pad.left + ((s - sMin) / (sMax - sMin)) * plotW;
  const toY = (b: number) => pad.top + ((bMax - b) / (bMax - bMin)) * plotH;

  // Zero line
  ctx.strokeStyle = "#ffffff15";
  ctx.lineWidth = 1;
  const y0 = toY(0);
  ctx.beginPath();
  ctx.moveTo(pad.left, y0);
  ctx.lineTo(W - pad.right, y0);
  ctx.stroke();

  // β < 0 fill
  ctx.beginPath();
  ctx.moveTo(toX(sMin), y0);
  for (let px = 0; px <= plotW; px++) {
    const s = sMin + (px / plotW) * (sMax - sMin);
    const b = betaFunction(s);
    ctx.lineTo(toX(s), toY(Math.max(b, bMin)));
  }
  ctx.lineTo(toX(sMax), y0);
  ctx.closePath();
  ctx.fillStyle = "#06b6d420";
  ctx.fill();

  // Beta curve
  ctx.strokeStyle = "#06b6d4";
  ctx.lineWidth = 2.5;
  ctx.beginPath();
  for (let px = 0; px <= plotW; px++) {
    const s = sMin + (px / plotW) * (sMax - sMin);
    const b = betaFunction(s);
    const x = toX(s);
    const y = toY(Math.max(b, bMin));
    px === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
  }
  ctx.stroke();

  // Current N marker
  const sN = Math.log(currentN);
  if (sN >= sMin && sN <= sMax) {
    const xN = toX(sN);
    const bN = betaFunction(sN);
    const yN = toY(bN);

    ctx.beginPath();
    ctx.arc(xN, yN, 5, 0, Math.PI * 2);
    ctx.fillStyle = "#06b6d4";
    ctx.fill();
    ctx.strokeStyle = "#fff";
    ctx.lineWidth = 1.5;
    ctx.stroke();

    ctx.fillStyle = "#fff";
    ctx.font = "bold 10px monospace";
    ctx.textAlign = "center";
    ctx.fillText(`β = ${bN.toFixed(4)}`, xN, yN - 10);
  }

  // Labels
  ctx.fillStyle = "#e2e8f0";
  ctx.font = "bold 12px sans-serif";
  ctx.textAlign = "left";
  ctx.fillText("β(s) < 0  →  Asymptotic Freedom", pad.left, 20);

  ctx.fillStyle = "#64748b";
  ctx.font = "10px sans-serif";
  ctx.textAlign = "center";
  ctx.fillText("s = ln N", pad.left + plotW / 2, H - 8);

  ctx.fillStyle = "#06b6d4";
  ctx.font = "10px monospace";
  ctx.textAlign = "right";
  ctx.fillText("β(s) ≈ −1.76/s¹·⁸²", W - pad.right, 20);
}

/* ───────── sector bar component ───────── */

function SectorBar({ N }: { N: number }) {
  const coprime = coprimeFraction(N);
  const noncoprime = 1 - coprime;

  return (
    <div>
      <div className="flex rounded-lg overflow-hidden h-6 gap-0.5">
        <motion.div
          className="bg-gradient-to-r from-rose-500 to-rose-400 flex items-center justify-center"
          animate={{ width: `${coprime * 100}%` }}
          transition={{ duration: 0.5, ease: "easeOut" }}
        >
          <span className="text-[9px] font-bold text-white">
            coprime {(coprime * 100).toFixed(1)}%
          </span>
        </motion.div>
        <motion.div
          className="bg-gradient-to-r from-cyan-600 to-cyan-500 flex items-center justify-center"
          animate={{ width: `${noncoprime * 100}%` }}
          transition={{ duration: 0.5, ease: "easeOut" }}
        >
          <span className="text-[9px] font-bold text-white">
            non {(noncoprime * 100).toFixed(1)}%
          </span>
        </motion.div>
      </div>
      <div className="flex justify-between text-[9px] text-slate-600 mt-1 px-1">
        <span>gcd(j,k) = 1 → destructive interference</span>
        <span>gcd(j,k) &gt; 1 → subleading</span>
      </div>
    </div>
  );
}

/* ───────── page ───────── */

export default function RGFlowPage() {
  const [logN, setLogN] = useState(7); // s = ln(N), N ≈ 1097
  const N = Math.round(Math.exp(logN));
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const betaRef = useRef<HTMLCanvasElement>(null);
  const animRef = useRef(0);
  const frameRef = useRef<number>(0);

  const draw = useCallback(() => {
    animRef.current += 0.02;
    if (canvasRef.current) {
      drawRGFlow(canvasRef.current, N, animRef.current);
    }
    if (betaRef.current) {
      drawBetaFunction(betaRef.current, N);
    }
    frameRef.current = requestAnimationFrame(draw);
  }, [N]);

  useEffect(() => {
    frameRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(frameRef.current);
  }, [draw]);

  const F = gramEnergy(N);
  const beta = betaFunction(logN);
  const d2 = bdDistance(N);

  return (
    <div className="p-8 max-w-5xl mx-auto">
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
        <Link
          href="/"
          className="text-xs text-slate-600 hover:text-slate-400 transition-colors"
        >
          &larr; Back to Cathedral
        </Link>
        <h1 className="text-3xl font-bold mt-3">
          <span className="bg-gradient-to-r from-rose-400 via-amber-400 to-cyan-400 bg-clip-text text-transparent">
            Renormalization Group Flow
          </span>
        </h1>
        <p className="text-slate-400 mt-2 max-w-2xl">
          The Gram energy F(s) = (v<sup>T</sup>Gv − 1)·ln N flows to the
          fixed point L₁ = −γ − ln(4π) ≈ {L1.toFixed(3)}. The negative beta
          function β(s) {"<"} 0 is the number-theoretic analogue of{" "}
          <strong className="text-cyan-400">asymptotic freedom</strong> in QCD.
        </p>
      </motion.div>

      {/* Interactive slider */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.3 }}
        className="mt-6 p-5 rounded-xl bg-gradient-to-r from-[#12142a] to-[#0d0e1a] border border-slate-700/30"
      >
        <div className="flex items-center justify-between mb-3">
          <div className="text-sm text-slate-300">
            <span className="text-slate-500">N = </span>
            <span className="text-xl font-bold font-mono text-amber-400">
              {N.toLocaleString()}
            </span>
            <span className="text-slate-500 ml-2">
              (s = ln N = {logN.toFixed(1)})
            </span>
          </div>
          <div className="flex gap-6 text-xs font-mono">
            <div>
              <span className="text-slate-500">F(s) = </span>
              <span className="text-rose-400 font-bold">{F.toFixed(3)}</span>
            </div>
            <div>
              <span className="text-slate-500">β(s) = </span>
              <span className="text-cyan-400 font-bold">{beta.toFixed(4)}</span>
            </div>
            <div>
              <span className="text-slate-500">d² = </span>
              <span className="text-emerald-400 font-bold">{d2.toFixed(4)}</span>
            </div>
          </div>
        </div>
        <input
          type="range"
          min="1.5"
          max="11"
          step="0.05"
          value={logN}
          onChange={(e) => setLogN(parseFloat(e.target.value))}
          className="w-full h-2 rounded-full appearance-none cursor-pointer"
          style={{
            background: `linear-gradient(to right, #f43f5e, #f59e0b, #10b981)`,
          }}
        />
        <div className="flex justify-between text-[9px] text-slate-600 mt-1">
          <span>N ≈ 5</span>
          <span>N ≈ 100</span>
          <span>N ≈ 1,000</span>
          <span>N ≈ 10,000</span>
          <span>N ≈ 60,000</span>
        </div>
      </motion.div>

      {/* Main RG flow canvas */}
      <motion.div
        initial={{ opacity: 0, scale: 0.98 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.4 }}
        className="mt-6 rounded-xl overflow-hidden border border-slate-700/30"
      >
        <canvas
          ref={canvasRef}
          width={900}
          height={400}
          className="w-full"
          style={{ imageRendering: "auto" }}
        />
      </motion.div>

      {/* Beta function + Sector decomposition */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
        <motion.div
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ delay: 0.5 }}
          className="rounded-xl overflow-hidden border border-slate-700/30"
        >
          <canvas
            ref={betaRef}
            width={450}
            height={250}
            className="w-full"
          />
        </motion.div>

        <motion.div
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ delay: 0.6 }}
          className="rounded-xl p-5 border border-slate-700/30 bg-[#0d0e1a]"
        >
          <h3 className="text-sm font-bold text-slate-200 mb-3">
            Coprime Sector Decomposition
          </h3>
          <SectorBar N={N} />
          <div className="mt-4 space-y-3 text-xs text-slate-400">
            <p>
              The Gram energy decomposes into{" "}
              <span className="text-rose-400 font-bold">coprime</span> fibers
              (gcd = 1, destructive interference) and{" "}
              <span className="text-cyan-400 font-bold">noncoprime</span> fibers
              (gcd {">"} 1, subleading via GCD reduction).
            </p>
            <p>
              As N → ∞, the coprime fraction approaches{" "}
              <code className="text-amber-400">6/π² ≈ 60.8%</code>{" "}
              — the probability two random integers are coprime.
              The Möbius signs create the destructive interference
              that drives β(s) {"<"} 0.
            </p>
          </div>

          {/* Physics analogy */}
          <div className="mt-4 pt-3 border-t border-slate-700/30">
            <h4 className="text-[10px] text-slate-500 uppercase tracking-wider mb-2">
              Physics Analogy
            </h4>
            <div className="grid grid-cols-2 gap-2 text-[10px]">
              {[
                ["β(s) < 0", "Asymptotic freedom"],
                ["F → L₁", "IR fixed point"],
                ["coprime fibers", "Color channels"],
                ["Möbius signs", "Gauge phases"],
                ["d² → 0", "Vacuum stability"],
                ["Selberg sieve", "Λ² weights"],
              ].map(([math, phys]) => (
                <div key={math} className="flex items-center gap-2">
                  <code className="text-rose-400">{math}</code>
                  <span className="text-slate-600">→</span>
                  <span className="text-slate-400">{phys}</span>
                </div>
              ))}
            </div>
          </div>
        </motion.div>
      </div>

      {/* Architecture reference */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.8 }}
        className="mt-6 p-5 rounded-xl bg-gradient-to-r from-emerald-500/5 via-transparent to-transparent border border-emerald-500/20"
      >
        <h3 className="text-sm font-bold text-emerald-400 mb-2">
          Cathedral Implementation
        </h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-[10px]">
          {[
            ["RGFlow.lean", "809 lines", "Beta function"],
            ["CoprimeSector.lean", "472 lines", "Channel decomp"],
            ["SelbergBridge.lean", "631 lines", "Sieve connection"],
            ["MassRenormalization.lean", "305 lines", "K₁ + L₁ split"],
          ].map(([file, lines, desc]) => (
            <div key={file} className="p-2 rounded bg-slate-800/50 border border-slate-700/30">
              <code className="text-emerald-400 block">{file}</code>
              <span className="text-slate-500">{lines} · {desc}</span>
            </div>
          ))}
        </div>
        <p className="text-[10px] text-slate-600 mt-2 font-mono">
          18 files · 6,041 total lines · 0 errors · 0 warnings
        </p>
      </motion.div>

      {/* Footer */}
      <div className="text-center text-xs text-slate-600 mt-8 pt-4 border-t border-slate-800">
        Renormalization Group Flow &mdash; v26 Penta-Crown &mdash; The vacuum is permanently stable 🍓
      </div>
    </div>
  );
}
