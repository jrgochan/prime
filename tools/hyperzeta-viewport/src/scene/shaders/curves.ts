/**
 * Curve shader — glowing lines with animated dash patterns.
 * Used by CurveRenderer for Perron Contour and Enhanced Waves.
 */

export const curveVertexShader = /* glsl */ `
  uniform float uTime;
  uniform float uDashSpeed;

  attribute float aArcLength;
  attribute vec3 aColor;

  varying float vArcLength;
  varying vec3 vColor;
  varying float vDepth;

  void main() {
    vArcLength = aArcLength;
    vColor = aColor;

    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    vDepth = -mvPosition.z;

    gl_Position = projectionMatrix * mvPosition;
  }
`;

export const curveFragmentShader = /* glsl */ `
  uniform float uTime;
  uniform float uDashSpeed;
  uniform float uDashLength;
  uniform float uGlowIntensity;
  uniform float uProgress;  // 0..1 animated reveal

  varying float vArcLength;
  varying vec3 vColor;
  varying float vDepth;

  void main() {
    // Animated reveal: only show up to uProgress along the arc
    float maxArc = uProgress;
    if (vArcLength > maxArc) discard;

    // Animated dash pattern (traveling along the curve)
    float dashPhase = vArcLength - uTime * uDashSpeed;
    float dash = smoothstep(0.0, 0.1, fract(dashPhase / uDashLength));

    // Depth-based fade
    float depthFade = 1.0 / (1.0 + vDepth * 0.02);

    // Core brightness
    float alpha = dash * depthFade * uGlowIntensity;

    // Fade in at the leading edge
    float edgeFade = smoothstep(maxArc, maxArc - 0.05, vArcLength);
    alpha *= edgeFade;

    gl_FragColor = vec4(vColor, alpha);
  }
`;
