"use client";

import { Text } from "@react-three/drei";
import * as THREE from "three";

const AXIS_LENGTH = 20;

function AxisLine({
  start,
  end,
  color,
}: {
  start: [number, number, number];
  end: [number, number, number];
  color: string;
}) {
  const positions = new Float32Array([...start, ...end]);
  return (
    <line>
      <bufferGeometry>
        <bufferAttribute
          attach="attributes-position"
          args={[positions, 3]}
          count={2}
          itemSize={3}
        />
      </bufferGeometry>
      <lineBasicMaterial color={color} />
    </line>
  );
}

export function AxisLabels() {
  return (
    <>
      <AxisLine
        start={[-AXIS_LENGTH, 0, 0]}
        end={[AXIS_LENGTH, 0, 0]}
        color="#1a3322"
      />
      <AxisLine
        start={[0, -AXIS_LENGTH, 0]}
        end={[0, AXIS_LENGTH, 0]}
        color="#1a2833"
      />
      <AxisLine
        start={[0, 0, -AXIS_LENGTH]}
        end={[0, 0, AXIS_LENGTH]}
        color="#331a28"
      />

      <Text
        position={[AXIS_LENGTH + 2, 0, 0]}
        fontSize={0.8}
        color="#00ff88"
        anchorX="center"
        anchorY="middle"
      >
        Im(i)
      </Text>
      <Text
        position={[0, AXIS_LENGTH + 2, 0]}
        fontSize={0.8}
        color="#00ccff"
        anchorX="center"
        anchorY="middle"
      >
        Im(j)
      </Text>
      <Text
        position={[0, 0, AXIS_LENGTH + 2]}
        fontSize={0.8}
        color="#ff6b9d"
        anchorX="center"
        anchorY="middle"
      >
        Im(k)
      </Text>
    </>
  );
}
