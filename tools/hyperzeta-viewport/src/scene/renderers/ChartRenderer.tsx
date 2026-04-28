"use client";

import { useRef, useEffect, useCallback } from "react";
import { useViewportStore } from "../../stores/viewport";
import { VIZ_MAP } from "../../content/visualizations";
import { getChartData } from "../../content/certificate-adapters";

// ── Design tokens ──
const COLORS = {
  bg: "rgba(8, 12, 18, 0.95)",
  grid: "rgba(255, 255, 255, 0.04)",
  axis: "rgba(255, 255, 255, 0.15)",
  text: "rgba(224, 232, 240, 0.5)",
  textBright: "rgba(224, 232, 240, 0.85)",
};

const SERIES_COLORS = [
  "#00ff88", "#00ccff", "#ffaa00", "#ff6b9d", "#bb88ff",
  "#88ffcc", "#ff8844", "#44ddff",
];

export interface ChartSeries {
  label: string;
  color?: string;
  points: { x: number; y: number }[];
  asymptote?: number;
  asymptoteLabel?: string;
  dashed?: boolean;
}

export interface ChartConfig {
  title: string;
  xLabel: string;
  yLabel: string;
  series: ChartSeries[];
  xLog?: boolean;
  yLog?: boolean;
  precision?: string;
}

/**
 * ChartRenderer — Canvas 2D convergence chart with Cathedral aesthetic.
 * Animated line drawing, asymptote markers, multi-series support.
 */
export function ChartRenderer() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animRef = useRef(0);
  const progressRef = useRef(0);
  const viewMode = useViewportStore((s) => s.viewMode);
  const viz = VIZ_MAP[viewMode];

  const draw = useCallback(
    (ctx: CanvasRenderingContext2D, width: number, height: number) => {
      const config = getChartData(viewMode);
      if (!config || config.series.length === 0) {
        drawPlaceholder(ctx, width, height, viz?.label ?? "");
        return;
      }

      const progress = Math.min(progressRef.current, 1);
      const pad = { top: 60, right: 40, bottom: 50, left: 70 };
      const cw = width - pad.left - pad.right;
      const ch = height - pad.top - pad.bottom;

      // Clear
      ctx.clearRect(0, 0, width, height);

      // Compute bounds across all series
      let xMin = Infinity, xMax = -Infinity, yMin = Infinity, yMax = -Infinity;
      for (const s of config.series) {
        for (const p of s.points) {
          const xv = config.xLog ? Math.log10(Math.max(p.x, 1)) : p.x;
          xMin = Math.min(xMin, xv);
          xMax = Math.max(xMax, xv);
          yMin = Math.min(yMin, p.y);
          yMax = Math.max(yMax, p.y);
        }
        if (s.asymptote !== undefined) {
          yMin = Math.min(yMin, s.asymptote * 0.95);
          yMax = Math.max(yMax, s.asymptote * 1.05);
        }
      }
      // Add padding
      const yRange = yMax - yMin || 1;
      yMin -= yRange * 0.08;
      yMax += yRange * 0.08;

      const toX = (v: number) => pad.left + ((v - xMin) / (xMax - xMin || 1)) * cw;
      const toY = (v: number) => pad.top + ch - ((v - yMin) / (yMax - yMin || 1)) * ch;

      // Grid lines
      ctx.strokeStyle = COLORS.grid;
      ctx.lineWidth = 1;
      for (let i = 0; i <= 5; i++) {
        const y = pad.top + (ch * i) / 5;
        ctx.beginPath();
        ctx.moveTo(pad.left, y);
        ctx.lineTo(pad.left + cw, y);
        ctx.stroke();
      }

      // Axes
      ctx.strokeStyle = COLORS.axis;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(pad.left, pad.top);
      ctx.lineTo(pad.left, pad.top + ch);
      ctx.lineTo(pad.left + cw, pad.top + ch);
      ctx.stroke();

      // Axis labels
      ctx.fillStyle = COLORS.text;
      ctx.font = "10px 'Geist Mono', monospace";
      ctx.textAlign = "center";
      ctx.fillText(config.xLabel, pad.left + cw / 2, height - 10);
      ctx.save();
      ctx.translate(15, pad.top + ch / 2);
      ctx.rotate(-Math.PI / 2);
      ctx.fillText(config.yLabel, 0, 0);
      ctx.restore();

      // Tick labels
      ctx.textAlign = "center";
      ctx.textBaseline = "top";
      for (let i = 0; i <= 4; i++) {
        const v = xMin + ((xMax - xMin) * i) / 4;
        const label = config.xLog ? Math.round(Math.pow(10, v)).toString() : v.toFixed(0);
        ctx.fillText(label, toX(v), pad.top + ch + 8);
      }
      ctx.textAlign = "right";
      ctx.textBaseline = "middle";
      for (let i = 0; i <= 5; i++) {
        const v = yMin + ((yMax - yMin) * i) / 5;
        ctx.fillText(v.toFixed(2), pad.left - 8, toY(v));
      }

      // Draw each series
      config.series.forEach((series, si) => {
        const color = series.color ?? SERIES_COLORS[si % SERIES_COLORS.length];
        const pts = series.points.map((p) => ({
          x: config.xLog ? Math.log10(Math.max(p.x, 1)) : p.x,
          y: p.y,
        }));

        // Animated progress: reveal points left to right
        const visibleCount = Math.max(1, Math.ceil(pts.length * progress));
        const visible = pts.slice(0, visibleCount);

        // Asymptote line
        if (series.asymptote !== undefined) {
          const ay = toY(series.asymptote);
          ctx.strokeStyle = color;
          ctx.globalAlpha = 0.3;
          ctx.lineWidth = 1;
          ctx.setLineDash([6, 4]);
          ctx.beginPath();
          ctx.moveTo(pad.left, ay);
          ctx.lineTo(pad.left + cw, ay);
          ctx.stroke();
          ctx.setLineDash([]);
          ctx.globalAlpha = 1;

          if (series.asymptoteLabel) {
            ctx.fillStyle = color;
            ctx.globalAlpha = 0.6;
            ctx.font = "11px 'Geist Mono', monospace";
            ctx.textAlign = "right";
            ctx.fillText(series.asymptoteLabel, pad.left + cw - 4, ay - 6);
            ctx.globalAlpha = 1;
          }
        }

        // Line
        ctx.strokeStyle = color;
        ctx.lineWidth = 2.5;
        ctx.lineJoin = "round";
        if (series.dashed) ctx.setLineDash([8, 4]);
        ctx.beginPath();
        visible.forEach((p, i) => {
          const x = toX(p.x);
          const y = toY(p.y);
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        });
        ctx.stroke();
        ctx.setLineDash([]);

        // Glow
        ctx.strokeStyle = color;
        ctx.globalAlpha = 0.15;
        ctx.lineWidth = 8;
        ctx.beginPath();
        visible.forEach((p, i) => {
          const x = toX(p.x);
          const y = toY(p.y);
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        });
        ctx.stroke();
        ctx.globalAlpha = 1;

        // Data points
        ctx.fillStyle = color;
        visible.forEach((p) => {
          ctx.beginPath();
          ctx.arc(toX(p.x), toY(p.y), 3.5, 0, Math.PI * 2);
          ctx.fill();
        });
      });

      // Title
      ctx.fillStyle = COLORS.textBright;
      ctx.font = "bold 14px 'Geist Mono', monospace";
      ctx.textAlign = "left";
      ctx.fillText(config.title, pad.left, 28);

      // Precision badge
      if (config.precision) {
        ctx.fillStyle = COLORS.text;
        ctx.font = "9px 'Geist Mono', monospace";
        ctx.textAlign = "right";
        ctx.fillText(config.precision, pad.left + cw, 28);
      }

      // Legend
      ctx.font = "10px 'Geist Mono', monospace";
      let lx = pad.left;
      config.series.forEach((s, si) => {
        const color = s.color ?? SERIES_COLORS[si % SERIES_COLORS.length];
        ctx.fillStyle = color;
        ctx.fillRect(lx, 42, 12, 3);
        ctx.fillStyle = COLORS.text;
        ctx.textAlign = "left";
        ctx.fillText(s.label, lx + 16, 46);
        lx += ctx.measureText(s.label).width + 32;
      });
    },
    [viewMode, viz]
  );

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    progressRef.current = 0;
    const ctx = canvas.getContext("2d")!;

    const animate = () => {
      const dpr = window.devicePixelRatio || 1;
      const rect = canvas.getBoundingClientRect();
      canvas.width = rect.width * dpr;
      canvas.height = rect.height * dpr;
      ctx.scale(dpr, dpr);

      progressRef.current = Math.min(progressRef.current + 0.02, 1);
      draw(ctx, rect.width, rect.height);

      animRef.current = requestAnimationFrame(animate);
    };

    animRef.current = requestAnimationFrame(animate);
    return () => cancelAnimationFrame(animRef.current);
  }, [draw, viewMode]);

  return (
    <canvas
      ref={canvasRef}
      className="chart-canvas"
      style={{ width: "100%", height: "100%", display: "block" }}
    />
  );
}

function drawPlaceholder(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
  label: string
) {
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = COLORS.text;
  ctx.font = "14px 'Geist Mono', monospace";
  ctx.textAlign = "center";
  ctx.fillText(`${label} — loading certificate data...`, w / 2, h / 2);
}
