/*
 * qq_cholesky.cu — GPU Quad-Double (f64) Cholesky Decomposition
 *
 * QQ = 4 × f64 → ~62 decimal digits of precision.
 * This is the highest-precision tier in the Cathedral pipeline.
 *
 * Use cases:
 *   - Cross-validation of DD Cholesky results
 *   - Publication-grade certified bounds
 *   - N ≤ 20,000 (due to 4× memory overhead vs DD)
 *
 * Memory: 4 × N² × 8 bytes per matrix = 32N² bytes
 *   N=10000 → 3.2 GB, N=20000 → 12.8 GB
 *
 * Build: nvcc -arch=sm_89 -O3 --shared -Xcompiler -fPIC -o libqqcholesky.so qq_cholesky.cu
 */

#include <stdio.h>
#include <math.h>

/* ═══════════════════════════════════════════════════════════════
   QQ (Quad-Double) arithmetic: 4 × f64 → ~62 decimal digits
   Reference: Hida/Li/Bailey "Library for Double-Double and
   Quad-Double Arithmetic" (2001)
   ═══════════════════════════════════════════════════════════════ */

// Error-free transformations
__device__ __forceinline__
void two_sum(double a, double b, double &s, double &e) {
    s = a + b;
    double v = s - a;
    e = (a - (s - v)) + (b - v);
}

__device__ __forceinline__
void quick_two_sum(double a, double b, double &s, double &e) {
    s = a + b;
    e = b - (s - a);
}

__device__ __forceinline__
void two_prod(double a, double b, double &p, double &e) {
    p = a * b;
    e = fma(a, b, -p);
}

/* ═══════ DD (Double-Double) sub-operations ═══════ */

__device__ __forceinline__
void dd_add(double ah, double al, double bh, double bl,
            double &rh, double &rl) {
    double s, e;
    two_sum(ah, bh, s, e);
    e += al + bl;
    quick_two_sum(s, e, rh, rl);
}

__device__ __forceinline__
void dd_mul(double ah, double al, double bh, double bl,
            double &rh, double &rl) {
    double p, e;
    two_prod(ah, bh, p, e);
    e += ah * bl + al * bh;
    quick_two_sum(p, e, rh, rl);
}

/* ═══════ QQ (Quad-Double) type ═══════ */

struct QQ {
    double x[4];  // x[0] is most significant
};

__device__
QQ qq_make(double v) {
    QQ r; r.x[0] = v; r.x[1] = 0.0; r.x[2] = 0.0; r.x[3] = 0.0;
    return r;
}

__device__ __host__
QQ qq_from_dd(double hi, double lo) {
    QQ r;
    r.x[0] = hi; r.x[1] = lo; r.x[2] = 0.0; r.x[3] = 0.0;
    return r;
}

__device__
double qq_to_double(QQ q) {
    return q.x[0] + q.x[1] + q.x[2] + q.x[3];
}

// Renormalize: ensure |x[i+1]| ≤ ulp(x[i])/2
__device__
QQ qq_renorm(double c0, double c1, double c2, double c3, double c4) {
    double s0, s1, s2, s3;
    double t0, t1, t2, t3;

    quick_two_sum(c3, c4, s0, t3);
    quick_two_sum(c2, s0, s0, t2);
    quick_two_sum(c1, s0, s0, t1);
    quick_two_sum(c0, s0, c0, t0);
    s0 = t0;

    quick_two_sum(s0, t1, s0, s1);
    quick_two_sum(s0, t2, s0, s2);
    quick_two_sum(s0, t3, s0, s3);

    quick_two_sum(c0, s0, c0, c1);
    quick_two_sum(c1, s1, c1, c2);
    quick_two_sum(c2, s2, c2, c3);
    c3 += s3;

    QQ r; r.x[0] = c0; r.x[1] = c1; r.x[2] = c2; r.x[3] = c3;
    return r;
}

// QQ + QQ → QQ
__device__
QQ qq_add(QQ a, QQ b) {
    // IEEE add with error tracking across 4 components
    double s0, s1, s2, s3;
    double t0, t1, t2, t3;

    two_sum(a.x[0], b.x[0], s0, t0);
    two_sum(a.x[1], b.x[1], s1, t1);
    two_sum(a.x[2], b.x[2], s2, t2);
    two_sum(a.x[3], b.x[3], s3, t3);

    // Cascade carries
    two_sum(s1, t0, s1, t0);
    two_sum(s2, t0, s2, t0);
    two_sum(s2, t1, s2, t1);

    double e;
    two_sum(s3, t0, s3, e); t0 = e;
    two_sum(s3, t1, s3, e); t1 = e;
    two_sum(s3, t2, s3, e); t2 = e;

    double c4 = t0 + t1 + t2 + t3;

    return qq_renorm(s0, s1, s2, s3, c4);
}

__device__ __forceinline__
QQ qq_neg(QQ a) {
    QQ r; r.x[0] = -a.x[0]; r.x[1] = -a.x[1];
    r.x[2] = -a.x[2]; r.x[3] = -a.x[3];
    return r;
}

__device__ __forceinline__
QQ qq_sub(QQ a, QQ b) { return qq_add(a, qq_neg(b)); }

// QQ × QQ → QQ (sloppy multiplication — keeps ~62 digit accuracy)
__device__
QQ qq_mul(QQ a, QQ b) {
    double p0h, p0l, p1h, p1l, p2h, p2l, p3h, p3l;
    double p4h, p4l, p5h, p5l, p6h, p6l;

    // Level 0: O(1)
    two_prod(a.x[0], b.x[0], p0h, p0l);

    // Level 1: O(eps)
    two_prod(a.x[0], b.x[1], p1h, p1l);
    two_prod(a.x[1], b.x[0], p2h, p2l);

    // Level 2: O(eps²)
    two_prod(a.x[0], b.x[2], p3h, p3l);
    two_prod(a.x[1], b.x[1], p4h, p4l);
    two_prod(a.x[2], b.x[0], p5h, p5l);

    // Level 3: O(eps³) — accumulate as doubles
    double q0 = a.x[0] * b.x[3] + a.x[1] * b.x[2]
              + a.x[2] * b.x[1] + a.x[3] * b.x[0];

    // Accumulate
    double s0 = p0h;
    double s1, e1;
    two_sum(p1h, p2h, s1, e1);
    two_sum(s1, p0l, s1, e1);

    double s2, e2;
    two_sum(p3h, p4h, s2, e2);
    two_sum(s2, p5h, s2, e2);
    s2 += p1l + p2l + e1;

    double s3 = q0 + p3l + p4l + p5l + e2;

    return qq_renorm(s0, s1, s2, s3, 0.0);
}

// QQ / QQ via iterative refinement
__device__
QQ qq_div(QQ a, QQ b) {
    double q0 = a.x[0] / b.x[0];
    QQ r = qq_sub(a, qq_mul(b, qq_make(q0)));

    double q1 = r.x[0] / b.x[0];
    r = qq_sub(r, qq_mul(b, qq_make(q1)));

    double q2 = r.x[0] / b.x[0];
    r = qq_sub(r, qq_mul(b, qq_make(q2)));

    double q3 = r.x[0] / b.x[0];

    return qq_renorm(q0, q1, q2, q3, 0.0);
}

// QQ sqrt via Newton iteration (4 iterations for full precision)
__device__
QQ qq_sqrt(QQ a) {
    if (a.x[0] <= 0.0) return qq_make(0.0);
    QQ x = qq_make(sqrt(a.x[0]));
    QQ half = qq_make(0.5);
    // Newton: x = (x + a/x) / 2
    for (int i = 0; i < 4; i++)
        x = qq_mul(qq_add(x, qq_div(a, x)), half);
    return x;
}

__device__ __forceinline__
bool qq_le_zero(QQ a) {
    return a.x[0] < 0.0 || (a.x[0] == 0.0 && a.x[1] <= 0.0);
}

/* ═══════════════════════════════════════════════════════════════
   Cholesky Kernels
   ═══════════════════════════════════════════════════════════════ */

__global__
void qq_cholesky_column(
    const QQ* __restrict__ gram, QQ* __restrict__ L,
    QQ inv, int j, int dim)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x + j + 1;
    if (i >= dim) return;

    QQ s = gram[i * dim + j];
    for (int k = 0; k < j; k++)
        s = qq_sub(s, qq_mul(L[i*dim+k], L[j*dim+k]));
    L[i * dim + j] = qq_mul(s, inv);
}

__global__
void qq_cholesky_diagonal(
    const QQ* __restrict__ gram, QQ* __restrict__ L,
    QQ* __restrict__ diag_out, QQ* __restrict__ inv_out,
    int* __restrict__ status, int j, int dim)
{
    QQ s = gram[j * dim + j];
    for (int k = 0; k < j; k++) {
        QQ ljk = L[j * dim + k];
        s = qq_sub(s, qq_mul(ljk, ljk));
    }
    if (qq_le_zero(s)) { *status = j + 1; return; }
    QQ d = qq_sqrt(s);
    L[j * dim + j] = d;
    *diag_out = d;
    *inv_out = qq_div(qq_make(1.0), d);
}

__global__
void qq_forward_solve(const QQ* __restrict__ L, const QQ* __restrict__ b,
                      QQ* __restrict__ y, int dim) {
    for (int i = 0; i < dim; i++) {
        QQ s = b[i];
        for (int k = 0; k < i; k++)
            s = qq_sub(s, qq_mul(L[i*dim+k], y[k]));
        y[i] = qq_div(s, L[i*dim+i]);
    }
}

__global__
void qq_backward_solve(const QQ* __restrict__ L, const QQ* __restrict__ y,
                       QQ* __restrict__ c, int dim) {
    for (int i = dim-1; i >= 0; i--) {
        QQ s = y[i];
        for (int k = i+1; k < dim; k++)
            s = qq_sub(s, qq_mul(L[k*dim+i], c[k]));
        c[i] = qq_div(s, L[i*dim+i]);
    }
}

__global__
void qq_dot_product(const QQ* __restrict__ b, const QQ* __restrict__ c,
                    double* __restrict__ d2_hi, double* __restrict__ d2_lo,
                    int dim) {
    QQ bc = qq_make(0.0);
    for (int i = 0; i < dim; i++)
        bc = qq_add(bc, qq_mul(b[i], c[i]));
    QQ one = qq_make(1.0);
    QQ d2 = qq_sub(one, bc);
    *d2_hi = d2.x[0];
    *d2_lo = d2.x[1];
}

/* ═══════════════════════════════════════════════════════════════
   Host API
   ═══════════════════════════════════════════════════════════════ */

extern "C" {

/// Compute d² = 1 - b^T G^{-1} b using QQ (quad-double) Cholesky.
/// ~62 decimal digits of precision.
///
/// Input: DD Gram matrix (hi + lo arrays), b vector.
/// Output: d² as f64 (only ~15 digits returned, but internal is ~62).
///
/// Memory: ~32 × N² bytes (4× more than DD).
/// Recommended: N ≤ 20,000.
double gpu_qq_cholesky_d2(
    const double* gram_hi_host,
    const double* gram_lo_host,
    const double* b_host,
    int dim,
    int* fail_col)
{
    size_t n = (size_t)dim;
    size_t mat_qq = n * n * sizeof(QQ);
    size_t vec_qq = n * sizeof(QQ);

    // Convert DD → QQ on host
    QQ* h_gram = (QQ*)malloc(mat_qq);
    QQ* h_b = (QQ*)malloc(vec_qq);
    for (size_t i = 0; i < n*n; i++)
        h_gram[i] = qq_from_dd(gram_hi_host[i], gram_lo_host[i]);
    for (size_t i = 0; i < n; i++)
        h_b[i] = qq_from_dd(b_host[i], 0.0);

    QQ *d_gram, *d_L, *d_b, *d_y, *d_c, *d_diag, *d_inv;
    double *d_d2_hi, *d_d2_lo;
    int *d_status;

    cudaMalloc(&d_gram, mat_qq);
    cudaMalloc(&d_L, mat_qq);
    cudaMalloc(&d_b, vec_qq);
    cudaMalloc(&d_y, vec_qq);
    cudaMalloc(&d_c, vec_qq);
    cudaMalloc(&d_diag, sizeof(QQ));
    cudaMalloc(&d_inv, sizeof(QQ));
    cudaMalloc(&d_d2_hi, sizeof(double));
    cudaMalloc(&d_d2_lo, sizeof(double));
    cudaMalloc(&d_status, sizeof(int));

    cudaMemcpy(d_gram, h_gram, mat_qq, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, h_b, vec_qq, cudaMemcpyHostToDevice);
    cudaMemset(d_L, 0, mat_qq);
    cudaMemset(d_status, 0, sizeof(int));
    *fail_col = 0;

    // Column-by-column Cholesky
    for (int j = 0; j < dim; j++) {
        qq_cholesky_diagonal<<<1,1>>>(d_gram, d_L, d_diag, d_inv,
                                      d_status, j, dim);
        int h_s = 0;
        cudaMemcpy(&h_s, d_status, sizeof(int), cudaMemcpyDeviceToHost);
        if (h_s != 0) { *fail_col = h_s; goto cleanup; }

        int rem = dim - j - 1;
        if (rem > 0) {
            QQ h_inv;
            cudaMemcpy(&h_inv, d_inv, sizeof(QQ), cudaMemcpyDeviceToHost);
            int thr = 256, blk = (rem + thr - 1) / thr;
            qq_cholesky_column<<<blk, thr>>>(d_gram, d_L, h_inv, j, dim);
        }
    }
    cudaDeviceSynchronize();

    // Triangular solves + dot product
    qq_forward_solve<<<1,1>>>(d_L, d_b, d_y, dim);
    qq_backward_solve<<<1,1>>>(d_L, d_y, d_c, dim);
    qq_dot_product<<<1,1>>>(d_b, d_c, d_d2_hi, d_d2_lo, dim);
    cudaDeviceSynchronize();

    {
        double h_d2;
        cudaMemcpy(&h_d2, d_d2_hi, sizeof(double), cudaMemcpyDeviceToHost);
        free(h_gram); free(h_b);
        cudaFree(d_gram); cudaFree(d_L); cudaFree(d_b);
        cudaFree(d_y); cudaFree(d_c);
        cudaFree(d_diag); cudaFree(d_inv);
        cudaFree(d_d2_hi); cudaFree(d_d2_lo);
        cudaFree(d_status);
        return h_d2;
    }

cleanup:
    free(h_gram); free(h_b);
    cudaFree(d_gram); cudaFree(d_L); cudaFree(d_b);
    cudaFree(d_y); cudaFree(d_c);
    cudaFree(d_diag); cudaFree(d_inv);
    cudaFree(d_d2_hi); cudaFree(d_d2_lo);
    cudaFree(d_status);
    return NAN;
}

}  // extern "C"
