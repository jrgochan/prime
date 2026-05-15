/* tslint:disable */
/* eslint-disable */

export class HyperEngine {
    free(): void;
    [Symbol.dispose](): void;
    get_buffer_pointer(): number;
    get_layer_buffer_pointer(): number;
    get_collapse_metric(): number;
    get_lambda(): number;
    set_view_mode(mode: number): void;
    get_view_mode(): number;
    get_layer_energy(level: number): number;
    constructor(particle_count: number);
    tick_physics(): void;
}

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly __wbg_hyperengine_free: (a: number, b: number) => void;
    readonly hyperengine_get_buffer_pointer: (a: number) => number;
    readonly hyperengine_get_layer_buffer_pointer: (a: number) => number;
    readonly hyperengine_get_collapse_metric: (a: number) => number;
    readonly hyperengine_get_lambda: (a: number) => number;
    readonly hyperengine_set_view_mode: (a: number, b: number) => void;
    readonly hyperengine_get_view_mode: (a: number) => number;
    readonly hyperengine_get_layer_energy: (a: number, b: number) => number;
    readonly hyperengine_new: (a: number) => number;
    readonly hyperengine_tick_physics: (a: number) => void;
    readonly __wbindgen_exn_store: (a: number) => void;
    readonly __externref_table_alloc: () => number;
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
