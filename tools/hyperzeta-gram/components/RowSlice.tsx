'use client';

interface DataPoint {
  index: number;
  value: number;
}

interface Props {
  data: DataPoint[];
  j: number;
  onClose: () => void;
}

/**
 * 2D row slice overlay — shows G(j, •) as a line graph.
 * Renders a canvas-based plot at the bottom of the viewport.
 */
export default function RowSlice({ data, j, onClose }: Props) {
  if (data.length === 0) return null;

  const width = 600;
  const height = 160;
  const pad = { top: 25, right: 20, bottom: 30, left: 55 };
  const plotW = width - pad.left - pad.right;
  const plotH = height - pad.top - pad.bottom;

  const minX = Math.min(...data.map(d => d.index));
  const maxX = Math.max(...data.map(d => d.index));
  const minY = Math.min(...data.map(d => d.value));
  const maxY = Math.max(...data.map(d => d.value));
  const rangeX = maxX - minX || 1;
  const rangeY = maxY - minY || 1;

  const toSvgX = (x: number) => pad.left + ((x - minX) / rangeX) * plotW;
  const toSvgY = (y: number) => pad.top + plotH - ((y - minY) / rangeY) * plotH;

  // Build SVG path
  const pathParts = data.map((d, i) =>
    `${i === 0 ? 'M' : 'L'} ${toSvgX(d.index).toFixed(1)} ${toSvgY(d.value).toFixed(1)}`
  );
  const pathD = pathParts.join(' ');

  // Y-axis ticks
  const yTicks = [0, 0.25, 0.5, 0.75, 1].map(t => minY + t * rangeY);
  // X-axis ticks
  const xTicks = [0, 0.25, 0.5, 0.75, 1].map(t => Math.round(minX + t * rangeX));

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <span style={styles.title}>Row Slice: G({j}, k)</span>
        <button onClick={onClose} style={styles.closeBtn}>✕</button>
      </div>
      <svg width={width} height={height} style={styles.svg}>
        {/* Grid lines */}
        {yTicks.map((y, i) => (
          <line key={`yg-${i}`}
            x1={pad.left} y1={toSvgY(y)} x2={width - pad.right} y2={toSvgY(y)}
            stroke="rgba(255,255,255,0.06)" strokeWidth={1}
          />
        ))}

        {/* Y axis labels */}
        {yTicks.map((y, i) => (
          <text key={`yl-${i}`}
            x={pad.left - 6} y={toSvgY(y) + 3}
            fill="rgba(255,255,255,0.3)" fontSize={8} textAnchor="end"
            fontFamily="'JetBrains Mono', monospace"
          >
            {y.toExponential(1)}
          </text>
        ))}

        {/* X axis labels */}
        {xTicks.map((x, i) => (
          <text key={`xl-${i}`}
            x={toSvgX(x)} y={height - pad.bottom + 14}
            fill="rgba(255,255,255,0.3)" fontSize={8} textAnchor="middle"
            fontFamily="'JetBrains Mono', monospace"
          >
            {x}
          </text>
        ))}

        {/* Axis labels */}
        <text x={width / 2} y={height - 4}
          fill="rgba(255,255,255,0.25)" fontSize={9} textAnchor="middle"
          fontFamily="Inter, sans-serif"
        >
          k
        </text>
        <text x={12} y={pad.top + plotH / 2}
          fill="rgba(255,255,255,0.25)" fontSize={9} textAnchor="middle"
          fontFamily="Inter, sans-serif"
          transform={`rotate(-90, 12, ${pad.top + plotH / 2})`}
        >
          G({j}, k)
        </text>

        {/* Data line */}
        <path d={pathD} fill="none" stroke="#ff8844" strokeWidth={1.5} opacity={0.9} />

        {/* Data points */}
        {data.map((d, i) => (
          <circle key={i}
            cx={toSvgX(d.index)} cy={toSvgY(d.value)}
            r={data.length < 100 ? 2 : 1}
            fill="#ff8844" opacity={0.7}
          />
        ))}
      </svg>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    bottom: '40px',
    left: '50%',
    transform: 'translateX(-50%)',
    background: 'rgba(10, 10, 25, 0.92)',
    backdropFilter: 'blur(16px)',
    border: '1px solid rgba(255, 136, 68, 0.15)',
    borderRadius: '10px',
    padding: '8px 12px 4px',
    zIndex: 50,
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '4px',
  },
  title: {
    fontSize: '11px',
    fontWeight: 600,
    color: '#ff8844',
    fontFamily: "'JetBrains Mono', monospace",
  },
  closeBtn: {
    background: 'none',
    border: 'none',
    color: 'rgba(255,255,255,0.4)',
    fontSize: '12px',
    cursor: 'pointer',
    padding: '2px 6px',
  },
  svg: {
    display: 'block',
  },
};
