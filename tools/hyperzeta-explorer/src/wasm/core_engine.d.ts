/* tslint:disable */
/* eslint-disable */

export class HyperEngine {
    free(): void;
    [Symbol.dispose](): void;
    get_buffer_pointer(): number;
    /**
     * Centroid X of output cloud
     */
    get_centroid_x(): number;
    /**
     * Centroid Y of output cloud
     */
    get_centroid_y(): number;
    /**
     * Centroid Z of output cloud
     */
    get_centroid_z(): number;
    /**
     * Running mean of collapse metric
     */
    get_collapse_mean(): number;
    get_collapse_metric(): number;
    /**
     * Elongation ratio λ₁/λ₂ — spikes when particles form a line
     */
    get_elongation(): number;
    /**
     * Flatness ratio λ₁/λ₃ — spikes when particles form a disc or line
     */
    get_flatness(): number;
    /**
     * Fluctuation energy E_S(t) — the TimeDomainBridge primitive
     */
    get_fluctuation_energy(): number;
    /**
     * Gram form bound: |vᵀGv - asymptotic| ≤ this value
     */
    get_gram_bound(): number;
    get_lambda(): number;
    get_layer_buffer_pointer(): number;
    /**
     * Get layer energy for the given Cayley-Dickson level (0-5)
     */
    get_layer_energy(level: number): number;
    /**
     * PCA eigenvalue λ₁ (largest — dominant direction)
     */
    get_pca_lambda1(): number;
    /**
     * PCA eigenvalue λ₂ (second)
     */
    get_pca_lambda2(): number;
    /**
     * PCA eigenvalue λ₃ (smallest)
     */
    get_pca_lambda3(): number;
    /**
     * Peak |E_S| seen so far
     */
    get_peak_fluctuation(): number;
    /**
     * Get prime harmonic energy for prime index k (0-126)
     */
    get_prime_energy(k: number): number;
    /**
     * Get prime uniformity score (0-1, 1 = perfectly uniform)
     */
    get_prime_uniformity(): number;
    get_tower_level(): number;
    get_view_mode(): number;
    constructor(particle_count: number);
    /**
     * Set Cayley-Dickson tower level (0-7):
     * 0=ℝ(0), 1=ℂ(1), 2=ℍ(3), 3=𝕆(7), 4=𝕊(15), 5=𝕋(31), 6=𝕍(63), 7=∞(127)
     */
    set_tower_level(level: number): void;
    set_view_mode(mode: number): void;
    tick_physics(): void;
}

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly __wbg_hyperengine_free: (a: number, b: number) => void;
    readonly hyperengine_get_buffer_pointer: (a: number) => number;
    readonly hyperengine_get_centroid_x: (a: number) => number;
    readonly hyperengine_get_centroid_y: (a: number) => number;
    readonly hyperengine_get_centroid_z: (a: number) => number;
    readonly hyperengine_get_collapse_mean: (a: number) => number;
    readonly hyperengine_get_collapse_metric: (a: number) => number;
    readonly hyperengine_get_elongation: (a: number) => number;
    readonly hyperengine_get_flatness: (a: number) => number;
    readonly hyperengine_get_fluctuation_energy: (a: number) => number;
    readonly hyperengine_get_gram_bound: (a: number) => number;
    readonly hyperengine_get_lambda: (a: number) => number;
    readonly hyperengine_get_layer_buffer_pointer: (a: number) => number;
    readonly hyperengine_get_layer_energy: (a: number, b: number) => number;
    readonly hyperengine_get_pca_lambda1: (a: number) => number;
    readonly hyperengine_get_pca_lambda2: (a: number) => number;
    readonly hyperengine_get_pca_lambda3: (a: number) => number;
    readonly hyperengine_get_peak_fluctuation: (a: number) => number;
    readonly hyperengine_get_prime_energy: (a: number, b: number) => number;
    readonly hyperengine_get_prime_uniformity: (a: number) => number;
    readonly hyperengine_get_tower_level: (a: number) => number;
    readonly hyperengine_get_view_mode: (a: number) => number;
    readonly hyperengine_new: (a: number) => number;
    readonly hyperengine_set_tower_level: (a: number, b: number) => void;
    readonly hyperengine_set_view_mode: (a: number, b: number) => void;
    readonly hyperengine_tick_physics: (a: number) => void;
    readonly __wbindgen_exn_store: (a: number) => void;
    readonly __externref_table_alloc: () => number;
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
 * Instantiates the given `module`, which can either be bytes or
 * a precompiled `WebAssembly.Module`.
 *
 * @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
 *
 * @returns {InitOutput}
 */
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
 * If `module_or_path` is {RequestInfo} or {URL}, makes a request and
 * for everything else, calls `WebAssembly.instantiate` directly.
 *
 * @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
 *
 * @returns {Promise<InitOutput>}
 */
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
