"use client";

/**
 * LatticeCloud — backward-compatibility wrapper.
 * The actual particle rendering logic has been extracted to
 * scene/renderers/ParticleRenderer.tsx as part of the v2
 * renderer abstraction layer.
 *
 * This file re-exports ParticleRenderer so existing imports work.
 */
export { ParticleRenderer as LatticeCloud } from "./renderers/ParticleRenderer";
