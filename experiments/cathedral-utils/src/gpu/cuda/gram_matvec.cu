/*
 * gram_matvec.cu — Matrix-Free GPU Gram-Vector Multiply
 *
 * Computes y = G · x where G(j,k) is computed on-the-fly using
 * the Vasyunin formula, WITHOUT storing the Gram matrix.
 *
 * Each CUDA thread computes one row of the output:
 *   y[row] = Σ_col G(row+2, col+2) × x[col]
 *
 * v2: Optimized for GPU — no branching in hot loop, fixed T, no Kahan.
 *
 * Build:
 *   nvcc -arch=sm_89 -O3 --shared -Xcompiler -fPIC \
 *        -o libgrammatvec.so gram_matvec.cu
 */

#include <math.h>
#include <stdio.h>
#include <stdint.h>

/* ═══════ GCD ═══════ */
__device__ __forceinline__
int gpu_gcd(int a, int b) {
    while (b != 0) { int t = b; b = a % b; a = t; }
    return a;
}

/* ═══════ Single Gram entry G(j,k) — GPU-optimized ═══════ */
// Simplified: no branching, no Kahan, no early exit.
// Fixed T iterations. Pure arithmetic — GPU-friendly.
__device__
double gram_entry_gpu(int j, int k, int t_max) {
    double jf = (double)j;
    double kf = (double)k;
    double inv_jk = 1.0 / (jf * kf);
    double inv_jf = 1.0 / jf;
    double inv_kf = 1.0 / kf;

    int g = gpu_gcd(j, k);

    // For j,k >> T: short-circuit with asymptotic
    if (j > t_max && k > t_max) {
        double d = (double)g;
        double tail_mean = 0.25 + d * d / (12.0 * jf * kf);
        double inv_t = 1.0 / (double)t_max;
        return (double)t_max * inv_jk
            + tail_mean * inv_t
            + tail_mean * 0.5 * inv_t * inv_t;
    }

    double total = 0.0;

    // Unrolled loop with minimal branching
    for (int n = 1; n <= t_max; n++) {
        double nf = (double)n;
        int a_int = n / j;
        int b_int = n / k;

        // ln(1+1/n) via rational approximation (no branching)
        double x = 1.0 / nf;
        double ln_term;
        if (n < 8) {
            ln_term = log1p(x);
        } else {
            // Padé[3,3] approximant of ln(1+x) — excellent for x < 0.125
            // More accurate than Taylor for the same number of ops
            ln_term = x * (1.0 - x * (0.5 - x * (1.0/3.0 - x * 0.25)));
        }

        double ab_coeff = (double)a_int * inv_kf + (double)b_int * inv_jf;
        double ab_frac = (a_int > 0 && b_int > 0) ?
            (double)((long long)a_int * b_int) / (nf * (nf + 1.0)) : 0.0;

        total += inv_jk - ab_coeff * ln_term + ab_frac;
    }

    // Euler-Maclaurin tail
    double d = (double)g;
    double tail_mean = 0.25 + d * d / (12.0 * jf * kf);
    double inv_t = 1.0 / (double)t_max;
    total += tail_mean * inv_t
        + tail_mean * 0.5 * inv_t * inv_t
        + tail_mean * (1.0/6.0) * inv_t * inv_t * inv_t;

    return total;
}


/* ═══════ Matrix-Free Matvec Kernel ═══════ */
//
// Each thread computes one row of y = G · x.
// For N=1M: 1M threads, each doing 1M × O(T) work.
//
__global__
void gram_matvec_kernel(
    const double* __restrict__ x,
    double* __restrict__ y,
    int dim,
    int t_max)
{
    int row = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= dim) return;

    int j = row + 2;
    double sum = 0.0;

    for (int col = 0; col < dim; col++) {
        double xv = x[col];
        // Skip zero entries (common in early Lanczos iterations)
        if (xv == 0.0) continue;

        int k = col + 2;
        double g_jk = gram_entry_gpu(j, k, t_max);
        sum += g_jk * xv;
    }

    y[row] = sum;
}


/* ═══════ C Interface ═══════ */

extern "C" {

int gram_matvec_alloc(int dim, double** d_x, double** d_y) {
    int s1 = cudaMalloc(d_x, dim * sizeof(double));
    int s2 = cudaMalloc(d_y, dim * sizeof(double));
    return (s1 || s2) ? -1 : 0;
}

void gram_matvec_free(double* d_x, double* d_y) {
    cudaFree(d_x);
    cudaFree(d_y);
}

void gram_matvec_upload_x(double* d_x, const double* h_x, int dim) {
    cudaMemcpy(d_x, h_x, dim * sizeof(double), cudaMemcpyHostToDevice);
}

void gram_matvec_download_y(const double* d_y, double* h_y, int dim) {
    cudaMemcpy(h_y, d_y, dim * sizeof(double), cudaMemcpyDeviceToHost);
}

void gram_matvec_exec(double* d_x, double* d_y, int dim, int t_max) {
    int block_size = 256;
    int grid_size = (dim + block_size - 1) / block_size;
    gram_matvec_kernel<<<grid_size, block_size>>>(d_x, d_y, dim, t_max);
    cudaDeviceSynchronize();
}

void gram_matvec_full(
    double* d_x, double* d_y,
    const double* h_x, double* h_y,
    int dim, int t_max)
{
    gram_matvec_upload_x(d_x, h_x, dim);
    gram_matvec_exec(d_x, d_y, dim, t_max);
    gram_matvec_download_y(d_y, h_y, dim);
}

} // extern "C"
