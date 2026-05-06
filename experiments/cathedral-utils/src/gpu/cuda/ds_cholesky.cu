/*
 * ds_cholesky.cu — GPU Double-Single (f32) Cholesky
 *
 * DS = "double-single": each number = (hi: f32, lo: f32) → ~14 digits.
 * Same precision as f64, but uses GPU's native f32 (64× faster on RTX 4090).
 *
 * Build: nvcc -arch=sm_89 -O3 --shared -Xcompiler -fPIC -o libdscholesky.so ds_cholesky.cu
 */

#include <stdio.h>
#include <math.h>

/* ═══════ DS (double-single f32) arithmetic ═══════ */

__device__ __forceinline__
void ds_two_sum(float a, float b, float &s, float &e) {
    s = a + b;
    float v = s - a;
    e = (a - (s - v)) + (b - v);
}

__device__ __forceinline__
void ds_two_prod(float a, float b, float &p, float &e) {
    p = a * b;
    e = fmaf(a, b, -p);
}

__device__ __forceinline__
void ds_add(float ah, float al, float bh, float bl, float &rh, float &rl) {
    float s, e;
    ds_two_sum(ah, bh, s, e);
    e += al + bl;
    ds_two_sum(s, e, rh, rl);
}

__device__ __forceinline__
void ds_sub(float ah, float al, float bh, float bl, float &rh, float &rl) {
    ds_add(ah, al, -bh, -bl, rh, rl);
}

__device__ __forceinline__
void ds_mul(float ah, float al, float bh, float bl, float &rh, float &rl) {
    float p, e;
    ds_two_prod(ah, bh, p, e);
    e += ah * bl + al * bh;
    ds_two_sum(p, e, rh, rl);
}

__device__ __forceinline__
void ds_div(float ah, float al, float bh, float bl, float &rh, float &rl) {
    float q1 = ah / bh;
    float rhi, rlo;
    ds_mul(bh, bl, q1, 0.0f, rhi, rlo);
    ds_sub(ah, al, rhi, rlo, rhi, rlo);
    float q2 = rhi / bh;
    ds_two_sum(q1, q2, rh, rl);
}

__device__ __forceinline__
void ds_sqrt(float ah, float al, float &rh, float &rl) {
    if (ah <= 0.0f) { rh = 0.0f; rl = 0.0f; return; }
    float x = sqrtf(ah);
    float qh, ql;
    ds_div(ah, al, x, 0.0f, qh, ql);
    ds_add(x, 0.0f, qh, ql, rh, rl);
    rh *= 0.5f; rl *= 0.5f;
    ds_div(ah, al, rh, rl, qh, ql);
    ds_add(rh, rl, qh, ql, rh, rl);
    rh *= 0.5f; rl *= 0.5f;
}

/* ═══════ Cholesky kernels (f32 DS) ═══════ */

__global__
void ds_cholesky_column(
    const float* __restrict__ gram_hi, const float* __restrict__ gram_lo,
    float* __restrict__ l_hi, float* __restrict__ l_lo,
    float inv_hi, float inv_lo, int j, int dim)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x + j + 1;
    if (i >= dim) return;
    int idx = i * dim + j;
    float sh = gram_hi[idx], sl = gram_lo[idx];
    for (int k = 0; k < j; k++) {
        float ph, pl;
        ds_mul(l_hi[i*dim+k], l_lo[i*dim+k], l_hi[j*dim+k], l_lo[j*dim+k], ph, pl);
        ds_sub(sh, sl, ph, pl, sh, sl);
    }
    float rh, rl;
    ds_mul(sh, sl, inv_hi, inv_lo, rh, rl);
    l_hi[idx] = rh;
    l_lo[idx] = rl;
}

__global__
void ds_cholesky_diagonal(
    const float* __restrict__ gram_hi, const float* __restrict__ gram_lo,
    float* __restrict__ l_hi, float* __restrict__ l_lo,
    float* __restrict__ out_hi, float* __restrict__ out_lo,
    float* __restrict__ inv_hi, float* __restrict__ inv_lo,
    int* __restrict__ status, int j, int dim)
{
    int idx = j * dim + j;
    float sh = gram_hi[idx], sl = gram_lo[idx];
    for (int k = 0; k < j; k++) {
        float ph, pl;
        ds_mul(l_hi[j*dim+k], l_lo[j*dim+k], l_hi[j*dim+k], l_lo[j*dim+k], ph, pl);
        ds_sub(sh, sl, ph, pl, sh, sl);
    }
    if (sh <= 0.0f) { *status = j + 1; *out_hi = sh; *out_lo = sl; return; }
    float dh, dl;
    ds_sqrt(sh, sl, dh, dl);
    l_hi[idx] = dh; l_lo[idx] = dl;
    *out_hi = dh; *out_lo = dl;
    ds_div(1.0f, 0.0f, dh, dl, *inv_hi, *inv_lo);
}

__global__
void ds_forward_solve(
    const float* __restrict__ l_hi, const float* __restrict__ l_lo,
    const float* __restrict__ b_hi, const float* __restrict__ b_lo,
    float* __restrict__ y_hi, float* __restrict__ y_lo, int dim)
{
    for (int i = 0; i < dim; i++) {
        float sh = b_hi[i], sl = b_lo[i];
        for (int k = 0; k < i; k++) {
            float ph, pl;
            ds_mul(l_hi[i*dim+k], l_lo[i*dim+k], y_hi[k], y_lo[k], ph, pl);
            ds_sub(sh, sl, ph, pl, sh, sl);
        }
        ds_div(sh, sl, l_hi[i*dim+i], l_lo[i*dim+i], y_hi[i], y_lo[i]);
    }
}

__global__
void ds_backward_solve(
    const float* __restrict__ l_hi, const float* __restrict__ l_lo,
    const float* __restrict__ y_hi, const float* __restrict__ y_lo,
    float* __restrict__ c_hi, float* __restrict__ c_lo, int dim)
{
    for (int i = dim - 1; i >= 0; i--) {
        float sh = y_hi[i], sl = y_lo[i];
        for (int k = i + 1; k < dim; k++) {
            float ph, pl;
            ds_mul(l_hi[k*dim+i], l_lo[k*dim+i], c_hi[k], c_lo[k], ph, pl);
            ds_sub(sh, sl, ph, pl, sh, sl);
        }
        ds_div(sh, sl, l_hi[i*dim+i], l_lo[i*dim+i], c_hi[i], c_lo[i]);
    }
}

__global__
void ds_dot_product(
    const float* __restrict__ b_hi, const float* __restrict__ b_lo,
    const float* __restrict__ c_hi, const float* __restrict__ c_lo,
    double* __restrict__ d2_out, int dim)
{
    // Accumulate in f64 for final result
    double bc = 0.0;
    for (int i = 0; i < dim; i++) {
        double bi = (double)b_hi[i] + (double)b_lo[i];
        double ci = (double)c_hi[i] + (double)c_lo[i];
        bc += bi * ci;
    }
    *d2_out = 1.0 - bc;
}

/* ═══════ Host API ═══════ */

extern "C" {

// DS-f32 Cholesky: input is f64 DD, converted to f32 DS internally.
// Returns d² as f64. ~14 digits precision, f32 speed.
double gpu_ds_cholesky_d2(
    const double* gram_hi_host, const double* gram_lo_host,
    const double* b_host, int dim, int* fail_col)
{
    size_t n = (size_t)dim;
    size_t mat_f = n * n * sizeof(float);
    size_t vec_f = n * sizeof(float);

    // Convert f64 DD → f32 DS on host
    float* h_ghi = (float*)malloc(n*n*sizeof(float));
    float* h_glo = (float*)malloc(n*n*sizeof(float));
    float* h_bhi = (float*)malloc(n*sizeof(float));
    float* h_blo = (float*)malloc(n*sizeof(float));
    for (size_t i = 0; i < n*n; i++) {
        h_ghi[i] = (float)gram_hi_host[i];
        h_glo[i] = (float)(gram_hi_host[i] - (double)h_ghi[i] + gram_lo_host[i]);
    }
    for (size_t i = 0; i < n; i++) {
        h_bhi[i] = (float)b_host[i];
        h_blo[i] = (float)(b_host[i] - (double)h_bhi[i]);
    }

    float *d_ghi, *d_glo, *d_lhi, *d_llo;
    float *d_bhi, *d_blo, *d_yhi, *d_ylo, *d_chi, *d_clo;
    float *d_ohi, *d_olo, *d_ihi, *d_ilo;
    double *d_d2; int *d_status;

    cudaMalloc(&d_ghi, mat_f); cudaMalloc(&d_glo, mat_f);
    cudaMalloc(&d_lhi, mat_f); cudaMalloc(&d_llo, mat_f);
    cudaMalloc(&d_bhi, vec_f); cudaMalloc(&d_blo, vec_f);
    cudaMalloc(&d_yhi, vec_f); cudaMalloc(&d_ylo, vec_f);
    cudaMalloc(&d_chi, vec_f); cudaMalloc(&d_clo, vec_f);
    cudaMalloc(&d_ohi, sizeof(float)); cudaMalloc(&d_olo, sizeof(float));
    cudaMalloc(&d_ihi, sizeof(float)); cudaMalloc(&d_ilo, sizeof(float));
    cudaMalloc(&d_d2, sizeof(double)); cudaMalloc(&d_status, sizeof(int));

    cudaMemcpy(d_ghi, h_ghi, mat_f, cudaMemcpyHostToDevice);
    cudaMemcpy(d_glo, h_glo, mat_f, cudaMemcpyHostToDevice);
    cudaMemcpy(d_bhi, h_bhi, vec_f, cudaMemcpyHostToDevice);
    cudaMemcpy(d_blo, h_blo, vec_f, cudaMemcpyHostToDevice);
    cudaMemset(d_lhi, 0, mat_f); cudaMemset(d_llo, 0, mat_f);
    cudaMemset(d_status, 0, sizeof(int));
    *fail_col = 0;

    for (int j = 0; j < dim; j++) {
        ds_cholesky_diagonal<<<1, 1>>>(d_ghi, d_glo, d_lhi, d_llo,
            d_ohi, d_olo, d_ihi, d_ilo, d_status, j, dim);
        int h_s = 0;
        cudaMemcpy(&h_s, d_status, sizeof(int), cudaMemcpyDeviceToHost);
        if (h_s != 0) {
            *fail_col = h_s;
            goto cleanup;
        }
        int rem = dim - j - 1;
        if (rem > 0) {
            float h_ihi, h_ilo;
            cudaMemcpy(&h_ihi, d_ihi, sizeof(float), cudaMemcpyDeviceToHost);
            cudaMemcpy(&h_ilo, d_ilo, sizeof(float), cudaMemcpyDeviceToHost);
            int thr = 256, blk = (rem + thr - 1) / thr;
            ds_cholesky_column<<<blk, thr>>>(d_ghi, d_glo, d_lhi, d_llo,
                h_ihi, h_ilo, j, dim);
        }
    }
    cudaDeviceSynchronize();
    ds_forward_solve<<<1, 1>>>(d_lhi, d_llo, d_bhi, d_blo, d_yhi, d_ylo, dim);
    ds_backward_solve<<<1, 1>>>(d_lhi, d_llo, d_yhi, d_ylo, d_chi, d_clo, dim);
    ds_dot_product<<<1, 1>>>(d_bhi, d_blo, d_chi, d_clo, d_d2, dim);
    cudaDeviceSynchronize();

    { double h_d2;
      cudaMemcpy(&h_d2, d_d2, sizeof(double), cudaMemcpyDeviceToHost);
      free(h_ghi); free(h_glo); free(h_bhi); free(h_blo);
      cudaFree(d_ghi); cudaFree(d_glo); cudaFree(d_lhi); cudaFree(d_llo);
      cudaFree(d_bhi); cudaFree(d_blo); cudaFree(d_yhi); cudaFree(d_ylo);
      cudaFree(d_chi); cudaFree(d_clo); cudaFree(d_ohi); cudaFree(d_olo);
      cudaFree(d_ihi); cudaFree(d_ilo); cudaFree(d_d2); cudaFree(d_status);
      return h_d2;
    }

cleanup:
    free(h_ghi); free(h_glo); free(h_bhi); free(h_blo);
    cudaFree(d_ghi); cudaFree(d_glo); cudaFree(d_lhi); cudaFree(d_llo);
    cudaFree(d_bhi); cudaFree(d_blo); cudaFree(d_yhi); cudaFree(d_ylo);
    cudaFree(d_chi); cudaFree(d_clo); cudaFree(d_ohi); cudaFree(d_olo);
    cudaFree(d_ihi); cudaFree(d_ilo); cudaFree(d_d2); cudaFree(d_status);
    return NAN;
}

}  // extern "C"
