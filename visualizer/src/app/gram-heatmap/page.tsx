"use client";
import { useEffect, useRef, useState, useCallback } from "react";
import { motion } from "framer-motion";
import { gramEntry } from "@/lib/math";

export default function GramHeatmapPage() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [N, setN] = useState(30);
  const [hoveredCell, setHoveredCell] = useState<{ j: number; k: number; val: number } | null>(null);
  const [computing, setComputing] = useState(false);
  const matrixRef = useRef<Float64Array | null>(null);

  const computeMatrix = useCallback((size: number) => {
    setComputing(true);
    const matrix = new Float64Array(size * size);
    for (let j = 0; j < size; j++) {
      for (let k = j; k < size; k++) {
        const val = gramEntry(j + 1, k + 1, 500);
        matrix[j * size + k] = val;
        matrix[k * size + j] = val;
      }
    }
    matrixRef.current = matrix;
    setComputing(false);
    return matrix;
  }, []);

  useEffect(() => {
    const matrix = computeMatrix(N);
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const cellSize = Math.min(600, canvas.parentElement!.clientWidth - 40) / N;
    canvas.width = N * cellSize;
    canvas.height = N * cellSize;

    // Find min/max for color scale
    let min = Infinity, max = -Infinity;
    for (let i = 0; i < matrix.length; i++) {
      if (matrix[i] < min) min = matrix[i];
      if (matrix[i] > max) max = matrix[i];
    }

    // Color scale: blue (low) → dark (0.25) → red (high)
    const colorScale = (val: number): string => {
      const center = 0.25;
      if (val >= center) {
        const t = Math.min((val - center) / (max - center), 1);
        const r = Math.round(30 + 225 * t);
        const g = Math.round(30 + 40 * t);
        const b = Math.round(40);
        return `rgb(${r},${g},${b})`;
      } else {
        const t = Math.min((center - val) / (center - min), 1);
        const r = Math.round(30);
        const g = Math.round(30 + 40 * t);
        const b = Math.round(40 + 200 * t);
        return `rgb(${r},${g},${b})`;
      }
    };

    // Draw
    for (let j = 0; j < N; j++) {
      for (let k = 0; k < N; k++) {
        const val = matrix[j * N + k];
        ctx.fillStyle = colorScale(val);
        ctx.fillRect(k * cellSize, j * cellSize, cellSize, cellSize);

        if (cellSize > 2) {
          ctx.strokeStyle = "#0a0b14";
          ctx.lineWidth = 0.5;
          ctx.strokeRect(k * cellSize, j * cellSize, cellSize, cellSize);
        }
      }
    }

    // Mouse handler
    const handleMouse = (e: MouseEvent) => {
      const rect = canvas.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      const k = Math.floor(x / cellSize);
      const j = Math.floor(y / cellSize);
      if (j >= 0 && j < N && k >= 0 && k < N) {
        setHoveredCell({ j: j + 1, k: k + 1, val: matrix[j * N + k] });
      } else {
        setHoveredCell(null);
      }
    };

    canvas.addEventListener("mousemove", handleMouse);
    canvas.addEventListener("mouseleave", () => setHoveredCell(null));

    return () => {
      canvas.removeEventListener("mousemove", handleMouse);
    };
  }, [N, computeMatrix]);

  return (
    <div className="h-full flex flex-col">
      <div className="p-6 border-b border-[#1e2148]">
        <h2 className="text-2xl font-bold text-slate-200">Gram Matrix Heatmap</h2>
        <p className="text-sm text-slate-500 mt-1">
          G<sub>jk</sub> = ∫₀¹ {"{"}j/x{"}"}{"{"}k/x{"}"} dx — the inner product matrix of fractional part basis functions
        </p>
      </div>

      <div className="flex-1 p-6 flex gap-6">
        <div className="flex-1 flex flex-col items-center">
          <div className="relative">
            <canvas ref={canvasRef} className="rounded-lg" />
            {computing && (
              <div className="absolute inset-0 flex items-center justify-center bg-[#0a0b14]/80 rounded-lg">
                <div className="text-amber-400 text-sm animate-pulse">Computing N={N}...</div>
              </div>
            )}
          </div>

          {/* Slider */}
          <div className="mt-6 w-full max-w-md">
            <div className="flex justify-between text-xs text-slate-500 mb-2">
              <span>N = {N}</span>
              <span>{N}×{N} = {N * N} entries</span>
            </div>
            <input
              type="range"
              min={5}
              max={80}
              value={N}
              onChange={(e) => setN(parseInt(e.target.value))}
              className="w-full accent-amber-500"
            />
          </div>
        </div>

        {/* Info panel */}
        <div className="w-72 space-y-4">
          {hoveredCell && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148]"
            >
              <div className="text-xs text-slate-500 mb-1">Entry</div>
              <div className="text-lg font-mono text-slate-200">
                G<sub>{hoveredCell.j},{hoveredCell.k}</sub> = {hoveredCell.val.toFixed(6)}
              </div>
              <div className="text-xs text-slate-500 mt-2">
                Excess: {(hoveredCell.val - 0.25).toFixed(6)}
              </div>
              {hoveredCell.j === hoveredCell.k && (
                <div className="text-xs text-emerald-400 mt-1">
                  Diagonal: 1/4 + 1/(12·{hoveredCell.j}²) ≈ {(0.25 + 1/(12*hoveredCell.j*hoveredCell.j)).toFixed(6)}
                </div>
              )}
            </motion.div>
          )}

          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148] space-y-3">
            <h3 className="text-sm font-bold text-slate-300">Color Scale</h3>
            <div className="h-4 rounded-full bg-gradient-to-r from-blue-600 via-[#1e1e28] to-red-500" />
            <div className="flex justify-between text-xs text-slate-500">
              <span>Below 1/4</span>
              <span className="text-slate-400">1/4</span>
              <span>Above 1/4</span>
            </div>
          </div>

          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148] text-xs text-slate-400 space-y-2">
            <p><strong className="text-slate-300">Diagonal:</strong> G<sub>kk</sub> = 1/4 + 1/(12k²)</p>
            <p><strong className="text-slate-300">Off-diagonal:</strong> Encodes divisor correlations</p>
            <p><strong className="text-slate-300">Baseline:</strong> 1/4 (independent fractional parts)</p>
          </div>
        </div>
      </div>
    </div>
  );
}
