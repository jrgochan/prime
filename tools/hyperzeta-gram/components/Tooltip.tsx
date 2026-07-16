'use client';

import { GramPoint } from '@/lib/colorMaps';

interface Props {
  point: GramPoint | null;
}

function isPrime(n: number): boolean {
  if (n < 2) return false;
  if (n < 4) return true;
  if (n % 2 === 0 || n % 3 === 0) return false;
  for (let i = 5; i * i <= n; i += 6) {
    if (n % i === 0 || n % (i + 2) === 0) return false;
  }
  return true;
}

function primeFactors(n: number): string {
  if (n <= 1) return String(n);
  if (isPrime(n)) return `${n} (prime)`;
  const factors: string[] = [];
  let rem = n;
  for (let p = 2; p * p <= rem; p++) {
    let exp = 0;
    while (rem % p === 0) { rem /= p; exp++; }
    if (exp > 0) factors.push(exp > 1 ? `${p}^${exp}` : `${p}`);
  }
  if (rem > 1) factors.push(`${rem}`);
  return factors.join(' × ');
}

/**
 * Floating tooltip that shows data for the hovered point.
 */
export default function Tooltip({ point }: Props) {
  if (!point) return null;

  return (
    <div style={styles.tooltip}>
      <div style={styles.header}>G({point.j}, {point.k})</div>
      <div style={styles.value}>{point.v.toExponential(6)}</div>
      <div style={styles.divider} />
      <div style={styles.row}>
        <span style={styles.label}>j</span>
        <span style={styles.val}>{point.j} = {primeFactors(point.j)}</span>
      </div>
      <div style={styles.row}>
        <span style={styles.label}>k</span>
        <span style={styles.val}>{point.k} = {primeFactors(point.k)}</span>
      </div>
      <div style={styles.row}>
        <span style={styles.label}>gcd</span>
        <span style={styles.val}>{point.g}</span>
      </div>
      <div style={styles.row}>
        <span style={styles.label}>type</span>
        <span style={styles.val}>
          {point.p === 2 ? 'both prime' : point.p === 1 ? 'one prime' : 'composite'}
        </span>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  tooltip: {
    position: 'absolute',
    top: '16px',
    right: '16px',
    background: 'rgba(10, 10, 25, 0.92)',
    backdropFilter: 'blur(16px)',
    border: '1px solid rgba(255, 136, 68, 0.2)',
    borderRadius: '8px',
    padding: '12px 16px',
    minWidth: '200px',
    fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
    zIndex: 50,
    pointerEvents: 'none',
  },
  header: {
    fontSize: '14px',
    fontWeight: 600,
    color: '#ff8844',
    marginBottom: '4px',
  },
  value: {
    fontSize: '18px',
    fontWeight: 700,
    color: '#ffffff',
    marginBottom: '8px',
  },
  divider: {
    height: '1px',
    background: 'rgba(255,255,255,0.08)',
    marginBottom: '8px',
  },
  row: {
    display: 'flex',
    justifyContent: 'space-between',
    gap: '12px',
    padding: '2px 0',
  },
  label: {
    fontSize: '10px',
    color: 'rgba(255,255,255,0.4)',
    textTransform: 'uppercase' as const,
    letterSpacing: '1px',
  },
  val: {
    fontSize: '11px',
    color: 'rgba(255,255,255,0.8)',
    textAlign: 'right' as const,
  },
};
