"use client";

import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { OrbitControls, Html, Stars } from "@react-three/drei";
import { useEffect, useState, useRef, useMemo, useCallback } from "react";
import * as THREE from "three";

import {
  CENSUS_DATA,
  PARTICLE_TYPES,
  MILESTONES,
  classifyAll,
  interpolateCensus,
  type IntegerParticle,
  type CensusPoint,
  type ParticleClass,
} from "./particle-data";

// ═══════════════════════════════════════════════════════
// LAYOUT MODES
// ═══════════════════════════════════════════════════════

type LayoutMode = 'spiral' | 'linear' | 'logarithmic' | 'ulam';

const PHI = (1 + Math.sqrt(5)) / 2;
const GOLDEN_ANGLE = 2 * Math.PI * (1 - 1 / PHI);

/** Seeded RNG so positions are deterministic */
function seededRandom(seed: number): number {
  const x = Math.sin(seed * 12.9898 + seed * 78.233) * 43758.5453;
  return x - Math.floor(x);
}

function typeYOffset(type: ParticleClass, seed: number): number {
  switch (type) {
    case 'vacuum':   return -2;
    case 'higgs':    return 1.5;
    case 'quark':    return 2 + seededRandom(seed) * 1.5;
    case 'meson':    return -2 - seededRandom(seed) * 1.5;
    case 'baryon':   return 1.5 + seededRandom(seed) * 1;
    case 'tetra':    return -1.5 - seededRandom(seed) * 0.8;
    case 'penta':    return 1 + seededRandom(seed) * 0.5;
    case 'hexa':     return -1 - seededRandom(seed) * 0.3;
    case 'excluded': return (seededRandom(seed) - 0.5) * 0.5;
  }
}

/** Compute Ulam spiral (x, z) coordinates for integer k (1-indexed) */
function ulamCoords(k: number): [number, number] {
  if (k === 1) return [0, 0];
  // Layer: which ring (0 = center)
  const layer = Math.ceil((Math.sqrt(k) - 1) / 2);
  // Start of this layer
  const layerStart = (2 * layer - 1) ** 2 + 1;
  const sideLen = 2 * layer;
  const offset = k - layerStart;
  const side = Math.floor(offset / sideLen);
  const pos = offset % sideLen;

  switch (side) {
    case 0: return [layer, -layer + 1 + pos];           // right edge, going up
    case 1: return [layer - 1 - pos, layer];             // top edge, going left
    case 2: return [-layer, layer - 1 - pos];            // left edge, going down
    case 3: return [-layer + 1 + pos, -layer];           // bottom edge, going right
    default: return [0, 0];
  }
}

function computePositions(
  particles: IntegerParticle[],
  layout: LayoutMode,
): Float32Array {
  const count = particles.length;
  const pos = new Float32Array(count * 3);

  // Pre-compute Ulam scale factor
  const ulamScale = layout === 'ulam' ? 0.15 : 1;

  for (let i = 0; i < count; i++) {
    const p = particles[i];
    const k = p.k;
    const idx = i * 3;

    switch (layout) {
      case 'spiral': {
        const y = typeYOffset(p.type, k * 7.13);
        const maxK = count;
        const r = Math.sqrt(k / maxK) * 30;
        const theta = k * GOLDEN_ANGLE;
        pos[idx] = r * Math.cos(theta);
        pos[idx + 1] = y;
        pos[idx + 2] = r * Math.sin(theta);
        break;
      }
      case 'linear': {
        const y = typeYOffset(p.type, k * 7.13);
        const t = k / count;
        pos[idx] = (t - 0.5) * 80;
        pos[idx + 1] = y;
        pos[idx + 2] = (seededRandom(k * 3.17) - 0.5) * 4;
        break;
      }
      case 'logarithmic': {
        const y = typeYOffset(p.type, k * 7.13);
        const logK = Math.log(Math.max(k, 1));
        const logMax = Math.log(count);
        const t = logK / logMax;
        pos[idx] = (t - 0.5) * 80;
        pos[idx + 1] = y;
        pos[idx + 2] = (seededRandom(k * 3.17) - 0.5) * 6;
        break;
      }
      case 'ulam': {
        // Classic Ulam spiral: flat 2D grid, integer at its spiral position
        // Y is nearly flat so diagonal lines are visible
        const [ux, uz] = ulamCoords(k);
        pos[idx] = ux * ulamScale;
        pos[idx + 1] = (p.type === 'excluded' ? -0.1 : 0) + seededRandom(k * 2.71) * 0.05;
        pos[idx + 2] = uz * ulamScale;
        break;
      }
    }
  }
  return pos;
}

// ═══════════════════════════════════════════════════════
// AUDIO ENGINE — Cosmic Hum
// ═══════════════════════════════════════════════════════

class CosmicAudio {
  private ctx: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private droneOsc: OscillatorNode | null = null;
  private droneGain: GainNode | null = null;
  private subOsc: OscillatorNode | null = null;
  private subGain: GainNode | null = null;
  private lfo: OscillatorNode | null = null;
  private lfoGain: GainNode | null = null;
  private active = false;

  init() {
    if (this.ctx) return;
    this.ctx = new AudioContext();
    this.masterGain = this.ctx.createGain();
    this.masterGain.gain.value = 0;
    this.masterGain.connect(this.ctx.destination);

    // Main drone — sine at ~55 Hz (sub A)
    this.droneOsc = this.ctx.createOscillator();
    this.droneOsc.type = 'sine';
    this.droneOsc.frequency.value = 55;
    this.droneGain = this.ctx.createGain();
    this.droneGain.gain.value = 0.3;
    this.droneOsc.connect(this.droneGain);
    this.droneGain.connect(this.masterGain);
    this.droneOsc.start();

    // Sub-bass drone — sine at ~27.5 Hz
    this.subOsc = this.ctx.createOscillator();
    this.subOsc.type = 'sine';
    this.subOsc.frequency.value = 27.5;
    this.subGain = this.ctx.createGain();
    this.subGain.gain.value = 0.15;
    this.subOsc.connect(this.subGain);
    this.subGain.connect(this.masterGain);
    this.subOsc.start();

    // LFO for tremolo
    this.lfo = this.ctx.createOscillator();
    this.lfo.type = 'sine';
    this.lfo.frequency.value = 0.1;
    this.lfoGain = this.ctx.createGain();
    this.lfoGain.gain.value = 0.05;
    this.lfo.connect(this.lfoGain);
    this.lfoGain.connect(this.droneGain!.gain);
    this.lfo.start();
  }

  toggle() {
    if (!this.ctx) this.init();
    if (!this.ctx || !this.masterGain) return;

    this.active = !this.active;
    const now = this.ctx.currentTime;
    this.masterGain.gain.cancelScheduledValues(now);
    this.masterGain.gain.setValueAtTime(this.masterGain.gain.value, now);
    this.masterGain.gain.linearRampToValueAtTime(
      this.active ? 0.25 : 0,
      now + 1
    );
    return this.active;
  }

  /** Update audio parameters based on current census data */
  update(census: CensusPoint) {
    if (!this.ctx || !this.active) return;

    // Drone pitch shifts with SUSY cancellation: higher cancel = higher pitch
    // Map 30-99.8% cancel → 40-80 Hz
    const cancelNorm = (census.cancel - 30) / 70;
    const pitch = 40 + cancelNorm * 40;
    if (this.droneOsc) {
      this.droneOsc.frequency.setTargetAtTime(pitch, this.ctx.currentTime, 0.5);
    }

    // Sub-bass follows at half pitch
    if (this.subOsc) {
      this.subOsc.frequency.setTargetAtTime(pitch / 2, this.ctx.currentTime, 0.5);
    }

    // LFO speed increases with N (universe getting more complex)
    if (this.lfo) {
      const lfoFreq = 0.05 + cancelNorm * 0.2;
      this.lfo.frequency.setTargetAtTime(lfoFreq, this.ctx.currentTime, 1);
    }
  }

  /** Play a milestone chime */
  chime() {
    if (!this.ctx || !this.masterGain || !this.active) return;
    const osc = this.ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.value = 880;
    const gain = this.ctx.createGain();
    gain.gain.value = 0.15;
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 1.5);
    osc.connect(gain);
    gain.connect(this.masterGain);
    osc.start();
    osc.stop(this.ctx.currentTime + 1.5);
  }

  isActive() { return this.active; }
}

// ═══════════════════════════════════════════════════════
// PARTICLE FIELD (INSTANCED)
// ═══════════════════════════════════════════════════════

const PARTICLE_COLOR_THREE: Record<string, THREE.Color> = {};
PARTICLE_TYPES.forEach(p => {
  PARTICLE_COLOR_THREE[p.key] = new THREE.Color(p.color);
});
PARTICLE_COLOR_THREE['excluded'] = new THREE.Color('#1e293b');

const MAX_PARTICLES = 56000;
const tmpQuat = new THREE.Quaternion();

function ParticleField({ particles, currentN, flash, positions }: {
  particles: IntegerParticle[];
  currentN: number;
  flash: boolean;
  positions: Float32Array;
}) {
  const meshRef = useRef<THREE.InstancedMesh>(null);
  const timeRef = useRef(0);
  const matrix = useMemo(() => new THREE.Matrix4(), []);
  const posVec = useMemo(() => new THREE.Vector3(), []);
  const color = useMemo(() => new THREE.Color(), []);
  const scaleVec = useMemo(() => new THREE.Vector3(), []);
  const black = useMemo(() => new THREE.Color('#000000'), []);

  useFrame((_, delta) => {
    timeRef.current += delta;
    if (!meshRef.current) return;

    const mesh = meshRef.current;
    const visible = Math.min(currentN, particles.length);
    const lnN = Math.log(Math.max(currentN, 2));
    const t = timeRef.current;

    for (let i = 0; i < MAX_PARTICLES; i++) {
      if (i >= visible) {
        matrix.makeScale(0, 0, 0);
        mesh.setMatrixAt(i, matrix);
        continue;
      }

      const p = particles[i];
      const idx = i * 3;

      // Breathing animation
      const breath = 1 + Math.sin(t * 2 + i * 0.01) * 0.05;

      // Size by type
      let size: number;
      if (p.type === 'excluded') {
        size = 0.03;
      } else if (p.type === 'vacuum') {
        size = 0.3;
      } else if (p.type === 'higgs') {
        size = 0.25;
      } else {
        const v = Math.abs(p.mu) * Math.max(0, 1 - Math.log(p.k) / lnN);
        size = 0.05 + v * 0.15;
      }

      const flashBoost = flash ? 1 + Math.sin(t * 10) * 0.3 : 0;
      const s = size * breath * (1 + flashBoost);

      scaleVec.set(s, s, s);
      posVec.set(positions[idx], positions[idx + 1], positions[idx + 2]);
      matrix.compose(posVec, tmpQuat, scaleVec);
      mesh.setMatrixAt(i, matrix);

      // Color
      const baseColor = PARTICLE_COLOR_THREE[p.type] || PARTICLE_COLOR_THREE['excluded'];
      color.copy(baseColor);

      // Fade in leading edge
      if (i > visible * 0.92) {
        const fade = (visible - i) / (visible * 0.08);
        color.lerp(black, 1 - Math.max(fade, 0));
      }

      mesh.setColorAt(i, color);
    }

    mesh.instanceMatrix.needsUpdate = true;
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  });

  return (
    <instancedMesh ref={meshRef} args={[undefined, undefined, MAX_PARTICLES]} frustumCulled={false}>
      <sphereGeometry args={[1, 8, 8]} />
      <meshBasicMaterial transparent opacity={0.85} depthWrite={false} />
    </instancedMesh>
  );
}

// ═══════════════════════════════════════════════════════
// VTGV GAUGE RING
// ═══════════════════════════════════════════════════════

function VtGvRing({ vtgv }: { vtgv: number }) {
  const ringRef = useRef<THREE.Mesh>(null);
  const timeRef = useRef(0);

  useFrame((_, delta) => {
    timeRef.current += delta;
    if (ringRef.current) {
      ringRef.current.rotation.z = timeRef.current * 0.1;
    }
  });

  const arcAngle = vtgv * Math.PI * 2;
  const thresholdColor = vtgv < 0.7 ? '#10b981' : vtgv < 0.9 ? '#f59e0b' : '#ef4444';

  return (
    <group position={[0, 15, 0]}>
      <mesh ref={ringRef}>
        <torusGeometry args={[4, 0.15, 8, 64]} />
        <meshBasicMaterial color="#1e293b" transparent opacity={0.3} />
      </mesh>
      <mesh rotation={[0, 0, -Math.PI / 2]}>
        <torusGeometry args={[4, 0.2, 8, 64, arcAngle]} />
        <meshBasicMaterial color={thresholdColor} transparent opacity={0.8} />
      </mesh>
      <mesh position={[4, 0, 0]}>
        <sphereGeometry args={[0.3, 8, 8]} />
        <meshBasicMaterial color="#ef4444" transparent opacity={0.6} />
      </mesh>
      <Html center distanceFactor={20} style={{ pointerEvents: 'none' }}>
        <div style={{
          fontFamily: "'JetBrains Mono', monospace",
          fontSize: '24px', fontWeight: 800,
          color: thresholdColor,
          textShadow: `0 0 20px ${thresholdColor}`,
          textAlign: 'center',
        }}>
          {vtgv.toFixed(4)}
          <div style={{
            fontSize: '10px', color: '#94a3b8',
            fontWeight: 400, letterSpacing: '0.1em',
          }}>
            vᵀGv
          </div>
        </div>
      </Html>
    </group>
  );
}

// ═══════════════════════════════════════════════════════
// SUSY STREAMS — Counter-rotating particle rings
// ═══════════════════════════════════════════════════════

function SusyStreams() {
  const bosRef = useRef<THREE.Points>(null);
  const ferRef = useRef<THREE.Points>(null);
  const timeRef = useRef(0);
  const streamCount = 200;

  const bosPositions = useMemo(() => {
    const arr = new Float32Array(streamCount * 3);
    for (let i = 0; i < streamCount; i++) {
      const a = (i / streamCount) * Math.PI * 2;
      arr[i * 3] = Math.cos(a) * 38;
      arr[i * 3 + 1] = Math.sin(a * 3) * 2;
      arr[i * 3 + 2] = Math.sin(a) * 38;
    }
    return arr;
  }, []);

  const ferPositions = useMemo(() => {
    const arr = new Float32Array(streamCount * 3);
    for (let i = 0; i < streamCount; i++) {
      const a = (i / streamCount) * Math.PI * 2;
      arr[i * 3] = Math.cos(a) * 38;
      arr[i * 3 + 1] = Math.sin(a * 3 + 1) * 2;
      arr[i * 3 + 2] = Math.sin(a) * 38;
    }
    return arr;
  }, []);

  useFrame((_, delta) => {
    timeRef.current += delta;
    if (bosRef.current) bosRef.current.rotation.y = timeRef.current * 0.15;
    if (ferRef.current) ferRef.current.rotation.y = -timeRef.current * 0.15;
  });

  return (
    <group>
      <points ref={bosRef}>
        <bufferGeometry>
          <bufferAttribute attach="attributes-position" args={[bosPositions, 3]} />
        </bufferGeometry>
        <pointsMaterial color="#ef4444" size={0.5} transparent opacity={0.4} depthWrite={false} />
      </points>
      <points ref={ferRef}>
        <bufferGeometry>
          <bufferAttribute attach="attributes-position" args={[ferPositions, 3]} />
        </bufferGeometry>
        <pointsMaterial color="#3b82f6" size={0.5} transparent opacity={0.4} depthWrite={false} />
      </points>
    </group>
  );
}

// ═══════════════════════════════════════════════════════
// CAMERA CONTROLLER
// ═══════════════════════════════════════════════════════

function CameraController({ currentN }: { currentN: number }) {
  const { camera } = useThree();

  useFrame(() => {
    const t = Math.log(Math.max(currentN, 6)) / Math.log(55440);
    const target = 30 + t * 35;
    const pos = camera.position;
    const currentDist = pos.length();
    const newDist = currentDist + (target - currentDist) * 0.02;
    pos.normalize().multiplyScalar(newDist);
  });

  return null;
}

// ═══════════════════════════════════════════════════════
// HUD OVERLAY
// ═══════════════════════════════════════════════════════

const LAYOUT_OPTIONS: { mode: LayoutMode; label: string; icon: string }[] = [
  { mode: 'spiral', label: 'Galaxy', icon: '🌀' },
  { mode: 'ulam', label: 'Ulam', icon: '🔲' },
  { mode: 'linear', label: 'Linear', icon: '━' },
  { mode: 'logarithmic', label: 'Log', icon: '📐' },
];

function HUD({ census, currentN, playing, layout, audioOn, onTogglePlay, onSliderChange, onSetLayout, onToggleAudio, milestone }: {
  census: CensusPoint;
  currentN: number;
  playing: boolean;
  layout: LayoutMode;
  audioOn: boolean;
  onTogglePlay: () => void;
  onSliderChange: (n: number) => void;
  onSetLayout: (m: LayoutMode) => void;
  onToggleAudio: () => void;
  milestone: string | null;
}) {
  return (
    <div style={{
      position: 'absolute', top: 0, left: 0, right: 0, bottom: 0,
      pointerEvents: 'none', fontFamily: "'Inter', sans-serif",
      zIndex: 10,
    }}>
      {/* Top-left: Title */}
      <div style={{ position: 'absolute', top: 24, left: 24 }}>
        <div style={{
          fontSize: 11, fontWeight: 600, letterSpacing: '0.12em',
          color: '#a78bfa', textTransform: 'uppercase', marginBottom: 4,
        }}>
          ⚛️ Cathedral Project
        </div>
        <div style={{
          fontSize: 28, fontWeight: 900, letterSpacing: '-0.03em',
          background: 'linear-gradient(135deg, #f1f5f9, #a78bfa)',
          WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent',
          lineHeight: 1.1,
        }}>
          The Particle Zoo
        </div>
        <div style={{ fontSize: 12, color: '#64748b', marginTop: 4 }}>
          Every integer has a soul
        </div>
      </div>

      {/* Top-right: Stats */}
      <div style={{
        position: 'absolute', top: 24, right: 24,
        display: 'flex', gap: 24,
      }}>
        {[
          { label: 'N', value: currentN.toLocaleString(), color: '#f1f5f9' },
          { label: 'vᵀGv', value: census.vtgv.toFixed(4), color: census.vtgv < 0.8 ? '#10b981' : '#f59e0b' },
          { label: 'gap·ln(N)', value: census.gapLn.toFixed(3), color: '#a78bfa' },
          { label: 'SUSY', value: census.cancel.toFixed(1) + '%', color: '#f59e0b' },
        ].map((s, i) => (
          <div key={i} style={{ textAlign: 'center' }}>
            <div style={{
              fontFamily: "'JetBrains Mono', monospace",
              fontSize: 18, fontWeight: 700, color: s.color,
            }}>
              {s.value}
            </div>
            <div style={{ fontSize: 9, color: '#64748b', letterSpacing: '0.08em', textTransform: 'uppercase' }}>
              {s.label}
            </div>
          </div>
        ))}
      </div>

      {/* Left: Layout toggle + Audio */}
      <div style={{
        position: 'absolute', top: 100, left: 24,
        display: 'flex', flexDirection: 'column', gap: 6,
        pointerEvents: 'auto',
      }}>
        {LAYOUT_OPTIONS.map(opt => (
          <button
            key={opt.mode}
            onClick={() => onSetLayout(opt.mode)}
            style={{
              display: 'flex', alignItems: 'center', gap: 6,
              padding: '6px 12px', borderRadius: 8,
              border: layout === opt.mode
                ? '1px solid rgba(139, 92, 246, 0.5)'
                : '1px solid rgba(255,255,255,0.06)',
              background: layout === opt.mode
                ? 'rgba(139, 92, 246, 0.15)'
                : 'rgba(15, 23, 42, 0.7)',
              color: layout === opt.mode ? '#a78bfa' : '#64748b',
              fontSize: 11, fontWeight: 500, cursor: 'pointer',
              backdropFilter: 'blur(8px)',
            }}
          >
            <span>{opt.icon}</span>
            <span>{opt.label}</span>
          </button>
        ))}
        <div style={{ height: 8 }} />
        <button
          onClick={onToggleAudio}
          style={{
            display: 'flex', alignItems: 'center', gap: 6,
            padding: '6px 12px', borderRadius: 8,
            border: audioOn
              ? '1px solid rgba(245, 158, 11, 0.4)'
              : '1px solid rgba(255,255,255,0.06)',
            background: audioOn
              ? 'rgba(245, 158, 11, 0.1)'
              : 'rgba(15, 23, 42, 0.7)',
            color: audioOn ? '#fbbf24' : '#64748b',
            fontSize: 11, fontWeight: 500, cursor: 'pointer',
            backdropFilter: 'blur(8px)',
          }}
        >
          <span>{audioOn ? '🔊' : '🔇'}</span>
          <span>Audio</span>
        </button>
      </div>

      {/* Bottom-left: Particle legend */}
      <div style={{
        position: 'absolute', bottom: 90, left: 24,
        display: 'flex', flexDirection: 'column', gap: 4,
      }}>
        {PARTICLE_TYPES.filter(p => p.key !== 'excluded').map(p => {
          const val = census[p.key as keyof CensusPoint] as number;
          const hasVal = Math.abs(val) > 0.0001;
          return (
            <div key={p.key} style={{
              display: 'flex', alignItems: 'center', gap: 8,
              opacity: hasVal ? 1 : 0.3, fontSize: 11,
            }}>
              <div style={{
                width: 8, height: 8, borderRadius: '50%',
                backgroundColor: p.color,
                boxShadow: hasVal ? `0 0 6px ${p.color}` : 'none',
              }} />
              <span style={{ color: '#cbd5e1', fontWeight: 500, width: 80 }}>{p.label}</span>
              <span style={{
                fontFamily: "'JetBrains Mono', monospace", fontSize: 10,
                color: val > 0.0001 ? '#f87171' : val < -0.0001 ? '#60a5fa' : '#475569',
              }}>
                {hasVal ? (val > 0 ? '+' : '') + val.toFixed(3) : '—'}
              </span>
            </div>
          );
        })}
      </div>

      {/* Slider moved to main page for extrapolation support */}

      {/* Milestone toast */}
      {milestone && (
        <div style={{
          position: 'absolute', top: '50%', left: '50%',
          transform: 'translate(-50%, -50%)',
          padding: '16px 32px',
          background: 'rgba(15, 23, 42, 0.9)',
          backdropFilter: 'blur(16px)', borderRadius: 16,
          border: '1px solid rgba(245, 158, 11, 0.4)',
          textAlign: 'center',
          animation: 'fadeInUp 0.5s ease-out',
        }}>
          <div style={{ fontSize: 24, marginBottom: 4 }}>⚡</div>
          <div style={{
            fontSize: 18, fontWeight: 800, color: '#f59e0b',
            letterSpacing: '-0.02em',
          }}>
            {milestone}
          </div>
        </div>
      )}

      {/* Footer quote */}
      <div style={{
        position: 'absolute', bottom: 70, right: 24,
        fontSize: 10, color: '#475569', fontStyle: 'italic',
        textAlign: 'right', maxWidth: 250,
      }}>
        The primes push. The semiprimes pull.<br />The balance holds.
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════
// MAIN PAGE
// ═══════════════════════════════════════════════════════

const cosmicAudio = typeof window !== 'undefined' ? new CosmicAudio() : null;

// Particle limits: real data to 55K, sieve-classified to 200K
const DATA_LIMIT = 55440;
const EXTRAP_LIMIT = 200000;

export default function ParticleZooPage() {
  const [currentN, setCurrentN] = useState(6);
  const [playing, setPlaying] = useState(false);
  const [milestone, setMilestone] = useState<string | null>(null);
  const [flash, setFlash] = useState(false);
  const [layout, setLayout] = useState<LayoutMode>('spiral');
  const [audioOn, setAudioOn] = useState(false);
  const [extrapolate, setExtrapolate] = useState(false);
  const milestoneTimeout = useRef<ReturnType<typeof setTimeout>>();
  const lastMilestone = useRef(0);

  const maxN = extrapolate ? EXTRAP_LIMIT : DATA_LIMIT;

  // Pre-classify all integers up to max N (recomputes when mode changes)
  const allParticles = useMemo(() => classifyAll(maxN), [maxN]);

  // Compute positions for current layout
  const positions = useMemo(
    () => computePositions(allParticles, layout),
    [allParticles, layout]
  );

  // Interpolated (or extrapolated) census for current N
  const census = useMemo(() => interpolateCensus(currentN), [currentN]);

  // Update audio parameters
  useEffect(() => {
    cosmicAudio?.update(census);
  }, [census]);

  // Auto-play
  useEffect(() => {
    if (!playing) return;
    const interval = setInterval(() => {
      setCurrentN(prev => {
        const step = Math.max(1, Math.floor(Math.sqrt(prev) * 0.3));
        const next = Math.min(prev + step, maxN);
        if (next >= maxN) setPlaying(false);
        return next;
      });
    }, 16);
    return () => clearInterval(interval);
  }, [playing, maxN]);

  // Milestone detection
  useEffect(() => {
    for (const m of MILESTONES) {
      if (currentN >= m.N && lastMilestone.current < m.N) {
        lastMilestone.current = m.N;
        setMilestone(m.label);
        setFlash(true);
        cosmicAudio?.chime();
        if (milestoneTimeout.current) clearTimeout(milestoneTimeout.current);
        milestoneTimeout.current = setTimeout(() => {
          setMilestone(null);
          setFlash(false);
        }, 3000);
      }
    }
  }, [currentN]);

  const handleSliderChange = useCallback((n: number) => {
    setPlaying(false);
    setCurrentN(n);
    const highestPassed = MILESTONES.filter(m => m.N <= n).pop();
    lastMilestone.current = highestPassed ? highestPassed.N : 0;
  }, []);

  const handleCustomN = useCallback((value: string) => {
    const n = parseInt(value.replace(/,/g, ''));
    if (!isNaN(n) && n >= 6) {
      setPlaying(false);
      // Auto-enable extrapolation if needed
      if (n > DATA_LIMIT) setExtrapolate(true);
      setCurrentN(Math.min(n, EXTRAP_LIMIT));
      const highestPassed = MILESTONES.filter(m => m.N <= n).pop();
      lastMilestone.current = highestPassed ? highestPassed.N : 0;
    }
  }, []);

  const togglePlay = useCallback(() => {
    if (currentN >= maxN) {
      setCurrentN(6);
      lastMilestone.current = 0;
    }
    setPlaying(p => !p);
  }, [currentN, maxN]);

  const handleSetLayout = useCallback((m: LayoutMode) => {
    setLayout(m);
  }, []);

  const handleToggleAudio = useCallback(() => {
    const active = cosmicAudio?.toggle();
    setAudioOn(!!active);
  }, []);

  const handleToggleExtrapolate = useCallback(() => {
    setExtrapolate(prev => {
      const next = !prev;
      // Clamp currentN if disabling extrapolation
      if (!next && currentN > DATA_LIMIT) {
        setCurrentN(DATA_LIMIT);
      }
      return next;
    });
  }, [currentN]);

  return (
    <div style={{
      width: '100vw', height: '100vh',
      background: '#030712', position: 'relative',
      overflow: 'hidden',
    }}>
      <Canvas
        camera={{ position: [30, 15, 30], fov: 60, near: 0.1, far: 500 }}
        gl={{ antialias: true, alpha: false }}
        style={{ background: '#030712' }}
      >
        <Stars radius={200} depth={100} count={3000} factor={4} saturation={0.2} fade speed={0.5} />
        <fog attach="fog" args={['#030712', 50, 150]} />
        <ambientLight intensity={0.6} />
        <pointLight position={[0, 20, 0]} intensity={1} color="#a78bfa" />

        <ParticleField
          particles={allParticles}
          currentN={currentN}
          flash={flash}
          positions={positions}
        />
        <SusyStreams />
        <VtGvRing vtgv={census.vtgv} />
        <CameraController currentN={currentN} />
        <OrbitControls
          enableDamping dampingFactor={0.05}
          minDistance={10} maxDistance={200}
          autoRotate autoRotateSpeed={0.3}
        />
      </Canvas>

      <HUD
        census={census}
        currentN={currentN}
        playing={playing}
        layout={layout}
        audioOn={audioOn}
        onTogglePlay={togglePlay}
        onSliderChange={handleSliderChange}
        onSetLayout={handleSetLayout}
        onToggleAudio={handleToggleAudio}
        milestone={milestone}
      />

      {/* Extrapolation controls — top-center */}
      <div style={{
        position: 'absolute', top: 80, left: '50%', transform: 'translateX(-50%)',
        display: 'flex', alignItems: 'center', gap: 12,
        pointerEvents: 'auto', zIndex: 20,
      }}>
        <button
          onClick={handleToggleExtrapolate}
          style={{
            padding: '6px 14px', borderRadius: 8,
            border: extrapolate
              ? '1px solid rgba(6, 182, 212, 0.5)'
              : '1px solid rgba(255,255,255,0.08)',
            background: extrapolate
              ? 'rgba(6, 182, 212, 0.12)'
              : 'rgba(15, 23, 42, 0.7)',
            color: extrapolate ? '#22d3ee' : '#64748b',
            fontSize: 11, fontWeight: 600, cursor: 'pointer',
            backdropFilter: 'blur(8px)',
            letterSpacing: '0.05em',
          }}
        >
          {extrapolate ? '🔭 EXTRAPOLATE ON' : '🔭 Extrapolate'}
        </button>
        {extrapolate && (
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            padding: '5px 10px', borderRadius: 8,
            background: 'rgba(15, 23, 42, 0.8)',
            border: '1px solid rgba(6, 182, 212, 0.2)',
            backdropFilter: 'blur(8px)',
          }}>
            <span style={{ fontSize: 10, color: '#94a3b8' }}>Go to N =</span>
            <input
              type="text"
              defaultValue=""
              placeholder="e.g. 100000"
              onKeyDown={e => {
                if (e.key === 'Enter') handleCustomN((e.target as HTMLInputElement).value);
              }}
              style={{
                width: 90, padding: '3px 6px', borderRadius: 4,
                border: '1px solid rgba(6, 182, 212, 0.3)',
                background: 'rgba(0,0,0,0.3)',
                color: '#22d3ee', fontSize: 12,
                fontFamily: "'JetBrains Mono', monospace",
                outline: 'none',
              }}
            />
          </div>
        )}
      </div>

      {/* Extrapolation indicator */}
      {census.extrapolated && (
        <div style={{
          position: 'absolute', top: 24, left: '50%', transform: 'translateX(-50%)',
          padding: '4px 12px', borderRadius: 6,
          background: 'rgba(6, 182, 212, 0.1)',
          border: '1px solid rgba(6, 182, 212, 0.3)',
          fontSize: 10, fontWeight: 600, color: '#22d3ee',
          letterSpacing: '0.1em', zIndex: 20,
        }}>
          🔭 EXTRAPOLATED — beyond N=55,440 census data
        </div>
      )}

      {/* Slider max now respects extrapolation */}
      <div style={{
        position: 'absolute', bottom: 20, left: 24, right: 24,
        pointerEvents: 'auto', zIndex: 20,
      }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 12,
          padding: '10px 16px',
          background: 'rgba(15, 23, 42, 0.85)',
          backdropFilter: 'blur(12px)',
          borderRadius: 12,
          border: census.extrapolated
            ? '1px solid rgba(6, 182, 212, 0.3)'
            : '1px solid rgba(139, 92, 246, 0.2)',
        }}>
          <button
            onClick={togglePlay}
            style={{
              width: 36, height: 36, borderRadius: '50%',
              border: '1px solid rgba(139, 92, 246, 0.4)',
              background: 'rgba(139, 92, 246, 0.15)',
              color: '#a78bfa', fontSize: 16, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}
          >
            {playing ? '⏸' : '▶'}
          </button>
          <span style={{
            fontFamily: "'JetBrains Mono', monospace",
            fontSize: 11, color: census.extrapolated ? '#22d3ee' : '#a78bfa',
            fontWeight: 600, minWidth: 30,
          }}>
            N =
          </span>
          <input
            type="range"
            min={6}
            max={maxN}
            value={currentN}
            onChange={e => handleSliderChange(parseInt(e.target.value))}
            style={{
              flex: 1, height: 4,
              accentColor: census.extrapolated ? '#06b6d4' : '#8b5cf6',
              cursor: 'pointer',
            }}
          />
          <span style={{
            fontFamily: "'JetBrains Mono', monospace",
            fontSize: 14, fontWeight: 700,
            color: census.extrapolated ? '#22d3ee' : '#f1f5f9',
            minWidth: 70, textAlign: 'right',
          }}>
            {currentN.toLocaleString()}
          </span>
        </div>
      </div>

      <style jsx global>{`
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&family=JetBrains+Mono:wght@400;500;600;700;800&display=swap');
        * { margin: 0; padding: 0; box-sizing: border-box; }
        @keyframes fadeInUp {
          from { opacity: 0; transform: translate(-50%, -40%); }
          to { opacity: 1; transform: translate(-50%, -50%); }
        }
        input[type="range"] {
          -webkit-appearance: none; appearance: none;
          background: rgba(255, 255, 255, 0.1);
          border-radius: 4px; outline: none;
        }
        input[type="range"]::-webkit-slider-thumb {
          -webkit-appearance: none; appearance: none;
          width: 16px; height: 16px; border-radius: 50%;
          background: #8b5cf6; cursor: pointer;
          box-shadow: 0 0 10px rgba(139, 92, 246, 0.5);
        }
      `}</style>
    </div>
  );
}

