/*
 * dd_cholesky.cu — GPU Double-Double Cholesky Decomposition
 *
 * Implements column-by-column Cholesky with DD (double-double) arithmetic
 * on GPU. Each DD number = (hi: f64, lo: f64) giving ~31 decimal digits.
 *
 * The off-diagonal elements in each column are embarrassingly parallel:
 * for column j, elements L[i,j] for i > j are independent.
 * We launch (dim-j-1) threads per column.
 *
 * Build: nvcc -arch=sm_89 -O3 -shared -o libddcholesky.so dd_cholesky.cu
 */

#include <stdio.h>
#include <math.h>

/* ═══════════════════════════════════════════════════════
   DD arithmetic: error-free transformations on f64
   Reference: Hida/Li/Bailey 2001
   ═══════════════════════════════════════════════════════ */

// Two-sum: a + b = s + e exactly
__device__ __forceinline__
void two_sum(double a, double b, double &s, double &e) {
    s = a + b;
    double v = s - a;
    e = (a - (s - v)) + (b - v);
}

// Two-prod: a * b = p + e exactly (uses FMA)
__device__ __forceinline__
void two_prod(double a, double b, double &p, double &e) {
    p = a * b;
    e = fma(a, b, -p);
}

// DD + DD → DD
__device__ __forceinline__
void dd_add(double ah, double al, double bh, double bl,
            double &rh, double &rl) {
    double s, e;
    two_sum(ah, bh, s, e);
    e += al + bl;
    two_sum(s, e, rh, rl);
}

// DD - DD → DD
__device__ __forceinline__
void dd_sub(double ah, double al, double bh, double bl,
            double &rh, double &rl) {
    dd_add(ah, al, -bh, -bl, rh, rl);
}

// DD * DD → DD
__device__ __forceinline__
void dd_mul(double ah, double al, double bh, double bl,
            double &rh, double &rl) {
    double p, e;
    two_prod(ah, bh, p, e);
    e += ah * bl + al * bh;
    two_sum(p, e, rh, rl);
}

// DD / DD → DD (Newton iteration)
__device__ __forceinline__
void dd_div(double ah, double al, double bh, double bl,
            double &rh, double &rl) {
    double q1 = ah / bh;
    // r = a - b * q1
    double rhi, rlo;
    dd_mul(bh, bl, q1, 0.0, rhi, rlo);
    dd_sub(ah, al, rhi, rlo, rhi, rlo);
    double q2 = rhi / bh;
    two_sum(q1, q2, rh, rl);
}

// DD sqrt via Newton: x = sqrt(a), x_{n+1} = (x_n + a/x_n)/2
__device__ __forceinline__
void dd_sqrt(double ah, double al, double &rh, double &rl) {
    if (ah <= 0.0) { rh = 0.0; rl = 0.0; return; }
    double x = sqrt(ah);
    // One Newton step in DD
    double qh, ql;
    dd_div(ah, al, x, 0.0, qh, ql);
    dd_add(x, 0.0, qh, ql, rh, rl);
    rh *= 0.5; rl *= 0.5;
    // Second Newton step
    dd_div(ah, al, rh, rl, qh, ql);
    dd_add(rh, rl, qh, ql, rh, rl);
    rh *= 0.5; rl *= 0.5;
}

/* ═══════════════════════════════════════════════════════
   GPU Kernels for Cholesky
   ═══════════════════════════════════════════════════════ */

// Kernel: compute off-diagonal elements L[i,j] for all i > j (one column)
// Each thread handles one row i.
__global__
void cholesky_column_kernel(
    const double* __restrict__ gram_hi,   // Gram matrix hi part
    const double* __restrict__ gram_lo,   // Gram matrix lo part
    double* __restrict__ l_hi,            // L matrix hi part (in/out)
    double* __restrict__ l_lo,            // L matrix lo part (in/out)
    double diag_inv_hi, double diag_inv_lo, // 1/L[j,j]
    int j, int dim)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x + j + 1;
    if (i >= dim) return;

    // sum = G[i,j]
    int idx = i * dim + j;
    double sh = gram_hi[idx];
    double sl = gram_lo[idx];

    // sum -= Σ_{k=0}^{j-1} L[i,k] * L[j,k]
    for (int k = 0; k < j; k++) {
        double lik_h = l_hi[i * dim + k];
        double lik_l = l_lo[i * dim + k];
        double ljk_h = l_hi[j * dim + k];
        double ljk_l = l_lo[j * dim + k];

        double ph, pl;
        dd_mul(lik_h, lik_l, ljk_h, ljk_l, ph, pl);
        dd_sub(sh, sl, ph, pl, sh, sl);
    }

    // L[i,j] = sum / L[j,j]  (multiply by precomputed inverse)
    double rh, rl;
    dd_mul(sh, sl, diag_inv_hi, diag_inv_lo, rh, rl);

    l_hi[idx] = rh;
    l_lo[idx] = rl;
}

// Kernel: compute diagonal L[j,j] = sqrt(G[j,j] - Σ L[j,k]²)
__global__
void cholesky_diagonal_kernel(
    const double* __restrict__ gram_hi,
    const double* __restrict__ gram_lo,
    double* __restrict__ l_hi,
    double* __restrict__ l_lo,
    double* __restrict__ diag_out_hi,  // output: L[j,j].hi
    double* __restrict__ diag_out_lo,  // output: L[j,j].lo
    double* __restrict__ diag_inv_hi,  // output: 1/L[j,j].hi
    double* __restrict__ diag_inv_lo,  // output: 1/L[j,j].lo
    int* __restrict__ status,          // output: 0=ok, 1=fail
    int j, int dim)
{
    // Single thread kernel
    int idx = j * dim + j;
    double sh = gram_hi[idx];
    double sl = gram_lo[idx];

    for (int k = 0; k < j; k++) {
        double ljk_h = l_hi[j * dim + k];
        double ljk_l = l_lo[j * dim + k];
        double ph, pl;
        dd_mul(ljk_h, ljk_l, ljk_h, ljk_l, ph, pl);
        dd_sub(sh, sl, ph, pl, sh, sl);
    }

    if (sh <= 0.0) {
        *status = j + 1;  // failed at column j
        *diag_out_hi = sh;
        *diag_out_lo = sl;
        return;
    }

    double dh, dl;
    dd_sqrt(sh, sl, dh, dl);
    l_hi[idx] = dh;
    l_lo[idx] = dl;
    *diag_out_hi = dh;
    *diag_out_lo = dl;

    // Compute 1/L[j,j]
    dd_div(1.0, 0.0, dh, dl, *diag_inv_hi, *diag_inv_lo);
}

// Kernel: forward solve L y = b (sequential, single thread)
__global__
void forward_solve_kernel(
    const double* __restrict__ l_hi,
    const double* __restrict__ l_lo,
    const double* __restrict__ b,
    double* __restrict__ y_hi,
    double* __restrict__ y_lo,
    int dim)
{
    for (int i = 0; i < dim; i++) {
        double sh = b[i];
        double sl = 0.0;
        for (int k = 0; k < i; k++) {
            double ph, pl;
            dd_mul(l_hi[i * dim + k], l_lo[i * dim + k],
                   y_hi[k], y_lo[k], ph, pl);
            dd_sub(sh, sl, ph, pl, sh, sl);
        }
        dd_div(sh, sl, l_hi[i * dim + i], l_lo[i * dim + i],
               y_hi[i], y_lo[i]);
    }
}

// Kernel: backward solve L^T c = y (sequential, single thread)
__global__
void backward_solve_kernel(
    const double* __restrict__ l_hi,
    const double* __restrict__ l_lo,
    const double* __restrict__ y_hi,
    const double* __restrict__ y_lo,
    double* __restrict__ c_hi,
    double* __restrict__ c_lo,
    int dim)
{
    for (int i = dim - 1; i >= 0; i--) {
        double sh = y_hi[i];
        double sl = y_lo[i];
        for (int k = i + 1; k < dim; k++) {
            double ph, pl;
            dd_mul(l_hi[k * dim + i], l_lo[k * dim + i],
                   c_hi[k], c_lo[k], ph, pl);
            dd_sub(sh, sl, ph, pl, sh, sl);
        }
        dd_div(sh, sl, l_hi[i * dim + i], l_lo[i * dim + i],
               c_hi[i], c_lo[i]);
    }
}

// Kernel: compute d² = 1 - b·c (single thread)
__global__
void dot_product_kernel(
    const double* __restrict__ b,
    const double* __restrict__ c_hi,
    const double* __restrict__ c_lo,
    double* __restrict__ d2_hi,
    double* __restrict__ d2_lo,
    int dim)
{
    double bc_h = 0.0, bc_l = 0.0;
    for (int i = 0; i < dim; i++) {
        double ph, pl;
        dd_mul(b[i], 0.0, c_hi[i], c_lo[i], ph, pl);
        dd_add(bc_h, bc_l, ph, pl, bc_h, bc_l);
    }
    dd_sub(1.0, 0.0, bc_h, bc_l, *d2_hi, *d2_lo);
}

/* ═══════════════════════════════════════════════════════
   Host-callable C API
   ═══════════════════════════════════════════════════════ */

extern "C" {

// Full GPU DD Cholesky: d² = 1 - b^T G^{-1} b
// Returns d² as f64. Sets *fail_col if Cholesky fails (0 = success).
double gpu_dd_cholesky_d2(
    const double* gram_hi_host,
    const double* gram_lo_host,
    const double* b_host,
    int dim,
    int* fail_col)
{
    size_t mat_bytes = (size_t)dim * dim * sizeof(double);
    size_t vec_bytes = (size_t)dim * sizeof(double);

    // Allocate device memory
    double *d_gram_hi, *d_gram_lo, *d_l_hi, *d_l_lo;
    double *d_b, *d_y_hi, *d_y_lo, *d_c_hi, *d_c_lo;
    double *d_diag_hi, *d_diag_lo, *d_inv_hi, *d_inv_lo;
    double *d_d2_hi, *d_d2_lo;
    int *d_status;

    cudaMalloc(&d_gram_hi, mat_bytes);
    cudaMalloc(&d_gram_lo, mat_bytes);
    cudaMalloc(&d_l_hi, mat_bytes);
    cudaMalloc(&d_l_lo, mat_bytes);
    cudaMalloc(&d_b, vec_bytes);
    cudaMalloc(&d_y_hi, vec_bytes);
    cudaMalloc(&d_y_lo, vec_bytes);
    cudaMalloc(&d_c_hi, vec_bytes);
    cudaMalloc(&d_c_lo, vec_bytes);
    cudaMalloc(&d_diag_hi, sizeof(double));
    cudaMalloc(&d_diag_lo, sizeof(double));
    cudaMalloc(&d_inv_hi, sizeof(double));
    cudaMalloc(&d_inv_lo, sizeof(double));
    cudaMalloc(&d_d2_hi, sizeof(double));
    cudaMalloc(&d_d2_lo, sizeof(double));
    cudaMalloc(&d_status, sizeof(int));

    // Copy input to device
    cudaMemcpy(d_gram_hi, gram_hi_host, mat_bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_gram_lo, gram_lo_host, mat_bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, b_host, vec_bytes, cudaMemcpyHostToDevice);
    cudaMemset(d_l_hi, 0, mat_bytes);
    cudaMemset(d_l_lo, 0, mat_bytes);
    cudaMemset(d_status, 0, sizeof(int));

    *fail_col = 0;

    // Column-by-column Cholesky
    for (int j = 0; j < dim; j++) {
        // 1. Compute diagonal L[j,j] (single thread)
        cholesky_diagonal_kernel<<<1, 1>>>(
            d_gram_hi, d_gram_lo, d_l_hi, d_l_lo,
            d_diag_hi, d_diag_lo, d_inv_hi, d_inv_lo,
            d_status, j, dim);

        // Check status
        int h_status = 0;
        cudaMemcpy(&h_status, d_status, sizeof(int), cudaMemcpyDeviceToHost);
        if (h_status != 0) {
            *fail_col = h_status;
            // Cleanup
            cudaFree(d_gram_hi); cudaFree(d_gram_lo);
            cudaFree(d_l_hi); cudaFree(d_l_lo);
            cudaFree(d_b); cudaFree(d_y_hi); cudaFree(d_y_lo);
            cudaFree(d_c_hi); cudaFree(d_c_lo);
            cudaFree(d_diag_hi); cudaFree(d_diag_lo);
            cudaFree(d_inv_hi); cudaFree(d_inv_lo);
            cudaFree(d_d2_hi); cudaFree(d_d2_lo);
            cudaFree(d_status);
            return NAN;
        }

        // 2. Compute off-diagonal L[i,j] for i > j (parallel!)
        int remaining = dim - j - 1;
        if (remaining > 0) {
            double h_inv_hi, h_inv_lo;
            cudaMemcpy(&h_inv_hi, d_inv_hi, sizeof(double), cudaMemcpyDeviceToHost);
            cudaMemcpy(&h_inv_lo, d_inv_lo, sizeof(double), cudaMemcpyDeviceToHost);

            int threads = 256;
            int blocks = (remaining + threads - 1) / threads;
            cholesky_column_kernel<<<blocks, threads>>>(
                d_gram_hi, d_gram_lo, d_l_hi, d_l_lo,
                h_inv_hi, h_inv_lo, j, dim);
        }
    }

    cudaDeviceSynchronize();

    // Forward solve: L y = b
    forward_solve_kernel<<<1, 1>>>(d_l_hi, d_l_lo, d_b, d_y_hi, d_y_lo, dim);

    // Backward solve: L^T c = y
    backward_solve_kernel<<<1, 1>>>(d_l_hi, d_l_lo, d_y_hi, d_y_lo,
                                     d_c_hi, d_c_lo, dim);

    // d² = 1 - b·c
    dot_product_kernel<<<1, 1>>>(d_b, d_c_hi, d_c_lo, d_d2_hi, d_d2_lo, dim);

    cudaDeviceSynchronize();

    double h_d2_hi, h_d2_lo;
    cudaMemcpy(&h_d2_hi, d_d2_hi, sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(&h_d2_lo, d_d2_lo, sizeof(double), cudaMemcpyDeviceToHost);

    // Cleanup
    cudaFree(d_gram_hi); cudaFree(d_gram_lo);
    cudaFree(d_l_hi); cudaFree(d_l_lo);
    cudaFree(d_b); cudaFree(d_y_hi); cudaFree(d_y_lo);
    cudaFree(d_c_hi); cudaFree(d_c_lo);
    cudaFree(d_diag_hi); cudaFree(d_diag_lo);
    cudaFree(d_inv_hi); cudaFree(d_inv_lo);
    cudaFree(d_d2_hi); cudaFree(d_d2_lo);
    cudaFree(d_status);

    return h_d2_hi;
}

}  // extern "C"
