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
 * Extruded heatmap: 2D grid with height = |G(j,k)|, color = G(j,k).
 * Each cell is a thin box extruded upward.
 */
export default function GramHeatmap({ points, colorMode, globalMin, globalMax, scale }: Props) {
  const geometry = useMemo(() => {
    if (points.length === 0) return null;

    // Expand to full symmetric set
    const fullPoints: GramPoint[] = [];
    points.forEach(pt => {
      fullPoints.push(pt);
      if (pt.j !== pt.k) {
        fullPoints.push({ ...pt, j: pt.k, k: pt.j });
      }
    });

    const jMax = Math.max(...fullPoints.map(p => p.j));
    const kMax = Math.max(...fullPoints.map(p => p.k));
    const absMax = Math.max(Math.abs(globalMin), Math.abs(globalMax));
    const maxDist = Math.max(...fullPoints.map(p => Math.abs(p.j - p.k)));

    // Estimate cell size from spacing
    const jSet = new Set(points.map(p => p.j));
    const js = Array.from(jSet).sort((a, b) => a - b);
    const cellSize = js.length > 1
      ? ((js[1] - js[0]) / jMax) * 2 * scale.x * 0.9
      : 0.02;

    // Create instanced boxes
    const positions: number[] = [];
    const colors: number[] = [];
    const indices: number[] = [];
    let vertIdx = 0;

    fullPoints.forEach(pt => {
      const x = (pt.j / jMax - 0.5) * 2 * scale.x;
      const z = (pt.k / kMax - 0.5) * 2 * scale.y;
      const height = Math.max(0.001, (Math.abs(pt.v) / absMax) * scale.z);

      const color = getPointColor(pt, colorMode, globalMin, globalMax, maxDist);
      const half = cellSize * 0.5;

      // 8 vertices for a box
      const verts = [
        // Bottom face (y=0)
        [x - half, 0, z - half],
        [x + half, 0, z - half],
        [x + half, 0, z + half],
        [x - half, 0, z + half],
        // Top face (y=height)
        [x - half, height, z - half],
        [x + half, height, z - half],
        [x + half, height, z + half],
        [x - half, height, z + half],
      ];

      verts.forEach(v => {
        positions.push(v[0], v[1], v[2]);
        colors.push(color.r, color.g, color.b);
      });

      const base = vertIdx;
      // Top face
      indices.push(base + 4, base + 5, base + 6, base + 4, base + 6, base + 7);
      // Front face
      indices.push(base + 0, base + 1, base + 5, base + 0, base + 5, base + 4);
      // Right face
      indices.push(base + 1, base + 2, base + 6, base + 1, base + 6, base + 5);
      // Back face
      indices.push(base + 2, base + 3, base + 7, base + 2, base + 7, base + 6);
      // Left face
      indices.push(base + 3, base + 0, base + 4, base + 3, base + 4, base + 7);

      vertIdx += 8;
    });

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
        metalness={0.2}
        roughness={0.5}
      />
    </mesh>
  );
}
