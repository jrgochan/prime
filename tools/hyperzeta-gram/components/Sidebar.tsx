'use client';

import { ColorMode, COLOR_MODE_LABELS } from '@/lib/colorMaps';

export type VizMode = 'surface' | 'cloud' | 'heatmap';

interface Props {
  vizMode: VizMode;
  setVizMode: (mode: VizMode) => void;
  colorMode: ColorMode;
  setColorMode: (mode: ColorMode) => void;
  resolution: 'lo' | 'hi';
  setResolution: (res: 'lo' | 'hi') => void;
  metadata: {
    N: number;
    dim: number;
    globalMin: number;
    globalMax: number;
    numPoints: number;
    resolution: string;
  } | null;
  loading: boolean;
}

export default function Sidebar({
  vizMode, setVizMode,
  colorMode, setColorMode,
  resolution, setResolution,
  metadata, loading,
}: Props) {
  return (
    <div style={styles.sidebar}>
      {/* Title */}
      <div style={styles.titleSection}>
        <h1 style={styles.title}>HYPERZETA</h1>
        <h2 style={styles.subtitle}>GRAM</h2>
        <p style={styles.description}>Vasyunin Gram Matrix G(j,k)</p>
      </div>

      {/* Loading indicator */}
      {loading && (
        <div style={styles.loading}>
          <div style={styles.spinner} />
          <span>Loading data...</span>
        </div>
      )}

      {/* Visualization Mode */}
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>Mode</h3>
        {(['surface', 'cloud', 'heatmap'] as VizMode[]).map(mode => (
          <label key={mode} style={styles.radioLabel}>
            <input
              type="radio"
              name="vizMode"
              checked={vizMode === mode}
              onChange={() => setVizMode(mode)}
              style={styles.radio}
            />
            <span style={vizMode === mode ? styles.radioTextActive : styles.radioText}>
              {mode === 'surface' ? '◈ Surface' : mode === 'cloud' ? '◉ Point Cloud' : '▤ Heatmap'}
            </span>
          </label>
        ))}
      </div>

      {/* Color Scheme */}
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>Color</h3>
        {(Object.keys(COLOR_MODE_LABELS) as ColorMode[]).map(mode => (
          <label key={mode} style={styles.radioLabel}>
            <input
              type="radio"
              name="colorMode"
              checked={colorMode === mode}
              onChange={() => setColorMode(mode)}
              style={styles.radio}
            />
            <span style={colorMode === mode ? styles.radioTextActive : styles.radioText}>
              {COLOR_MODE_LABELS[mode]}
            </span>
          </label>
        ))}
      </div>

      {/* Resolution */}
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>Resolution</h3>
        {(['lo', 'hi'] as const).map(res => (
          <label key={res} style={styles.radioLabel}>
            <input
              type="radio"
              name="resolution"
              checked={resolution === res}
              onChange={() => setResolution(res)}
              style={styles.radio}
            />
            <span style={resolution === res ? styles.radioTextActive : styles.radioText}>
              {res === 'lo' ? '⬡ Low (fast)' : '⬢ High (detailed)'}
            </span>
          </label>
        ))}
      </div>

      {/* Data Info */}
      {metadata && (
        <div style={styles.section}>
          <h3 style={styles.sectionTitle}>Data</h3>
          <div style={styles.stat}>
            <span style={styles.statLabel}>N</span>
            <span style={styles.statValue}>{metadata.N.toLocaleString()}</span>
          </div>
          <div style={styles.stat}>
            <span style={styles.statLabel}>Dimension</span>
            <span style={styles.statValue}>{metadata.dim.toLocaleString()}²</span>
          </div>
          <div style={styles.stat}>
            <span style={styles.statLabel}>Points</span>
            <span style={styles.statValue}>{metadata.numPoints.toLocaleString()}</span>
          </div>
          <div style={styles.stat}>
            <span style={styles.statLabel}>G min</span>
            <span style={styles.statValue}>{metadata.globalMin.toFixed(6)}</span>
          </div>
          <div style={styles.stat}>
            <span style={styles.statLabel}>G max</span>
            <span style={styles.statValue}>{metadata.globalMax.toFixed(6)}</span>
          </div>
        </div>
      )}

      {/* Footer */}
      <div style={styles.footer}>
        <p style={styles.footerText}>Cathedral Project</p>
        <p style={styles.footerSub}>Nyman–Beurling RH</p>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  sidebar: {
    position: 'fixed',
    left: 0,
    top: 0,
    bottom: 0,
    width: '260px',
    background: 'rgba(10, 10, 20, 0.85)',
    backdropFilter: 'blur(20px)',
    borderRight: '1px solid rgba(255, 255, 255, 0.06)',
    padding: '20px 16px',
    display: 'flex',
    flexDirection: 'column',
    gap: '4px',
    overflowY: 'auto',
    zIndex: 100,
    fontFamily: "'Inter', 'SF Pro Display', -apple-system, sans-serif",
  },
  titleSection: {
    textAlign: 'center',
    paddingBottom: '16px',
    borderBottom: '1px solid rgba(255, 255, 255, 0.08)',
    marginBottom: '8px',
  },
  title: {
    fontSize: '18px',
    fontWeight: 700,
    letterSpacing: '4px',
    color: '#ffffff',
    margin: 0,
  },
  subtitle: {
    fontSize: '26px',
    fontWeight: 300,
    letterSpacing: '8px',
    color: '#ff8844',
    margin: '2px 0 8px',
  },
  description: {
    fontSize: '11px',
    color: 'rgba(255,255,255,0.4)',
    margin: 0,
    fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
  },
  section: {
    padding: '12px 0',
    borderBottom: '1px solid rgba(255, 255, 255, 0.04)',
  },
  sectionTitle: {
    fontSize: '10px',
    fontWeight: 600,
    letterSpacing: '2px',
    textTransform: 'uppercase' as const,
    color: 'rgba(255,255,255,0.35)',
    marginBottom: '8px',
    margin: '0 0 8px',
  },
  radioLabel: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    padding: '4px 0',
    cursor: 'pointer',
  },
  radio: {
    accentColor: '#ff8844',
    width: '12px',
    height: '12px',
  },
  radioText: {
    fontSize: '12px',
    color: 'rgba(255,255,255,0.5)',
    transition: 'color 0.2s',
  },
  radioTextActive: {
    fontSize: '12px',
    color: '#ffffff',
    fontWeight: 500,
  },
  stat: {
    display: 'flex',
    justifyContent: 'space-between',
    padding: '3px 0',
  },
  statLabel: {
    fontSize: '11px',
    color: 'rgba(255,255,255,0.35)',
  },
  statValue: {
    fontSize: '11px',
    color: 'rgba(255,255,255,0.75)',
    fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
  },
  loading: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    padding: '12px 0',
    color: '#ff8844',
    fontSize: '12px',
  },
  spinner: {
    width: '14px',
    height: '14px',
    border: '2px solid rgba(255,136,68,0.2)',
    borderTopColor: '#ff8844',
    borderRadius: '50%',
    animation: 'spin 0.8s linear infinite',
  },
  footer: {
    marginTop: 'auto',
    textAlign: 'center',
    paddingTop: '16px',
    borderTop: '1px solid rgba(255, 255, 255, 0.06)',
  },
  footerText: {
    fontSize: '10px',
    color: 'rgba(255,255,255,0.25)',
    margin: '0 0 2px',
    letterSpacing: '1px',
  },
  footerSub: {
    fontSize: '9px',
    color: 'rgba(255,255,255,0.15)',
    margin: 0,
  },
};
