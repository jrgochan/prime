'use client';

import { useMemo } from 'react';
import * as THREE from 'three';
import { GramPoint, ColorMode, getPointColor } from '@/lib/colorMaps';

interface Props {
  points: GramPoint[];
  colorMode: ColorMode;
  globalMin: number;
  globalMax: number;
  scale: { x: number; y: number; z: number };
}

/**
 * 3D point cloud of the Gram matrix.
 * Each (j, k, G(j,k)) rendered as a colored particle.
 */
export default function GramPointCloud({ points, colorMode, globalMin, globalMax, scale }: Props) {
  const { positions, colors } = useMemo(() => {
    const pos = new Float32Array(points.length * 3);
    const col = new Float32Array(points.length * 3);

    const jMax = Math.max(...points.map(p => p.j));
    const kMax = Math.max(...points.map(p => p.k));
    const absMax = Math.max(Math.abs(globalMin), Math.abs(globalMax));
    const maxDist = Math.max(...points.map(p => Math.abs(p.j - p.k)));

    points.forEach((pt, i) => {
      const x = (pt.j / jMax - 0.5) * 2 * scale.x;
      const y = (pt.k / kMax - 0.5) * 2 * scale.y;
      const z = (pt.v / absMax) * scale.z;

      pos[i * 3] = x;
      pos[i * 3 + 1] = z;     // y-up
      pos[i * 3 + 2] = y;

      const color = getPointColor(pt, colorMode, globalMin, globalMax, maxDist);
      col[i * 3] = color.r;
      col[i * 3 + 1] = color.g;
      col[i * 3 + 2] = color.b;
    });

    return { positions: pos, colors: col };
  }, [points, colorMode, globalMin, globalMax, scale]);

  return (
    <points>
      <bufferGeometry>
        <bufferAttribute
          attach="attributes-position"
          array={positions}
          count={positions.length / 3}
          itemSize={3}
        />
        <bufferAttribute
          attach="attributes-color"
          array={colors}
          count={colors.length / 3}
          itemSize={3}
        />
      </bufferGeometry>
      <pointsMaterial
        vertexColors
        size={0.015}
        sizeAttenuation
        transparent
        opacity={0.85}
      />
    </points>
  );
}
