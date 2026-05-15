/**
 * Surface shader — height-field displacement with contour lines.
 * Used by SurfaceRenderer for Gram Heatmap and Spectral Gap.
 */

export const surfaceVertexShader = /* glsl */ `
  uniform float uHeightScale;
  uniform float uTime;
  uniform sampler2D uHeightMap;

  attribute vec2 aUV;

  varying float vHeight;
  varying vec2 vUv;
  varying float vDepth;

  void main() {
    vUv = uv;

    // Sample height from data texture
    float h = texture2D(uHeightMap, uv).r;
    vHeight = h;

    // Displace vertex along Y by height
    vec3 displaced = position;
    displaced.z = h * uHeightScale;

    vec4 mvPosition = modelViewMatrix * vec4(displaced, 1.0);
    vDepth = -mvPosition.z;

    gl_Position = projectionMatrix * mvPosition;
  }
`;

export const surfaceFragmentShader = /* glsl */ `
  uniform float uTime;
  uniform float uContourFreq;
  uniform vec3 uColorLow;
  uniform vec3 uColorMid;
  uniform vec3 uColorHigh;
  uniform float uWireframe;

  varying float vHeight;
  varying vec2 vUv;
  varying float vDepth;

  void main() {
    // Height-based color gradient (3-stop)
    vec3 color;
    if (vHeight < 0.5) {
      color = mix(uColorLow, uColorMid, vHeight * 2.0);
    } else {
      color = mix(uColorMid, uColorHigh, (vHeight - 0.5) * 2.0);
    }

    // Contour lines via fract()
    float contour = abs(fract(vHeight * uContourFreq) - 0.5);
    float line = smoothstep(0.02, 0.04, contour);
    color = mix(color * 1.4, color, line);

    // Depth fade
    float depthFade = 1.0 / (1.0 + vDepth * 0.015);
    float alpha = depthFade * 0.9;

    // Wireframe overlay
    if (uWireframe > 0.5) {
      float edge = min(
        min(fract(vUv.x * 32.0), 1.0 - fract(vUv.x * 32.0)),
        min(fract(vUv.y * 32.0), 1.0 - fract(vUv.y * 32.0))
      );
      float wireAlpha = smoothstep(0.0, 0.02, edge);
      color = mix(vec3(1.0), color, wireAlpha);
    }

    gl_FragColor = vec4(color, alpha);
  }
`;
