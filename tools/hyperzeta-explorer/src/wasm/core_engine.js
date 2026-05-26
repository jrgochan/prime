/* @ts-self-types="./core_engine.d.ts" */

export class HyperEngine {
    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        HyperEngineFinalization.unregister(this);
        return ptr;
    }
    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_hyperengine_free(ptr, 0);
    }
    /**
     * @returns {number}
     */
    get_buffer_pointer() {
        const ret = wasm.hyperengine_get_buffer_pointer(this.__wbg_ptr);
        return ret >>> 0;
    }
    /**
     * Centroid X of output cloud
     * @returns {number}
     */
    get_centroid_x() {
        const ret = wasm.hyperengine_get_centroid_x(this.__wbg_ptr);
        return ret;
    }
    /**
     * Centroid Y of output cloud
     * @returns {number}
     */
    get_centroid_y() {
        const ret = wasm.hyperengine_get_centroid_y(this.__wbg_ptr);
        return ret;
    }
    /**
     * Centroid Z of output cloud
     * @returns {number}
     */
    get_centroid_z() {
        const ret = wasm.hyperengine_get_centroid_z(this.__wbg_ptr);
        return ret;
    }
    /**
     * Running mean of collapse metric
     * @returns {number}
     */
    get_collapse_mean() {
        const ret = wasm.hyperengine_get_collapse_mean(this.__wbg_ptr);
        return ret;
    }
    /**
     * @returns {number}
     */
    get_collapse_metric() {
        const ret = wasm.hyperengine_get_collapse_metric(this.__wbg_ptr);
        return ret;
    }
    /**
     * Elongation ratio λ₁/λ₂ — spikes when particles form a line
     * @returns {number}
     */
    get_elongation() {
        const ret = wasm.hyperengine_get_elongation(this.__wbg_ptr);
        return ret;
    }
    /**
     * Flatness ratio λ₁/λ₃ — spikes when particles form a disc or line
     * @returns {number}
     */
    get_flatness() {
        const ret = wasm.hyperengine_get_flatness(this.__wbg_ptr);
        return ret;
    }
    /**
     * Fluctuation energy E_S(t) — the TimeDomainBridge primitive
     * @returns {number}
     */
    get_fluctuation_energy() {
        const ret = wasm.hyperengine_get_fluctuation_energy(this.__wbg_ptr);
        return ret;
    }
    /**
     * Gram form bound: |vᵀGv - asymptotic| ≤ this value
     * @returns {number}
     */
    get_gram_bound() {
        const ret = wasm.hyperengine_get_gram_bound(this.__wbg_ptr);
        return ret;
    }
    /**
     * Current height t on the critical line (for Teardrop Ascent HUD)
     * @returns {number}
     */
    get_height() {
        const ret = wasm.hyperengine_get_height(this.__wbg_ptr);
        return ret;
    }
    /**
     * @returns {number}
     */
    get_lambda() {
        const ret = wasm.hyperengine_get_lambda(this.__wbg_ptr);
        return ret;
    }
    /**
     * @returns {number}
     */
    get_layer_buffer_pointer() {
        const ret = wasm.hyperengine_get_layer_buffer_pointer(this.__wbg_ptr);
        return ret >>> 0;
    }
    /**
     * Get layer energy for the given Cayley-Dickson level (0-5)
     * @param {number} level
     * @returns {number}
     */
    get_layer_energy(level) {
        const ret = wasm.hyperengine_get_layer_energy(this.__wbg_ptr, level);
        return ret;
    }
    /**
     * PCA eigenvalue λ₁ (largest — dominant direction)
     * @returns {number}
     */
    get_pca_lambda1() {
        const ret = wasm.hyperengine_get_pca_lambda1(this.__wbg_ptr);
        return ret;
    }
    /**
     * PCA eigenvalue λ₂ (second)
     * @returns {number}
     */
    get_pca_lambda2() {
        const ret = wasm.hyperengine_get_pca_lambda2(this.__wbg_ptr);
        return ret;
    }
    /**
     * PCA eigenvalue λ₃ (smallest)
     * @returns {number}
     */
    get_pca_lambda3() {
        const ret = wasm.hyperengine_get_pca_lambda3(this.__wbg_ptr);
        return ret;
    }
    /**
     * Peak |E_S| seen so far
     * @returns {number}
     */
    get_peak_fluctuation() {
        const ret = wasm.hyperengine_get_peak_fluctuation(this.__wbg_ptr);
        return ret;
    }
    /**
     * Get prime harmonic energy for prime index k (0-126)
     * @param {number} k
     * @returns {number}
     */
    get_prime_energy(k) {
        const ret = wasm.hyperengine_get_prime_energy(this.__wbg_ptr, k);
        return ret;
    }
    /**
     * Get prime uniformity score (0-1, 1 = perfectly uniform)
     * @returns {number}
     */
    get_prime_uniformity() {
        const ret = wasm.hyperengine_get_prime_uniformity(this.__wbg_ptr);
        return ret;
    }
    /**
     * @returns {number}
     */
    get_tower_level() {
        const ret = wasm.hyperengine_get_tower_level(this.__wbg_ptr);
        return ret >>> 0;
    }
    /**
     * @returns {number}
     */
    get_view_mode() {
        const ret = wasm.hyperengine_get_view_mode(this.__wbg_ptr);
        return ret >>> 0;
    }
    /**
     * @param {number} particle_count
     */
    constructor(particle_count) {
        const ret = wasm.hyperengine_new(particle_count);
        this.__wbg_ptr = ret;
        HyperEngineFinalization.register(this, this.__wbg_ptr, this);
        return this;
    }
    /**
     * Set Cayley-Dickson tower level (0-7):
     * 0=ℝ(0), 1=ℂ(1), 2=ℍ(3), 3=𝕆(7), 4=𝕊(15), 5=𝕋(31), 6=𝕍(63), 7=∞(127)
     * @param {number} level
     */
    set_tower_level(level) {
        wasm.hyperengine_set_tower_level(this.__wbg_ptr, level);
    }
    /**
     * @param {number} mode
     */
    set_view_mode(mode) {
        wasm.hyperengine_set_view_mode(this.__wbg_ptr, mode);
    }
    tick_physics() {
        wasm.hyperengine_tick_physics(this.__wbg_ptr);
    }
}
if (Symbol.dispose) HyperEngine.prototype[Symbol.dispose] = HyperEngine.prototype.free;
function __wbg_get_imports() {
    const import0 = {
        __proto__: null,
        __wbg___wbindgen_is_function_5cd60d5cf78b4eef: function(arg0) {
            const ret = typeof(arg0) === 'function';
            return ret;
        },
        __wbg___wbindgen_is_object_b4593df85baada48: function(arg0) {
            const val = arg0;
            const ret = typeof(val) === 'object' && val !== null;
            return ret;
        },
        __wbg___wbindgen_is_string_dde0fd9020db4434: function(arg0) {
            const ret = typeof(arg0) === 'string';
            return ret;
        },
        __wbg___wbindgen_is_undefined_35bb9f4c7fd651d5: function(arg0) {
            const ret = arg0 === undefined;
            return ret;
        },
        __wbg___wbindgen_throw_9c31b086c2b26051: function(arg0, arg1) {
            throw new Error(getStringFromWasm0(arg0, arg1));
        },
        __wbg_call_dfde26266607c996: function() { return handleError(function (arg0, arg1, arg2) {
            const ret = arg0.call(arg1, arg2);
            return ret;
        }, arguments); },
        __wbg_crypto_38df2bab126b63dc: function(arg0) {
            const ret = arg0.crypto;
            return ret;
        },
        __wbg_getRandomValues_c44a50d8cfdaebeb: function() { return handleError(function (arg0, arg1) {
            arg0.getRandomValues(arg1);
        }, arguments); },
        __wbg_length_56fcd3e2b7e0299d: function(arg0) {
            const ret = arg0.length;
            return ret;
        },
        __wbg_msCrypto_bd5a034af96bcba6: function(arg0) {
            const ret = arg0.msCrypto;
            return ret;
        },
        __wbg_new_with_length_99887c91eae4abab: function(arg0) {
            const ret = new Uint8Array(arg0 >>> 0);
            return ret;
        },
        __wbg_node_84ea875411254db1: function(arg0) {
            const ret = arg0.node;
            return ret;
        },
        __wbg_process_44c7a14e11e9f69e: function(arg0) {
            const ret = arg0.process;
            return ret;
        },
        __wbg_prototypesetcall_5f9bdc8d75e07276: function(arg0, arg1, arg2) {
            Uint8Array.prototype.set.call(getArrayU8FromWasm0(arg0, arg1), arg2);
        },
        __wbg_randomFillSync_6c25eac9869eb53c: function() { return handleError(function (arg0, arg1) {
            arg0.randomFillSync(arg1);
        }, arguments); },
        __wbg_require_b4edbdcf3e2a1ef0: function() { return handleError(function () {
            const ret = module.require;
            return ret;
        }, arguments); },
        __wbg_static_accessor_GLOBAL_THIS_02344c9b09eb08a9: function() {
            const ret = typeof globalThis === 'undefined' ? null : globalThis;
            return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
        },
        __wbg_static_accessor_GLOBAL_ac6d4ac874d5cd54: function() {
            const ret = typeof global === 'undefined' ? null : global;
            return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
        },
        __wbg_static_accessor_SELF_9b2406c23aeb2023: function() {
            const ret = typeof self === 'undefined' ? null : self;
            return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
        },
        __wbg_static_accessor_WINDOW_b34d2126934e16ba: function() {
            const ret = typeof window === 'undefined' ? null : window;
            return isLikeNone(ret) ? 0 : addToExternrefTable0(ret);
        },
        __wbg_subarray_7c6a0da8f3b4a1ba: function(arg0, arg1, arg2) {
            const ret = arg0.subarray(arg1 >>> 0, arg2 >>> 0);
            return ret;
        },
        __wbg_versions_276b2795b1c6a219: function(arg0) {
            const ret = arg0.versions;
            return ret;
        },
        __wbindgen_cast_0000000000000001: function(arg0, arg1) {
            // Cast intrinsic for `Ref(Slice(U8)) -> NamedExternref("Uint8Array")`.
            const ret = getArrayU8FromWasm0(arg0, arg1);
            return ret;
        },
        __wbindgen_cast_0000000000000002: function(arg0, arg1) {
            // Cast intrinsic for `Ref(String) -> Externref`.
            const ret = getStringFromWasm0(arg0, arg1);
            return ret;
        },
        __wbindgen_init_externref_table: function() {
            const table = wasm.__wbindgen_externrefs;
            const offset = table.grow(4);
            table.set(0, undefined);
            table.set(offset + 0, undefined);
            table.set(offset + 1, null);
            table.set(offset + 2, true);
            table.set(offset + 3, false);
        },
    };
    return {
        __proto__: null,
        "./core_engine_bg.js": import0,
    };
}

const HyperEngineFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_hyperengine_free(ptr, 1));

function addToExternrefTable0(obj) {
    const idx = wasm.__externref_table_alloc();
    wasm.__wbindgen_externrefs.set(idx, obj);
    return idx;
}

function getArrayU8FromWasm0(ptr, len) {
    ptr = ptr >>> 0;
    return getUint8ArrayMemory0().subarray(ptr / 1, ptr / 1 + len);
}

function getStringFromWasm0(ptr, len) {
    return decodeText(ptr >>> 0, len);
}

let cachedUint8ArrayMemory0 = null;
function getUint8ArrayMemory0() {
    if (cachedUint8ArrayMemory0 === null || cachedUint8ArrayMemory0.byteLength === 0) {
        cachedUint8ArrayMemory0 = new Uint8Array(wasm.memory.buffer);
    }
    return cachedUint8ArrayMemory0;
}

function handleError(f, args) {
    try {
        return f.apply(this, args);
    } catch (e) {
        const idx = addToExternrefTable0(e);
        wasm.__wbindgen_exn_store(idx);
    }
}

function isLikeNone(x) {
    return x === undefined || x === null;
}

let cachedTextDecoder = new TextDecoder('utf-8', { ignoreBOM: true, fatal: true });
cachedTextDecoder.decode();
const MAX_SAFARI_DECODE_BYTES = 2146435072;
let numBytesDecoded = 0;
function decodeText(ptr, len) {
    numBytesDecoded += len;
    if (numBytesDecoded >= MAX_SAFARI_DECODE_BYTES) {
        cachedTextDecoder = new TextDecoder('utf-8', { ignoreBOM: true, fatal: true });
        cachedTextDecoder.decode();
        numBytesDecoded = len;
    }
    return cachedTextDecoder.decode(getUint8ArrayMemory0().subarray(ptr, ptr + len));
}

let wasmModule, wasmInstance, wasm;
function __wbg_finalize_init(instance, module) {
    wasmInstance = instance;
    wasm = instance.exports;
    wasmModule = module;
    cachedUint8ArrayMemory0 = null;
    wasm.__wbindgen_start();
    return wasm;
}

async function __wbg_load(module, imports) {
    if (typeof Response === 'function' && module instanceof Response) {
        if (typeof WebAssembly.instantiateStreaming === 'function') {
            try {
                return await WebAssembly.instantiateStreaming(module, imports);
            } catch (e) {
                const validResponse = module.ok && expectedResponseType(module.type);

                if (validResponse && module.headers.get('Content-Type') !== 'application/wasm') {
                    console.warn("`WebAssembly.instantiateStreaming` failed because your server does not serve Wasm with `application/wasm` MIME type. Falling back to `WebAssembly.instantiate` which is slower. Original error:\n", e);

                } else { throw e; }
            }
        }

        const bytes = await module.arrayBuffer();
        return await WebAssembly.instantiate(bytes, imports);
    } else {
        const instance = await WebAssembly.instantiate(module, imports);

        if (instance instanceof WebAssembly.Instance) {
            return { instance, module };
        } else {
            return instance;
        }
    }

    function expectedResponseType(type) {
        switch (type) {
            case 'basic': case 'cors': case 'default': return true;
        }
        return false;
    }
}

function initSync(module) {
    if (wasm !== undefined) return wasm;


    if (module !== undefined) {
        if (Object.getPrototypeOf(module) === Object.prototype) {
            ({module} = module)
        } else {
            console.warn('using deprecated parameters for `initSync()`; pass a single object instead')
        }
    }

    const imports = __wbg_get_imports();
    if (!(module instanceof WebAssembly.Module)) {
        module = new WebAssembly.Module(module);
    }
    const instance = new WebAssembly.Instance(module, imports);
    return __wbg_finalize_init(instance, module);
}

async function __wbg_init(module_or_path) {
    if (wasm !== undefined) return wasm;


    if (module_or_path !== undefined) {
        if (Object.getPrototypeOf(module_or_path) === Object.prototype) {
            ({module_or_path} = module_or_path)
        } else {
            console.warn('using deprecated parameters for the initialization function; pass a single object instead')
        }
    }

    if (module_or_path === undefined) {
        module_or_path = new URL('core_engine_bg.wasm', import.meta.url);
    }
    const imports = __wbg_get_imports();

    if (typeof module_or_path === 'string' || (typeof Request === 'function' && module_or_path instanceof Request) || (typeof URL === 'function' && module_or_path instanceof URL)) {
        module_or_path = fetch(module_or_path);
    }

    const { instance, module } = await __wbg_load(await module_or_path, imports);

    return __wbg_finalize_init(instance, module);
}

export { initSync, __wbg_init as default };
