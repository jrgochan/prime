'use client';

import { useState, useEffect, useCallback, useRef, Suspense } from 'react';
import { Canvas } from '@react-three/fiber';
import { OrbitControls, Html } from '@react-three/drei';
import * as THREE from 'three';
import Sidebar, { VizMode } from '@/components/Sidebar';
import GramSurface from '@/components/GramSurface';
import GramPointCloud from '@/components/GramPointCloud';
import GramHeatmap from '@/components/GramHeatmap';
import AxisGrid from '@/components/AxisGrid';
import Tooltip from '@/components/Tooltip';
import RowSlice from '@/components/RowSlice';
import { ColorMode, GramPoint } from '@/lib/colorMaps';

interface GramData {
  metadata: {
    N: number;
    dim: number;
    globalMin: number;
    globalMax: number;
    numPoints: number;
    resolution: string;
    sampledMin: number;
    sampledMax: number;
  };
  points: GramPoint[];
}

const SCALE = { x: 2.5, y: 2.5, z: 1.5 };
const AVAILABLE_SIZES = [360, 840, 1680, 2520, 5040];
const DEFAULT_N = 2520;

export default function Home() {
  const [vizMode, setVizMode] = useState<VizMode>('surface');
  const [colorMode, setColorMode] = useState<ColorMode>('magnitude');
  const [resolution, setResolution] = useState<'lo' | 'hi'>('lo');
  const [matrixN, setMatrixN] = useState(DEFAULT_N);
  const [data, setData] = useState<GramData | null>(null);
  const [loading, setLoading] = useState(true);

  // Enhancement state
  const [logScale, setLogScale] = useState(false);
  const [diagonalOnly, setDiagonalOnly] = useState(false);
  const [hoveredPoint, setHoveredPoint] = useState<GramPoint | null>(null);
  const [selectedJ, setSelectedJ] = useState<number | null>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  const loadData = useCallback(async (n: number, res: 'lo' | 'hi') => {
    setLoading(true);
    try {
      const resp = await fetch(`/data/gram_N${n}_${res}.json`);
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const json: GramData = await resp.json();
      setData(json);
    } catch (err) {
      console.error('Failed to load Gram data:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData(matrixN, resolution);
  }, [matrixN, resolution, loadData]);

  // Filter points for diagonal-only mode
  const filteredPoints = data ? (
    diagonalOnly
      ? data.points.filter(p => p.j === p.k)
      : data.points
  ) : [];

  // Extract row data for selected j
  const rowData = (data && selectedJ !== null)
    ? data.points
        .filter(p => p.j === selectedJ || p.k === selectedJ)
        .map(p => ({
          index: p.j === selectedJ ? p.k : p.j,
          value: p.v,
        }))
        .sort((a, b) => a.index - b.index)
    : null;

  const metadata = data ? {
    N: data.metadata.N,
    dim: data.metadata.dim,
    globalMin: data.metadata.globalMin,
    globalMax: data.metadata.globalMax,
    numPoints: data.metadata.numPoints,
    resolution: data.metadata.resolution,
  } : null;

  // Screenshot export
  const handleScreenshot = useCallback(() => {
    // Use the Three.js canvas
    const canvas = document.querySelector('canvas');
    if (!canvas) return;

    // Create a composite with sidebar info
    const link = document.createElement('a');
    link.download = `gram_N${matrixN}_${vizMode}_${colorMode}.png`;
    link.href = canvas.toDataURL('image/png');
    link.click();
  }, [matrixN, vizMode, colorMode]);

  return (
    <div style={{ width: '100vw', height: '100vh', display: 'flex' }}>
      <Sidebar
        vizMode={vizMode}
        setVizMode={setVizMode}
        colorMode={colorMode}
        setColorMode={setColorMode}
        resolution={resolution}
        setResolution={setResolution}
        matrixN={matrixN}
        setMatrixN={setMatrixN}
        availableSizes={AVAILABLE_SIZES}
        logScale={logScale}
        setLogScale={setLogScale}
        diagonalOnly={diagonalOnly}
        setDiagonalOnly={setDiagonalOnly}
        selectedJ={selectedJ}
        setSelectedJ={setSelectedJ}
        maxJ={data ? data.metadata.dim : 0}
        onScreenshot={handleScreenshot}
        metadata={metadata}
        loading={loading}
      />

      <div style={{
        marginLeft: '260px',
        flex: 1,
        position: 'relative',
      }}>
        <Canvas
          camera={{
            position: [3.5, 2.5, 3.5],
            fov: 50,
            near: 0.01,
            far: 100,
          }}
          gl={{ antialias: true, alpha: false, preserveDrawingBuffer: true }}
          style={{ background: '#050508' }}
        >
          {/* Lighting */}
          <ambientLight intensity={0.4} />
          <directionalLight position={[5, 8, 5]} intensity={0.8} color="#ffffff" />
          <directionalLight position={[-3, 4, -2]} intensity={0.3} color="#6688ff" />
          <pointLight position={[0, 3, 0]} intensity={0.5} color="#ff8844" distance={10} />

          {/* Controls */}
          <OrbitControls
            enableDamping
            dampingFactor={0.08}
            minDistance={1}
            maxDistance={20}
            target={[0, 0.3, 0]}
          />

          {/* Visualization */}
          <Suspense fallback={null}>
            {data && vizMode === 'surface' && (
              <GramSurface
                points={filteredPoints}
                colorMode={colorMode}
                globalMin={data.metadata.globalMin}
                globalMax={data.metadata.globalMax}
                scale={SCALE}
                logScale={logScale}
                onHover={setHoveredPoint}
              />
            )}
            {data && vizMode === 'cloud' && (
              <GramPointCloud
                points={filteredPoints}
                colorMode={colorMode}
                globalMin={data.metadata.globalMin}
                globalMax={data.metadata.globalMax}
                scale={SCALE}
                logScale={logScale}
              />
            )}
            {data && vizMode === 'heatmap' && (
              <GramHeatmap
                points={filteredPoints}
                colorMode={colorMode}
                globalMin={data.metadata.globalMin}
                globalMax={data.metadata.globalMax}
                scale={SCALE}
                logScale={logScale}
              />
            )}
          </Suspense>

          {/* Axis grid */}
          {data && (
            <AxisGrid
              scale={SCALE}
              maxJ={data.metadata.dim}
              maxK={data.metadata.dim}
            />
          )}

          {/* Subtle fog for depth */}
          <fog attach="fog" args={['#050508', 8, 25]} />
        </Canvas>

        {/* Tooltip overlay */}
        <Tooltip point={hoveredPoint} />

        {/* Row slice overlay */}
        {rowData && selectedJ !== null && (
          <RowSlice
            data={rowData}
            j={selectedJ}
            onClose={() => setSelectedJ(null)}
          />
        )}

        {/* Keyboard hint */}
        <div style={{
          position: 'absolute',
          bottom: '16px',
          right: '16px',
          fontSize: '10px',
          color: 'rgba(255,255,255,0.2)',
          fontFamily: "'JetBrains Mono', monospace",
        }}>
          drag to rotate · scroll to zoom
        </div>
      </div>
    </div>
  );
}
