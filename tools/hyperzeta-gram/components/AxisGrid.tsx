'use client';

import { useMemo } from 'react';
import * as THREE from 'three';
import { Text } from '@react-three/drei';

interface Props {
  scale: { x: number; y: number; z: number };
  maxJ: number;
  maxK: number;
}

/**
 * Subtle axis grid with labeled tick marks.
 * Draws grid lines on the j-k plane and axis labels.
 */
export default function AxisGrid({ scale, maxJ, maxK }: Props) {
  const gridLines = useMemo(() => {
    const lines: { start: [number, number, number]; end: [number, number, number]; }[] = [];
    const numLines = 10;

    // Grid on the j-k plane (y = 0)
    for (let i = 0; i <= numLines; i++) {
      const t = (i / numLines - 0.5) * 2;

      // Lines parallel to k-axis
      lines.push({
        start: [t * scale.x, 0, -scale.y],
        end: [t * scale.x, 0, scale.y],
      });

      // Lines parallel to j-axis
      lines.push({
        start: [-scale.x, 0, t * scale.y],
        end: [scale.x, 0, t * scale.y],
      });
    }

    return lines;
  }, [scale]);

  const tickLabels = useMemo(() => {
    const labels: { pos: [number, number, number]; text: string }[] = [];
    const ticks = [0, 0.25, 0.5, 0.75, 1.0];

    ticks.forEach(t => {
      const jVal = Math.round(t * maxJ);
      const kVal = Math.round(t * maxK);
      const x = (t - 0.5) * 2 * scale.x;
      const z = (t - 0.5) * 2 * scale.y;

      // j-axis labels (along x)
      labels.push({
        pos: [x, -0.05, -scale.y - 0.12],
        text: `${jVal}`,
      });

      // k-axis labels (along z)
      labels.push({
        pos: [-scale.x - 0.12, -0.05, z],
        text: `${kVal}`,
      });
    });

    return labels;
  }, [maxJ, maxK, scale]);

  return (
    <group>
      {/* Grid lines */}
      {gridLines.map((line, i) => (
        <line key={`grid-${i}`}>
          <bufferGeometry>
            <bufferAttribute
              attach="attributes-position"
              array={new Float32Array([...line.start, ...line.end])}
              count={2}
              itemSize={3}
            />
          </bufferGeometry>
          <lineBasicMaterial color="#ffffff" opacity={0.08} transparent />
        </line>
      ))}

      {/* Axis labels */}
      {tickLabels.map((label, i) => (
        <Text
          key={`label-${i}`}
          position={label.pos}
          fontSize={0.06}
          color="#888888"
          anchorX="center"
          anchorY="middle"
        >
          {label.text}
        </Text>
      ))}

      {/* Axis name labels */}
      <Text
        position={[0, -0.05, -scale.y - 0.25]}
        fontSize={0.08}
        color="#aaaaaa"
        anchorX="center"
      >
        j
      </Text>
      <Text
        position={[-scale.x - 0.25, -0.05, 0]}
        fontSize={0.08}
        color="#aaaaaa"
        anchorX="center"
        rotation={[0, Math.PI / 2, 0]}
      >
        k
      </Text>
      <Text
        position={[-scale.x - 0.12, scale.z * 0.5, -scale.y - 0.12]}
        fontSize={0.08}
        color="#aaaaaa"
        anchorX="center"
      >
        G(j,k)
      </Text>
    </group>
  );
}
