// ═══════════════════════════════════════════════════════════════════════════
//  SKELETON KEY CUDA KERNELS — Two-Tile Decomposition GPU Certifier
//
//  Full certification matching the CPU experiment's axiom_graduation module.
//  Each coprime pair (a,b) is ONE thread block. Within each block:
//    - Threads cooperatively compute sums over {1..b-1} and twoTileSet
//    - Shared memory used for parallel reduction
//    - logΓ and ψ computed via CUDA device functions
//
//  Certifications per pair:
//    §1. Structural invariants (beta bijection, s permutation, overshoot)
//    §2. Gauss formula verification (logΓ and ψ closed forms)
//    §3. Staircase telescope (Gemini Key 1)
//    §4. Beta modulo duality (Gemini Key 2)
//    §5. Graduation identity (Σ perClassLimit = deltaTarget)
// ═══════════════════════════════════════════════════════════════════════════

#include <math.h>
#include <stdio.h>

// ────────────────────────────────────────────────
// DEVICE HELPER FUNCTIONS
// ────────────────────────────────────────────────

__device__ double frac_part(double x) {
    return x - floor(x);
}

/// Digamma function via asymptotic expansion + recurrence
__device__ double digamma_device(double x) {
    if (x <= 0.0) return nan("");
    double result = 0.0;
    while (x < 10.0) {
        result -= 1.0 / x;
        x += 1.0;
    }
    double inv_x = 1.0 / x;
    double inv_x2 = inv_x * inv_x;
    result += log(x) - 0.5 * inv_x;
    double x2k = inv_x2;
    result -= x2k / 12.0;
    x2k *= inv_x2;
    result += x2k / 120.0;
    x2k *= inv_x2;
    result -= x2k / 252.0;
    x2k *= inv_x2;
    result += x2k / 240.0;
    x2k *= inv_x2;
    result -= x2k * 5.0 / 660.0;
    x2k *= inv_x2;
    result += x2k * 691.0 / 32760.0 / 6.0;
    return result;
}

__device__ double cot_device(double x) {
    return cos(x) / sin(x);
}

// ────────────────────────────────────────────────
// PAIR RESULT — matches Rust PairResult exactly
// ────────────────────────────────────────────────

struct PairResult {
    int a, b;
    int n_two_tile;

    // Structural
    int beta_bijection;
    int s_permutation;
    int overshoot_identity;

    // Gauss
    double gauss_loggamma_a_err;
    double gauss_loggamma_b_err;
    double gauss_digamma_a_err;
    double gauss_digamma_b_err;

    // Telescope
    double telescope_lg_err;
    double telescope_psi_err;

    // Beta duality
    int beta_duality_pw;
    double beta_duality_sum_err;

    // Graduation
    double sum_pcl;
    double delta_target;
    double identity_err;

    int certified;
};

// ────────────────────────────────────────────────
// MAIN KERNEL: One block per coprime pair
// ────────────────────────────────────────────────

extern "C"
__global__ void certify_skeleton_keys(
    const int* d_pairs,
    PairResult* d_results,
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

    // 8 shared arrays for reductions
    extern __shared__ double shared[];
    double* s1 = shared;
    double* s2 = shared + nthreads;
    double* s3 = shared + 2*nthreads;
    double* s4 = shared + 3*nthreads;
    double* s5 = shared + 4*nthreads;
    double* s6 = shared + 5*nthreads;
    double* s7 = shared + 6*nthreads;
    double* s8 = shared + 7*nthreads;

    // ═══ §1. STRUCTURAL + §3. TELESCOPE + §4. BETA DUALITY + §5. PCL ═══
    // Compute everything over TT in one pass

    double local_tt_lg = 0.0, local_tt_psi = 0.0;
    double local_pcl = 0.0, local_beta_lhs = 0.0;
    int local_n_tt = 0;
    int local_beta_pw = 1;
    int local_overshoot_ok = 1;

    // Scratch arrays for structural checks (use atomicAdd)
    // We'll verify bijection and permutation via checksum+count
    double local_beta_sum = 0.0;  // sum of tile indices
    double local_s_sum = 0.0;     // sum of overshoot values

    for (int m0 = 1 + tid; m0 < b; m0 += nthreads) {
        int n0 = (a * m0) / b;
        if (b * (n0 + 1) < a * (m0 + 1)) {
            // This m0 is two-tile
            local_n_tt++;
            int s_val = a * (m0 + 1) - b * (n0 + 1);

            // Structural: accumulate for bijection/permutation checks
            local_beta_sum += (double)n0;
            local_s_sum += (double)s_val;

            // Overshoot identity: s - a == (am₀ % b) - b
            int r = (a * m0) % b;
            if ((s_val - a) != (r - b)) local_overshoot_ok = 0;

            // Telescope LHS
            double alpha = ((double)(m0 + 1)) / bf;
            local_tt_lg += lgamma(alpha);
            local_tt_psi += digamma_device(alpha);

            // PCL
            double beta_val = ((double)(n0 + 1)) / af;
            double lg_beta = lgamma(beta_val);
            double lg_alpha = lgamma(alpha);
            double psi_beta = digamma_device(beta_val);
            double psi_alpha = digamma_device(alpha);
            local_pcl += -(1.0/af) * (lg_beta - lg_alpha)
                         - (((double)s_val - af) / (af*af*bf)) * psi_beta
                         - (1.0/(af*bf)) * psi_alpha;

            // Beta duality LHS
            double coeff = ((double)s_val - af) / (af*af*bf);
            local_beta_lhs += coeff * psi_beta;

            // Beta duality pointwise
            double fv = frac_part(bf * (double)(n0+1) / af);
            double coeff_rhs = -(1.0/(af*bf)) * fv;
            if (fabs(coeff - coeff_rhs) > 1e-10) local_beta_pw = 0;
        }
    }

    // Full sums for telescope RHS
    double local_full_lg = 0.0, local_full_psi = 0.0;
    double local_abel_lg = 0.0, local_abel_psi = 0.0;

    for (int m = tid; m < b; m += nthreads) {
        double alpha = ((double)(m + 1)) / bf;
        local_full_lg += lgamma(alpha);
        local_full_psi += digamma_device(alpha);
    }

    for (int r = 1 + tid; r < b; r += nthreads) {
        double fv = frac_part(af * (double)r / bf);
        double lg_r = lgamma(((double)(r+1))/bf);
        double lg_rm1 = lgamma(((double)r)/bf);
        double psi_r = digamma_device(((double)(r+1))/bf);
        double psi_rm1 = digamma_device(((double)r)/bf);
        local_abel_lg += fv * (lg_r - lg_rm1);
        local_abel_psi += fv * (psi_r - psi_rm1);
    }

    // Beta duality RHS
    double local_beta_rhs = 0.0;
    for (int r = 1 + tid; r < a; r += nthreads) {
        double fv = frac_part(bf * (double)r / af);
        local_beta_rhs += fv * digamma_device((double)r / af);
    }

    // §2. Gauss formulas
    double local_gauss_lg_a = 0.0, local_gauss_d_a = 0.0;
    double local_gauss_lg_b = 0.0, local_gauss_d_b = 0.0;

    for (int k = 1 + tid; k < a; k += nthreads) {
        local_gauss_lg_a += lgamma((double)k / af);
        local_gauss_d_a += digamma_device((double)k / af);
    }
    for (int k = 1 + tid; k < b; k += nthreads) {
        local_gauss_lg_b += lgamma((double)k / bf);
        local_gauss_d_b += digamma_device((double)k / bf);
    }

    // Cotangent sums for vasyuninGramFormula
    double local_vab = 0.0, local_vba = 0.0;
    for (int m = 1 + tid; m < b; m += nthreads) {
        local_vab += frac_part(af*(double)m/bf) * cot_device(M_PI*(double)m/bf);
    }
    for (int m = 1 + tid; m < a; m += nthreads) {
        local_vba += frac_part(bf*(double)m/af) * cot_device(M_PI*(double)m/af);
    }

    // fractTarget
    double local_ft = 0.0;
    for (int r = 1 + tid; r < b; r += nthreads) {
        double fv = frac_part(af*(double)r/bf);
        double lg_r = lgamma((double)r/bf);
        double lg_rp1 = lgamma(((double)(r+1))/bf);
        double psi_rp1 = digamma_device(((double)(r+1))/bf);
        local_ft += fv * (lg_r - lg_rp1 + (1.0/bf)*psi_rp1);
    }

    // ═══ PARALLEL REDUCTIONS ═══
    // Pass 1: 8 values
    s1[tid] = local_tt_lg;
    s2[tid] = local_full_lg;
    s3[tid] = local_abel_lg;
    s4[tid] = local_tt_psi;
    s5[tid] = local_full_psi;
    s6[tid] = local_abel_psi;
    s7[tid] = (double)local_n_tt;
    s8[tid] = local_pcl;
    __syncthreads();

    for (int s = nthreads/2; s > 0; s >>= 1) {
        if (tid < s) {
            s1[tid] += s1[tid+s];
            s2[tid] += s2[tid+s];
            s3[tid] += s3[tid+s];
            s4[tid] += s4[tid+s];
            s5[tid] += s5[tid+s];
            s6[tid] += s6[tid+s];
            s7[tid] += s7[tid+s];
            s8[tid] += s8[tid+s];
        }
        __syncthreads();
    }

    double tt_lg = s1[0], full_lg = s2[0], abel_lg = s3[0];
    double tt_psi = s4[0], full_psi = s5[0], abel_psi = s6[0];
    int n_tt = (int)s7[0];
    double sum_pcl_val = s8[0];

    // Pass 2: remaining values
    s1[tid] = local_beta_lhs;
    s2[tid] = local_beta_rhs;
    s3[tid] = (double)local_beta_pw;
    s4[tid] = (double)local_overshoot_ok;
    s5[tid] = local_beta_sum;
    s6[tid] = local_s_sum;
    s7[tid] = local_gauss_lg_a;
    s8[tid] = local_gauss_lg_b;
    __syncthreads();

    for (int s = nthreads/2; s > 0; s >>= 1) {
        if (tid < s) {
            s1[tid] += s1[tid+s];
            s2[tid] += s2[tid+s];
            s3[tid] = fmin(s3[tid], s3[tid+s]);
            s4[tid] = fmin(s4[tid], s4[tid+s]);
            s5[tid] += s5[tid+s];
            s6[tid] += s6[tid+s];
            s7[tid] += s7[tid+s];
            s8[tid] += s8[tid+s];
        }
        __syncthreads();
    }

    double beta_lhs_val = s1[0];
    double beta_rhs_sum = s2[0];
    int all_beta_pw = (int)s3[0];
    int all_overshoot = (int)s4[0];
    double beta_sum_total = s5[0];
    double s_sum_total = s6[0];
    double gauss_lg_a_sum = s7[0];
    double gauss_lg_b_sum = s8[0];

    // Pass 3
    s1[tid] = local_gauss_d_a;
    s2[tid] = local_gauss_d_b;
    s3[tid] = local_vab;
    s4[tid] = local_vba;
    s5[tid] = local_ft;
    __syncthreads();

    for (int s = nthreads/2; s > 0; s >>= 1) {
        if (tid < s) {
            s1[tid] += s1[tid+s];
            s2[tid] += s2[tid+s];
            s3[tid] += s3[tid+s];
            s4[tid] += s4[tid+s];
            s5[tid] += s5[tid+s];
        }
        __syncthreads();
    }

    double gauss_d_a_sum = s1[0];
    double gauss_d_b_sum = s2[0];
    double vab = s3[0];
    double vba = s4[0];
    double ft = s5[0];

    // ═══ FINAL COMPUTATION (thread 0) ═══
    if (tid == 0) {
        double gamma_c = 0.57721566490153286;
        double log_2pi = log(2.0 * M_PI);

        // §1. Structural invariants
        // Beta bijection: sum of {0,...,a-2} = (a-1)(a-2)/2, count = a-1
        double expected_beta_sum = (double)(a-1)*(double)(a-2)/2.0;
        int beta_bij = (n_tt == a-1 && fabs(beta_sum_total - expected_beta_sum) < 0.5) ? 1 : 0;

        // S permutation: sum of {1,...,a-1} = a(a-1)/2
        double expected_s_sum = (double)a*(double)(a-1)/2.0;
        int s_perm = (fabs(s_sum_total - expected_s_sum) < 0.5) ? 1 : 0;

        // §2. Gauss formulas
        double gauss_lg_a_closed = (af-1.0)/2.0 * log_2pi - 0.5*log(af);
        double gauss_lg_b_closed = (bf-1.0)/2.0 * log_2pi - 0.5*log(bf);
        double gauss_d_a_closed = -(af-1.0)*gamma_c - af*log(af);
        double gauss_d_b_closed = -(bf-1.0)*gamma_c - bf*log(bf);

        double gl_a_err = fabs(gauss_lg_a_sum - gauss_lg_a_closed);
        double gl_b_err = fabs(gauss_lg_b_sum - gauss_lg_b_closed);
        double gd_a_err = fabs(gauss_d_a_sum - gauss_d_a_closed);
        double gd_b_err = fabs(gauss_d_b_sum - gauss_d_b_closed);

        // §3. Telescope
        double fb_lg = lgamma(1.0);
        double fb_psi = digamma_device(1.0);
        double rhs_lg = (af/bf)*full_lg + abel_lg - fb_lg;
        double rhs_psi = (af/bf)*full_psi + abel_psi - fb_psi;
        double tel_lg = fabs(tt_lg - rhs_lg);
        double tel_psi = fabs(tt_psi - rhs_psi);

        // §4. Beta duality
        double beta_rhs_val = -(1.0/(af*bf)) * beta_rhs_sum;
        double beta_err = fabs(beta_lhs_val - beta_rhs_val);

        // §5. Graduation
        double formula = (log_2pi - gamma_c)/2.0 * (1.0/af + 1.0/bf)
            + (af - bf)/(2.0*af*bf) * log(bf/af)
            - M_PI/(2.0*af*bf) * (vab + vba)
            - 1.0/(af*bf);
        double strip = (af-1.0)/(af*bf);
        double stir = (1.0/bf)*(log_2pi - gamma_c - 1.0);
        double dt = formula - strip - stir - ft/af;
        double id_err = fabs(sum_pcl_val - dt);

        // Write result
        PairResult r;
        r.a = a; r.b = b; r.n_two_tile = n_tt;
        r.beta_bijection = beta_bij;
        r.s_permutation = s_perm;
        r.overshoot_identity = all_overshoot;
        r.gauss_loggamma_a_err = gl_a_err;
        r.gauss_loggamma_b_err = gl_b_err;
        r.gauss_digamma_a_err = gd_a_err;
        r.gauss_digamma_b_err = gd_b_err;
        r.telescope_lg_err = tel_lg;
        r.telescope_psi_err = tel_psi;
        r.beta_duality_pw = all_beta_pw;
        r.beta_duality_sum_err = beta_err;
        r.sum_pcl = sum_pcl_val;
        r.delta_target = dt;
        r.identity_err = id_err;

        r.certified = (beta_bij && s_perm && all_overshoot
            && gl_a_err < 1e-8 && gl_b_err < 1e-8
            && gd_a_err < 1e-8 && gd_b_err < 1e-8
            && tel_lg < 1e-8 && tel_psi < 1e-8
            && all_beta_pw && beta_err < 1e-8
            && id_err < 1e-8) ? 1 : 0;

        d_results[pair_idx] = r;
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

    // 8 shared arrays for reductions
    int smem = 8 * threads * sizeof(double);

    printf("  GPU launch: %d pairs, %d threads/block, %d KB smem\n",
           n_pairs, threads, smem / 1024);

    certify_skeleton_keys<<<n_pairs, threads, smem>>>(
        d_pairs, d_results, n_pairs
    );

    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        printf("  CUDA launch error: %s\n", cudaGetErrorString(err));
    }

    cudaDeviceSynchronize();
    err = cudaGetLastError();
    if (err != cudaSuccess) {
        printf("  CUDA sync error: %s\n", cudaGetErrorString(err));
    }

    cudaMemcpy(h_results, d_results, n_pairs * sizeof(PairResult), cudaMemcpyDeviceToHost);

    cudaFree(d_pairs);
    cudaFree(d_results);
}
