/*
 * qs_cholesky.cu — GPU Quad-Single (f32) Cholesky
 *
 * QS = 4 × f32 → ~28 decimal digits at f32 throughput.
 * Based on Bailey's QD library adapted for f32.
 *
 * Build: nvcc -arch=sm_89 -O3 --shared -Xcompiler -fPIC -o libqscholesky.so qs_cholesky.cu
 */

#include <math.h>

/* ═══════ Core error-free transformations ═══════ */

__device__ __forceinline__
void qts(float a, float b, float &s, float &e) {  // quick_two_sum
    s = a + b; e = b - (s - a);
}

__device__ __forceinline__
void ts(float a, float b, float &s, float &e) {  // two_sum
    s = a + b; float v = s - a; e = (a - (s - v)) + (b - v);
}

__device__ __forceinline__
void tp(float a, float b, float &p, float &e) {  // two_prod
    p = a * b; e = fmaf(a, b, -p);
}

/* ═══════ Double-single (DS) building block ═══════ */
// DS = (hi, lo), used as sub-component for QS

__device__ __forceinline__
void ds_add(float ah, float al, float bh, float bl, float &rh, float &rl) {
    float s, e; ts(ah, bh, s, e); e += al + bl; qts(s, e, rh, rl);
}

__device__ __forceinline__
void ds_mul(float ah, float al, float bh, float bl, float &rh, float &rl) {
    float p, e; tp(ah, bh, p, e); e += ah*bl + al*bh; qts(p, e, rh, rl);
}

/* ═══════ Quad-single as pair of double-singles ═══════
   QS = (hi0, lo0, hi1, lo1) = DS_high + DS_low
   Value = hi0 + lo0 + hi1 + lo1
   Precision: ~4×24 = ~96 mantissa bits → ~28 digits
*/

struct QS {
    float h0, l0, h1, l1;
};

__device__ __forceinline__
QS qs_make(float v) { return {v, 0.0f, 0.0f, 0.0f}; }

__device__ __host__
QS qs_from_dd(double hi, double lo) {
    // Convert DD (f64 pair) → QS (f32 quad)
    float a = (float)hi;
    float b = (float)(hi - (double)a);
    double rem = lo + (hi - (double)a - (double)b);
    float c = (float)rem;
    float d = (float)(rem - (double)c);
    return {a, b, c, d};
}

__device__ __forceinline__
double qs_to_double(QS q) {
    return (double)q.h0 + (double)q.l0 + (double)q.h1 + (double)q.l1;
}

// Renormalize 4 floats into canonical QS form
__device__
QS qs_renorm(float a, float b, float c, float d) {
    float s0,s1,s2,e;
    qts(c, d, s0, d);  qts(b, s0, s0, c);  qts(a, s0, s0, b);
    s1 = b; s2 = c;
    qts(s1, s2, s1, s2);
    qts(s0, s1, s0, s1);
    return {s0, s1, s2, d};
}

// QS + QS
__device__
QS qs_add(QS a, QS b) {
    float s0,s1,s2,s3,t0,t1,t2;
    ts(a.h0, b.h0, s0, t0);
    ts(a.l0, b.l0, s1, t1);
    ts(a.h1, b.h1, s2, t2);
    s3 = a.l1 + b.l1;
    // Cascade carries
    ts(s1, t0, s1, t0);
    ts(s2, t0, s2, t0); ts(s2, t1, s2, t1);
    float ee;
    ts(s3, t0, s3, ee); t0 = ee;
    ts(s3, t1, s3, ee); t1 = ee;
    ts(s3, t2, s3, ee); t2 = ee;
    s3 += t0 + t1 + t2;
    return qs_renorm(s0, s1, s2, s3);
}

__device__ __forceinline__
QS qs_neg(QS a) { return {-a.h0, -a.l0, -a.h1, -a.l1}; }

__device__ __forceinline__
QS qs_sub(QS a, QS b) { return qs_add(a, qs_neg(b)); }

// QS * QS (sloppy — keeps terms up to ~4 ulp)
__device__
QS qs_mul(QS a, QS b) {
    float p00h, p00l, p01h, p01l, p10h, p10l;
    float p02h, p02l, p11h, p11l, p20h, p20l;
    tp(a.h0, b.h0, p00h, p00l);   // O(1)
    tp(a.h0, b.l0, p01h, p01l);   // O(eps)
    tp(a.l0, b.h0, p10h, p10l);   // O(eps)
    tp(a.h0, b.h1, p02h, p02l);   // O(eps²)
    tp(a.l0, b.l0, p11h, p11l);   // O(eps²)
    tp(a.h1, b.h0, p20h, p20l);   // O(eps²)

    // O(eps³) terms — just accumulate as floats
    float p03 = a.h0 * b.l1;
    float p12 = a.l0 * b.h1;
    float p21 = a.h1 * b.l0;
    float p30 = a.l1 * b.h0;

    // Accumulate level by level
    float s0 = p00h;
    float s1, e1;
    ts(p01h, p10h, s1, e1);
    ts(s1, p00l, s1, e1);  // add p00l
    float s2, e2;
    ts(p02h, p11h, s2, e2);
    ts(s2, p20h, s2, e2);
    s2 += p01l + p10l + e1;
    float s3 = p03 + p12 + p21 + p30 + p02l + p11l + p20l + e2;

    return qs_renorm(s0, s1, s2, s3);
}

// QS / QS via iterative refinement
__device__
QS qs_div(QS a, QS b) {
    float q0 = a.h0 / b.h0;
    QS r = qs_sub(a, qs_mul(b, qs_make(q0)));
    float q1 = r.h0 / b.h0;
    r = qs_sub(r, qs_mul(b, qs_make(q1)));
    float q2 = r.h0 / b.h0;
    r = qs_sub(r, qs_mul(b, qs_make(q2)));
    float q3 = r.h0 / b.h0;
    return qs_renorm(q0, q1, q2, q3);
}

// QS sqrt via Newton (3 iterations for full precision)
__device__
QS qs_sqrt(QS a) {
    if (a.h0 <= 0.0f) return qs_make(0.0f);
    QS x = qs_make(sqrtf(a.h0));
    QS half = qs_make(0.5f);
    for (int i = 0; i < 3; i++)
        x = qs_mul(qs_add(x, qs_div(a, x)), half);
    return x;
}

__device__ __forceinline__
bool qs_le_zero(QS a) { return a.h0 < 0.0f || (a.h0 == 0.0f && a.l0 <= 0.0f); }

/* ═══════ Cholesky kernels ═══════ */

__global__
void qs_cholesky_column(
    const QS* __restrict__ gram, QS* __restrict__ L,
    float inv_h0, float inv_l0, float inv_h1, float inv_l1,
    int j, int dim)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x + j + 1;
    if (i >= dim) return;
    QS s = gram[i * dim + j];
    for (int k = 0; k < j; k++)
        s = qs_sub(s, qs_mul(L[i*dim+k], L[j*dim+k]));
    QS inv = {inv_h0, inv_l0, inv_h1, inv_l1};
    L[i * dim + j] = qs_mul(s, inv);
}

__global__
void qs_cholesky_diagonal(
    const QS* __restrict__ gram, QS* __restrict__ L,
    QS* __restrict__ diag_out, QS* __restrict__ inv_out,
    int* __restrict__ status, int j, int dim)
{
    QS s = gram[j * dim + j];
    for (int k = 0; k < j; k++) {
        QS ljk = L[j * dim + k];
        s = qs_sub(s, qs_mul(ljk, ljk));
    }
    if (qs_le_zero(s)) { *status = j + 1; return; }
    QS d = qs_sqrt(s);
    L[j * dim + j] = d;
    *diag_out = d;
    *inv_out = qs_div(qs_make(1.0f), d);
}

__global__
void qs_forward_solve(const QS* __restrict__ L, const QS* __restrict__ b,
                      QS* __restrict__ y, int dim) {
    for (int i = 0; i < dim; i++) {
        QS s = b[i];
        for (int k = 0; k < i; k++)
            s = qs_sub(s, qs_mul(L[i*dim+k], y[k]));
        y[i] = qs_div(s, L[i*dim+i]);
    }
}

__global__
void qs_backward_solve(const QS* __restrict__ L, const QS* __restrict__ y,
                       QS* __restrict__ c, int dim) {
    for (int i = dim-1; i >= 0; i--) {
        QS s = y[i];
        for (int k = i+1; k < dim; k++)
            s = qs_sub(s, qs_mul(L[k*dim+i], c[k]));
        c[i] = qs_div(s, L[i*dim+i]);
    }
}

__global__
void qs_dot_product(const QS* __restrict__ b, const QS* __restrict__ c,
                    double* __restrict__ d2_out, int dim) {
    QS bc = qs_make(0.0f);
    for (int i = 0; i < dim; i++)
        bc = qs_add(bc, qs_mul(b[i], c[i]));
    QS one = qs_make(1.0f);
    QS d2 = qs_sub(one, bc);
    *d2_out = qs_to_double(d2);
}

/* ═══════ Host API ═══════ */

extern "C" {

double gpu_qs_cholesky_d2(
    const double* gram_hi_host, const double* gram_lo_host,
    const double* b_host, int dim, int* fail_col)
{
    size_t n = (size_t)dim;
    size_t mat_qs = n * n * sizeof(QS);
    size_t vec_qs = n * sizeof(QS);

    // Convert f64 DD → QS on host
    QS* h_gram = (QS*)malloc(mat_qs);
    QS* h_b = (QS*)malloc(vec_qs);
    for (size_t i = 0; i < n*n; i++)
        h_gram[i] = qs_from_dd(gram_hi_host[i], gram_lo_host[i]);
    for (size_t i = 0; i < n; i++)
        h_b[i] = qs_from_dd(b_host[i], 0.0);

    QS *d_gram, *d_L, *d_b, *d_y, *d_c, *d_diag, *d_inv;
    double *d_d2; int *d_status;

    cudaMalloc(&d_gram, mat_qs); cudaMalloc(&d_L, mat_qs);
    cudaMalloc(&d_b, vec_qs); cudaMalloc(&d_y, vec_qs); cudaMalloc(&d_c, vec_qs);
    cudaMalloc(&d_diag, sizeof(QS)); cudaMalloc(&d_inv, sizeof(QS));
    cudaMalloc(&d_d2, sizeof(double)); cudaMalloc(&d_status, sizeof(int));

    cudaMemcpy(d_gram, h_gram, mat_qs, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, h_b, vec_qs, cudaMemcpyHostToDevice);
    cudaMemset(d_L, 0, mat_qs);
    cudaMemset(d_status, 0, sizeof(int));
    *fail_col = 0;

    for (int j = 0; j < dim; j++) {
        qs_cholesky_diagonal<<<1,1>>>(d_gram, d_L, d_diag, d_inv, d_status, j, dim);
        int h_s = 0;
        cudaMemcpy(&h_s, d_status, sizeof(int), cudaMemcpyDeviceToHost);
        if (h_s != 0) { *fail_col = h_s; goto cleanup; }

        int rem = dim - j - 1;
        if (rem > 0) {
            QS h_inv;
            cudaMemcpy(&h_inv, d_inv, sizeof(QS), cudaMemcpyDeviceToHost);
            int thr = 256, blk = (rem + thr - 1) / thr;
            qs_cholesky_column<<<blk,thr>>>(d_gram, d_L,
                h_inv.h0, h_inv.l0, h_inv.h1, h_inv.l1, j, dim);
        }
    }
    cudaDeviceSynchronize();

    qs_forward_solve<<<1,1>>>(d_L, d_b, d_y, dim);
    qs_backward_solve<<<1,1>>>(d_L, d_y, d_c, dim);
    qs_dot_product<<<1,1>>>(d_b, d_c, d_d2, dim);
    cudaDeviceSynchronize();

    { double h_d2;
      cudaMemcpy(&h_d2, d_d2, sizeof(double), cudaMemcpyDeviceToHost);
      free(h_gram); free(h_b);
      cudaFree(d_gram); cudaFree(d_L); cudaFree(d_b); cudaFree(d_y); cudaFree(d_c);
      cudaFree(d_diag); cudaFree(d_inv); cudaFree(d_d2); cudaFree(d_status);
      return h_d2; }

cleanup:
    free(h_gram); free(h_b);
    cudaFree(d_gram); cudaFree(d_L); cudaFree(d_b); cudaFree(d_y); cudaFree(d_c);
    cudaFree(d_diag); cudaFree(d_inv); cudaFree(d_d2); cudaFree(d_status);
    return NAN;
}

}  // extern "C"
