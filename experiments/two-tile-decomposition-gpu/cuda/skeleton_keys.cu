// ═══════════════════════════════════════════════════════════════════════════
//  SKELETON KEY CUDA KERNELS — Two-Tile Decomposition GPU Certifier
//
//  Certifies the Staircase Telescope and Beta Modulo Duality at f64
//  precision across massive coprime pair sets using GPU parallelism.
//
//  Each coprime pair (a,b) is ONE thread block. Within each block:
//    - Threads cooperatively compute sums over {1..b-1} and twoTileSet
//    - Shared memory used for parallel reduction
//    - logΓ and ψ computed via CUDA device functions
//
//  Output: per-pair error measurements for all identities.
// ═══════════════════════════════════════════════════════════════════════════

#include <math.h>
#include <stdio.h>

// ────────────────────────────────────────────────
// DEVICE HELPER FUNCTIONS
// ────────────────────────────────────────────────

/// Fractional part {x} = x - floor(x)
__device__ double frac_part(double x) {
    return x - floor(x);
}

/// Digamma function via asymptotic expansion + recurrence
/// Uses ψ(x+1) = ψ(x) + 1/x to shift to large argument, then
/// asymptotic: ψ(x) ≈ ln(x) - 1/(2x) - Σ B_{2k}/(2k·x^{2k})
__device__ double digamma_device(double x) {
    // Handle negative or zero
    if (x <= 0.0) return nan("");

    double result = 0.0;

    // Shift x to x >= 10 using recurrence ψ(x+1) = ψ(x) + 1/x
    while (x < 10.0) {
        result -= 1.0 / x;
        x += 1.0;
    }

    // Asymptotic expansion for large x
    // ψ(x) ≈ ln(x) - 1/(2x) - 1/(12x²) + 1/(120x⁴) - 1/(252x⁶) + ...
    double inv_x = 1.0 / x;
    double inv_x2 = inv_x * inv_x;
    result += log(x) - 0.5 * inv_x;

    double x2k = inv_x2;
    // Bernoulli numbers B₂/(2·1) = 1/12
    result -= x2k / 12.0;
    x2k *= inv_x2;
    // B₄/(4·2) = -1/120
    result += x2k / 120.0;
    x2k *= inv_x2;
    // B₆/(6·3) = 1/252
    result -= x2k / 252.0;
    x2k *= inv_x2;
    // B₈/(8·4) = -1/240
    result += x2k / 240.0;
    x2k *= inv_x2;
    // B₁₀/(10·5) = 1/132
    result -= x2k * 5.0 / 660.0;
    x2k *= inv_x2;
    // B₁₂/(12·6) = -691/32760
    result += x2k * 691.0 / 32760.0 / 6.0;

    return result;
}

// Cotangent via cos/sin
__device__ double cot_device(double x) {
    return cos(x) / sin(x);
}

// ────────────────────────────────────────────────
// PAIR RESULT STRUCTURE
// ────────────────────────────────────────────────

struct PairResult {
    int a, b;
    int n_two_tile;
    int beta_bijection;
    int s_permutation;

    // Staircase telescope errors
    double telescope_lg_err;
    double telescope_psi_err;

    // Beta duality
    int beta_duality_pw;
    double beta_duality_sum_err;

    // Graduation identity
    double sum_pcl;
    double delta_target;
    double identity_err;

    // Pass/fail
    int certified;
};

// ────────────────────────────────────────────────
// MAIN KERNEL: One block per coprime pair
// ────────────────────────────────────────────────

extern "C"
__global__ void certify_skeleton_keys(
    const int* d_pairs,      // [N×2] array of (a,b) pairs
    PairResult* d_results,   // [N] output results
    int n_pairs
) {
    int pair_idx = blockIdx.x;
    if (pair_idx >= n_pairs) return;

    int a = d_pairs[pair_idx * 2];
    int b = d_pairs[pair_idx * 2 + 1];
    double af = (double)a;
    double bf = (double)b;
    int tid = threadIdx.x;
    int nthreads = blockDim.x;

    // Shared memory for parallel reductions
    extern __shared__ double shared[];
    double* s_data1 = shared;               // [nthreads]
    double* s_data2 = shared + nthreads;    // [nthreads]
    double* s_data3 = shared + 2*nthreads;  // [nthreads]
    double* s_data4 = shared + 3*nthreads;  // [nthreads]

    // ═══ STAIRCASE TELESCOPE (Gemini Key 1) ═══
    // Test with f(m) = lgamma((m+1)/b) and f(m) = digamma((m+1)/b)

    // Step 1: Compute LHS = Σ_{m₀∈TT} f(m₀) for both functions
    double local_tt_lg = 0.0;
    double local_tt_psi = 0.0;
    int local_n_tt = 0;

    for (int m0 = 1 + tid; m0 < b; m0 += nthreads) {
        int n0 = (a * m0) / b;
        if (b * (n0 + 1) < a * (m0 + 1)) {
            double alpha = ((double)(m0 + 1)) / bf;
            local_tt_lg += lgamma(alpha);
            local_tt_psi += digamma_device(alpha);
            local_n_tt++;
        }
    }

    // Step 2: Compute full sums Σ_{m=0}^{b-1} f(m) and Abel sums
    double local_full_lg = 0.0;
    double local_full_psi = 0.0;
    double local_abel_lg = 0.0;
    double local_abel_psi = 0.0;

    for (int m = tid; m < b; m += nthreads) {
        double alpha = ((double)(m + 1)) / bf;
        local_full_lg += lgamma(alpha);
        local_full_psi += digamma_device(alpha);
    }

    for (int r = 1 + tid; r < b; r += nthreads) {
        double frac_val = frac_part(af * (double)r / bf);
        double lg_r = lgamma(((double)(r + 1)) / bf);
        double lg_rm1 = lgamma(((double)r) / bf);
        double psi_r = digamma_device(((double)(r + 1)) / bf);
        double psi_rm1 = digamma_device(((double)r) / bf);
        local_abel_lg += frac_val * (lg_r - lg_rm1);
        local_abel_psi += frac_val * (psi_r - psi_rm1);
    }

    // Reduce within block
    s_data1[tid] = local_tt_lg;
    s_data2[tid] = local_full_lg;
    s_data3[tid] = local_abel_lg;
    s_data4[tid] = local_tt_psi;
    __syncthreads();

    for (int s = nthreads / 2; s > 0; s >>= 1) {
        if (tid < s) {
            s_data1[tid] += s_data1[tid + s];
            s_data2[tid] += s_data2[tid + s];
            s_data3[tid] += s_data3[tid + s];
            s_data4[tid] += s_data4[tid + s];
        }
        __syncthreads();
    }

    double tt_lg_sum = s_data1[0];
    double full_lg_sum = s_data2[0];
    double abel_lg_sum = s_data3[0];
    double tt_psi_sum = s_data4[0];

    // Second reduction for full_psi and abel_psi
    s_data1[tid] = local_full_psi;
    s_data2[tid] = local_abel_psi;
    s_data3[tid] = (double)local_n_tt;
    __syncthreads();

    for (int s = nthreads / 2; s > 0; s >>= 1) {
        if (tid < s) {
            s_data1[tid] += s_data1[tid + s];
            s_data2[tid] += s_data2[tid + s];
            s_data3[tid] += s_data3[tid + s];
        }
        __syncthreads();
    }

    double full_psi_sum = s_data1[0];
    double abel_psi_sum = s_data2[0];
    int n_tt = (int)s_data3[0];

    // Telescope RHS: (a/b)·full + abel - f(b-1)
    double fb_lg = lgamma(1.0);  // lgamma(b/b) = lgamma(1) = 0
    double fb_psi = digamma_device(1.0);  // ψ(1) = -γ

    if (tid == 0) {
        double rhs_lg = (af / bf) * full_lg_sum + abel_lg_sum - fb_lg;
        double rhs_psi = (af / bf) * full_psi_sum + abel_psi_sum - fb_psi;

        d_results[pair_idx].telescope_lg_err = fabs(tt_lg_sum - rhs_lg);
        d_results[pair_idx].telescope_psi_err = fabs(tt_psi_sum - rhs_psi);
        d_results[pair_idx].n_two_tile = n_tt;
    }

    // ═══ BETA MODULO DUALITY (Gemini Key 2) ═══
    // LHS: Σ_{TT} ((s-a)/(a²b))·ψ(β)
    // RHS: -(1/(ab))·Σ_{r=1}^{a-1} {br/a}·ψ(r/a)

    double local_beta_lhs = 0.0;
    int local_beta_pw = 1;

    for (int m0 = 1 + tid; m0 < b; m0 += nthreads) {
        int n0 = (a * m0) / b;
        if (b * (n0 + 1) < a * (m0 + 1)) {
            int s = a * (m0 + 1) - b * (n0 + 1);
            double coeff_lhs = ((double)s - af) / (af * af * bf);
            double beta = ((double)(n0 + 1)) / af;
            local_beta_lhs += coeff_lhs * digamma_device(beta);

            // Verify pointwise: (s-a)/(a²b) = -(1/(ab))·{b(n0+1)/a}
            double frac_val = frac_part(bf * (double)(n0 + 1) / af);
            double coeff_rhs = -(1.0 / (af * bf)) * frac_val;
            if (fabs(coeff_lhs - coeff_rhs) > 1e-10) local_beta_pw = 0;
        }
    }

    double local_beta_rhs = 0.0;
    for (int r = 1 + tid; r < a; r += nthreads) {
        double frac_val = frac_part(bf * (double)r / af);
        double psi_val = digamma_device((double)r / af);
        local_beta_rhs += frac_val * psi_val;
    }

    s_data1[tid] = local_beta_lhs;
    s_data2[tid] = local_beta_rhs;
    s_data3[tid] = (double)local_beta_pw;
    __syncthreads();

    for (int s = nthreads / 2; s > 0; s >>= 1) {
        if (tid < s) {
            s_data1[tid] += s_data1[tid + s];
            s_data2[tid] += s_data2[tid + s];
            s_data3[tid] = fmin(s_data3[tid], s_data3[tid + s]);
        }
        __syncthreads();
    }

    if (tid == 0) {
        double beta_lhs = s_data1[0];
        double beta_rhs = -(1.0 / (af * bf)) * s_data2[0];
        d_results[pair_idx].beta_duality_pw = (int)s_data3[0];
        d_results[pair_idx].beta_duality_sum_err = fabs(beta_lhs - beta_rhs);
    }

    // ═══ GRADUATION IDENTITY ═══
    // Σ perClassLimit vs deltaTarget

    // Compute Σ perClassLimit
    double local_pcl = 0.0;
    for (int m0 = 1 + tid; m0 < b; m0 += nthreads) {
        int n0 = (a * m0) / b;
        if (b * (n0 + 1) < a * (m0 + 1)) {
            int s_val = a * (m0 + 1) - b * (n0 + 1);
            double alpha = ((double)(m0 + 1)) / bf;
            double beta = ((double)(n0 + 1)) / af;
            double lg_beta = lgamma(beta);
            double lg_alpha = lgamma(alpha);
            double psi_beta = digamma_device(beta);
            double psi_alpha = digamma_device(alpha);

            double pcl = -(1.0 / af) * (lg_beta - lg_alpha)
                         - (((double)s_val - af) / (af * af * bf)) * psi_beta
                         - (1.0 / (af * bf)) * psi_alpha;
            local_pcl += pcl;
        }
    }

    // Compute deltaTarget = formula - strip - stir/b - ft/a
    // formula = vasyuninGramFormula (needs cotangent sums)
    double local_vab = 0.0;  // V(a,b) = Σ {mr·a/b}·cot(πm/b)
    double local_vba = 0.0;  // V(b,a) = Σ {mr·b/a}·cot(πm/a)

    for (int m = 1 + tid; m < b; m += nthreads) {
        double frac_val = frac_part(af * (double)m / bf);
        local_vab += frac_val * cot_device(M_PI * (double)m / bf);
    }
    for (int m = 1 + tid; m < a; m += nthreads) {
        double frac_val = frac_part(bf * (double)m / af);
        local_vba += frac_val * cot_device(M_PI * (double)m / af);
    }

    // Compute fractTarget
    double local_ft = 0.0;
    for (int r = 1 + tid; r < b; r += nthreads) {
        double frac_val = frac_part(af * (double)r / bf);
        double lg_r = lgamma((double)r / bf);
        double lg_rp1 = lgamma(((double)(r + 1)) / bf);
        double psi_rp1 = digamma_device(((double)(r + 1)) / bf);
        local_ft += frac_val * (lg_r - lg_rp1 + (1.0 / bf) * psi_rp1);
    }

    s_data1[tid] = local_pcl;
    s_data2[tid] = local_vab;
    s_data3[tid] = local_vba;
    s_data4[tid] = local_ft;
    __syncthreads();

    for (int s = nthreads / 2; s > 0; s >>= 1) {
        if (tid < s) {
            s_data1[tid] += s_data1[tid + s];
            s_data2[tid] += s_data2[tid + s];
            s_data3[tid] += s_data3[tid + s];
            s_data4[tid] += s_data4[tid + s];
        }
        __syncthreads();
    }

    if (tid == 0) {
        double sum_pcl_val = s_data1[0];
        double vab = s_data2[0];
        double vba = s_data3[0];
        double ft = s_data4[0];

        double gamma_const = 0.57721566490153286;
        double log_2pi = log(2.0 * M_PI);

        // vasyuninGramFormula
        double formula = (log_2pi - gamma_const) / 2.0 * (1.0/af + 1.0/bf)
            + (af - bf) / (2.0*af*bf) * log(bf / af)
            - M_PI / (2.0*af*bf) * (vab + vba)
            - 1.0 / (af*bf);

        double strip = (af - 1.0) / (af * bf);
        double stir = (1.0 / bf) * (log_2pi - gamma_const - 1.0);
        double ft_over_a = ft / af;

        double dt = formula - strip - stir - ft_over_a;

        d_results[pair_idx].a = a;
        d_results[pair_idx].b = b;
        d_results[pair_idx].sum_pcl = sum_pcl_val;
        d_results[pair_idx].delta_target = dt;
        d_results[pair_idx].identity_err = fabs(sum_pcl_val - dt);
        d_results[pair_idx].beta_bijection = (n_tt == a - 1) ? 1 : 0;

        // Certified if all errors < 1e-8 (f64 precision)
        d_results[pair_idx].certified =
            (d_results[pair_idx].telescope_lg_err < 1e-8) &&
            (d_results[pair_idx].telescope_psi_err < 1e-8) &&
            (d_results[pair_idx].beta_duality_pw) &&
            (d_results[pair_idx].beta_duality_sum_err < 1e-8) &&
            (d_results[pair_idx].identity_err < 1e-8) ? 1 : 0;
    }
}

// ────────────────────────────────────────────────
// HOST-CALLABLE WRAPPER
// ────────────────────────────────────────────────

extern "C"
void launch_skeleton_keys(
    const int* h_pairs,
    PairResult* h_results,
    int n_pairs,
    int max_b
) {
    int* d_pairs;
    PairResult* d_results;

    cudaMalloc(&d_pairs, n_pairs * 2 * sizeof(int));
    cudaMalloc(&d_results, n_pairs * sizeof(PairResult));
    cudaMemcpy(d_pairs, h_pairs, n_pairs * 2 * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemset(d_results, 0, n_pairs * sizeof(PairResult));

    // Thread count: power of 2, max 256, adapted to max_b
    int threads = 128;
    if (max_b > 256) threads = 256;
    if (max_b < 64) threads = 64;

    // Shared memory: 4 arrays of doubles
    int smem = 4 * threads * sizeof(double);

    printf("  GPU launch: %d pairs, %d threads/block, %d KB smem\n",
           n_pairs, threads, smem / 1024);

    certify_skeleton_keys<<<n_pairs, threads, smem>>>(
        d_pairs, d_results, n_pairs
    );
    cudaDeviceSynchronize();

    cudaMemcpy(h_results, d_results, n_pairs * sizeof(PairResult), cudaMemcpyDeviceToHost);

    cudaFree(d_pairs);
    cudaFree(d_results);
}
