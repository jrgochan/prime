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
 * 3D surface mesh of the Gram matrix.
 * Creates a height field from (j, k, G(j,k)) with vertex coloring.
 */
export default function GramSurface({ points, colorMode, globalMin, globalMax, scale }: Props) {
  const geometry = useMemo(() => {
    if (points.length === 0) return null;

    // Build a sorted grid of unique j and k values
    const jSet = new Set<number>();
    const kSet = new Set<number>();
    points.forEach(p => { jSet.add(p.j); kSet.add(p.k); });
    const js = Array.from(jSet).sort((a, b) => a - b);
    const ks = Array.from(kSet).sort((a, b) => a - b);

    // Build lookup map — store both (j,k) and (k,j) since G is symmetric
    const lookup = new Map<string, GramPoint>();
    points.forEach(p => {
      lookup.set(`${p.j},${p.k}`, p);
      if (p.j !== p.k) {
        lookup.set(`${p.k},${p.j}`, { ...p, j: p.k, k: p.j });
      }
    });

    // Create grid vertices
    const positions: number[] = [];
    const colors: number[] = [];
    const indices: number[] = [];
    const maxDist = Math.max(...points.map(p => Math.abs(p.j - p.k)));

    const jMax = Math.max(...js);
    const kMax = Math.max(...ks);
    const absMax = Math.max(Math.abs(globalMin), Math.abs(globalMax));

    // Grid dimensions
    const rows = js.length;
    const cols = ks.length;

    // Build vertices
    for (let ri = 0; ri < rows; ri++) {
      for (let ci = 0; ci < cols; ci++) {
        const j = js[ri];
        const k = ks[ci];
        const key = `${j},${k}`;
        const pt = lookup.get(key);

        // Position: normalized to [-1, 1] range
        const x = (j / jMax - 0.5) * 2 * scale.x;
        const y = (k / kMax - 0.5) * 2 * scale.y;
        const z = pt ? (pt.v / absMax) * scale.z : 0;

        positions.push(x, z, y); // y-up convention: swap y/z

        // Color
        if (pt) {
          const color = getPointColor(pt, colorMode, globalMin, globalMax, maxDist);
          colors.push(color.r, color.g, color.b);
        } else {
          colors.push(0.1, 0.1, 0.15);
        }
      }
    }

    // Build triangle indices
    for (let ri = 0; ri < rows - 1; ri++) {
      for (let ci = 0; ci < cols - 1; ci++) {
        const a = ri * cols + ci;
        const b = a + 1;
        const c = (ri + 1) * cols + ci;
        const d = c + 1;
        indices.push(a, c, b);
        indices.push(b, c, d);
      }
    }

    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    geo.setIndex(indices);
    geo.computeVertexNormals();
    return geo;
  }, [points, colorMode, globalMin, globalMax, scale]);

  if (!geometry) return null;

  return (
    <mesh geometry={geometry}>
      <meshStandardMaterial
        vertexColors
        side={THREE.DoubleSide}
        metalness={0.1}
        roughness={0.6}
      />
    </mesh>
  );
}
