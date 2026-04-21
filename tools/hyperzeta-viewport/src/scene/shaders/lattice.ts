/**
 * GLSL shaders for the sedenion lattice particle cloud.
 * Inlined as template strings for Turbopack compatibility.
 */

export const vertexShader = /* glsl */ `
  varying float vDist;
  varying float vFog;

  void main() {
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);

    // Distance from origin — used for gradient coloring
    vDist = length(position);

    // Fog factor for depth fading
    vFog = smoothstep(2.0, 80.0, -mvPosition.z);

    // Size attenuation — closer particles appear larger
    gl_PointSize = 2.5 * (300.0 / max(-mvPosition.z, 1.0));

    gl_Position = projectionMatrix * mvPosition;
  }
`;

export const fragmentShader = /* glsl */ `
  uniform vec3 uCoreColor;
  uniform vec3 uEdgeColor;
  uniform float uCollapse;
  uniform float uTime;

  varying float vDist;
  varying float vFog;

  void main() {
    // Circular point mask
    float d = length(gl_PointCoord - 0.5);
    if (d > 0.5) discard;

    // Soft glow falloff
    float glow = smoothstep(0.5, 0.0, d);
    float alpha = glow * 0.75;

    // Distance-based gradient: core → edge
    float t = clamp(vDist / 25.0, 0.0, 1.0);
    vec3 color = mix(uCoreColor, uEdgeColor, t);

    // Collapse-driven brightness boost near singularity
    float collapseBoost = smoothstep(2.0, 0.1, uCollapse);
    color += collapseBoost * uCoreColor * 0.3 * glow;

    // Fog fade for depth
    alpha *= (1.0 - vFog * 0.6);

    gl_FragColor = vec4(color, alpha);
  }
`;
