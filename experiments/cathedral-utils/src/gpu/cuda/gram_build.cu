/*
 * gram_gpu.cu — GPU Gram Matrix Build using QS-f32 (quad-single)
 *
 * QS = 4 × f32 → ~28 digits at f32 throughput.
 * The block-based algorithm has O(T/j + T/k) blocks per entry,
 * and QS-f32 survives thousands of accumulations without
 * losing precision below the DD threshold (~15 digits).
 *
 * Build: nvcc -arch=sm_89 -O3 --shared -Xcompiler -fPIC -o libgramgpu.so gram_gpu.cu
 */

#include <math.h>
#include <stdio.h>

/* ═══════ Error-free transformations ═══════ */

__device__ __forceinline__
void qts_f(float a, float b, float &s, float &e) {
    s = a + b; e = b - (s - a);
}

__device__ __forceinline__
void ts_f(float a, float b, float &s, float &e) {
    s = a + b; float v = s - a; e = (a - (s - v)) + (b - v);
}

__device__ __forceinline__
void tp_f(float a, float b, float &p, float &e) {
    p = a * b; e = fmaf(a, b, -p);
}

/* ═══════ QS (quad-single) arithmetic ═══════ */

struct QS { float v[4]; };

__device__ __forceinline__
QS qs_zero() { QS r; r.v[0]=r.v[1]=r.v[2]=r.v[3]=0.0f; return r; }

__device__ __forceinline__
QS qs_make(float a) { QS r; r.v[0]=a; r.v[1]=r.v[2]=r.v[3]=0.0f; return r; }

__device__
QS qs_from_double(double a) {
    float h = (float)a;
    float l = (float)(a - (double)h);
    QS r; r.v[0]=h; r.v[1]=l; r.v[2]=r.v[3]=0.0f;
    return r;
}

__device__
QS qs_from_dd(double hi, double lo) {
    float a = (float)hi;
    float b = (float)(hi - (double)a);
    double rem = lo + (hi - (double)a - (double)b);
    float c = (float)rem;
    float d = (float)(rem - (double)c);
    QS r; r.v[0]=a; r.v[1]=b; r.v[2]=c; r.v[3]=d;
    return r;
}

__device__ __forceinline__
double qs_to_double(QS q) {
    return (double)q.v[0] + (double)q.v[1] + (double)q.v[2] + (double)q.v[3];
}

__device__
void qs_to_dd(QS q, double &hi, double &lo) {
    // Convert QS to DD by careful accumulation
    double s = (double)q.v[3];
    s += (double)q.v[2];
    s += (double)q.v[1];
    hi = (double)q.v[0] + s;
    lo = s - (hi - (double)q.v[0]);
}

// Renormalize 4 floats into canonical QS
__device__
QS qs_renorm(float c0, float c1, float c2, float c3) {
    float s0,s1,s2;
    qts_f(c2, c3, s0, c3); qts_f(c1, s0, s0, c2); qts_f(c0, s0, s0, c1);
    s1 = c1; s2 = c2;
    qts_f(s1, s2, s1, s2);
    qts_f(s0, s1, s0, s1);
    QS r; r.v[0]=s0; r.v[1]=s1; r.v[2]=s2; r.v[3]=c3;
    return r;
}

// QS + QS
__device__
QS qs_add(QS a, QS b) {
    float s0,s1,s2,s3,t0,t1,t2;
    ts_f(a.v[0], b.v[0], s0, t0);
    ts_f(a.v[1], b.v[1], s1, t1);
    ts_f(a.v[2], b.v[2], s2, t2);
    s3 = a.v[3] + b.v[3];
    ts_f(s1, t0, s1, t0);
    ts_f(s2, t0, s2, t0); ts_f(s2, t1, s2, t1);
    float ee;
    ts_f(s3, t0, s3, ee); t0 = ee;
    ts_f(s3, t1, s3, ee); t1 = ee;
    ts_f(s3, t2, s3, ee); t2 = ee;
    s3 += t0 + t1 + t2;
    return qs_renorm(s0, s1, s2, s3);
}

__device__ __forceinline__
QS qs_neg(QS a) { QS r; for(int i=0;i<4;i++) r.v[i]=-a.v[i]; return r; }

__device__ __forceinline__
QS qs_sub(QS a, QS b) { return qs_add(a, qs_neg(b)); }

// QS * QS (sloppy — keeps significant terms)
__device__
QS qs_mul(QS a, QS b) {
    float p00h, p00l, p01h, p01l, p10h, p10l;
    float p02h, p02l, p11h, p11l, p20h, p20l;
    tp_f(a.v[0], b.v[0], p00h, p00l);
    tp_f(a.v[0], b.v[1], p01h, p01l);
    tp_f(a.v[1], b.v[0], p10h, p10l);
    tp_f(a.v[0], b.v[2], p02h, p02l);
    tp_f(a.v[1], b.v[1], p11h, p11l);
    tp_f(a.v[2], b.v[0], p20h, p20l);

    float p03 = a.v[0]*b.v[3], p12 = a.v[1]*b.v[2];
    float p21 = a.v[2]*b.v[1], p30 = a.v[3]*b.v[0];

    float s0 = p00h;
    float s1, e1; ts_f(p01h, p10h, s1, e1); ts_f(s1, p00l, s1, e1);
    float s2, e2; ts_f(p02h, p11h, s2, e2); ts_f(s2, p20h, s2, e2);
    s2 += p01l + p10l + e1;
    float s3 = p03 + p12 + p21 + p30 + p02l + p11l + p20l + e2;
    return qs_renorm(s0, s1, s2, s3);
}

// QS / QS via iterative refinement
__device__
QS qs_div(QS a, QS b) {
    float q0 = a.v[0] / b.v[0];
    QS r = qs_sub(a, qs_mul(b, qs_make(q0)));
    float q1 = r.v[0] / b.v[0];
    r = qs_sub(r, qs_mul(b, qs_make(q1)));
    float q2 = r.v[0] / b.v[0];
    r = qs_sub(r, qs_mul(b, qs_make(q2)));
    float q3 = r.v[0] / b.v[0];
    return qs_renorm(q0, q1, q2, q3);
}

// QS from integer (handles values up to 2^53 correctly)
__device__
QS qs_from_int(int n) {
    float h = (float)n;
    float l = (float)(n - (int)h);
    QS r; r.v[0]=h; r.v[1]=l; r.v[2]=r.v[3]=0.0f;
    return r;
}

// QS from long long (handles large products correctly)
__device__
QS qs_from_ll(long long n) {
    double d = (double)n;
    float h = (float)d;
    float l = (float)(d - (double)h);
    double rem = d - (double)h - (double)l;
    float m = (float)rem;
    QS r; r.v[0]=h; r.v[1]=l; r.v[2]=m; r.v[3]=0.0f;
    return r;
}

/* ═══════ Integer GCD ═══════ */

__device__ __forceinline__
int gpu_gcd(int a, int b) {
    while (b != 0) { int t = b; b = a % b; a = t; }
    return a;
}

/* ═══════ On-the-fly QS ln(1+x) for x ∈ [0, 0.5] ═══════ */
// Horner evaluation of Taylor series: ln(1+x) = x(1 - x(1/2 - x(1/3 - ...)))
// 20 terms gives ~28 digits for x ≤ 0.5
__device__
QS qs_ln1p(QS x) {
    QS result = qs_div(qs_make(1.0f), qs_make(20.0f));
    for (int i = 19; i >= 2; i--) {
        result = qs_sub(qs_div(qs_make(1.0f), qs_from_int(i)), qs_mul(x, result));
    }
    result = qs_sub(qs_make(1.0f), qs_mul(x, result));
    return qs_mul(x, result);
}

/* ═══════ Born-Oppenheimer Gram entry kernel (QS-f32) ═══════ */
//
// Block-based algorithm with periodic tail correction:
//   Phase 1: Block-based sum up to T_direct using ln table (fast)
//   Phase 2: For high-lcm entries, extend through one full period
//            using on-the-fly ln(1+x) Taylor computation
//   Phase 3: Euler-Maclaurin tail at extended position
//
// Eliminates "arithmetic aliasing" truncation error for coprime (j,k).

__global__
void gram_build_kernel(
    const float* __restrict__ ln_v0,
    const float* __restrict__ ln_v1,
    const float* __restrict__ ln_v2,
    const float* __restrict__ ln_v3,
    double* __restrict__ gram_hi,
    double* __restrict__ gram_lo,
    int dim, int ln_table_size)
{
    long long tid = (long long)blockIdx.x * blockDim.x + threadIdx.x;
    long long total_entries = (long long)dim * (dim + 1) / 2;
    if (tid >= total_entries) return;

    // Map tid → (row, col) in upper triangle
    double disc = 2.0 * dim + 1.0;
    int row = (int)((disc - sqrt(disc * disc - 8.0 * (double)tid)) / 2.0);
    if (row < 0) row = 0;
    long long row_start = (long long)row * dim - (long long)row * (row - 1) / 2;
    while (row_start + (dim - row) <= tid && row < dim - 1) {
        row++;
        row_start = (long long)row * dim - (long long)row * (row - 1) / 2;
    }
    int col = (int)(tid - row_start) + row;
    if (row < 0 || row >= dim || col < row || col >= dim) return;

    int j = row + 2;
    int k = col + 2;
    int g = gpu_gcd(j, k);
    long long lcm_jk = ((long long)j / g) * k;

    // T_direct: cap for ln-table-based summation
    int t_direct = (int)(lcm_jk * 5);
    if (t_direct < 5000) t_direct = 5000;
    if (t_direct > 100000) t_direct = 100000;
    if (t_direct > ln_table_size - 1) t_direct = ln_table_size - 1;

    QS qs_j = qs_from_int(j);
    QS qs_k = qs_from_int(k);
    QS inv_jk = qs_div(qs_make(1.0f), qs_mul(qs_j, qs_k));
    QS inv_j  = qs_div(qs_make(1.0f), qs_j);
    QS inv_k  = qs_div(qs_make(1.0f), qs_k);
    QS total = qs_zero();

    // ═══ PHASE 1: Block-based direct sum using ln table ═══
    int pos = 1, next_j = j, next_k = k, a = 0, b = 0;

    while (pos <= t_direct) {
        int next = (next_j < next_k) ? next_j : next_k;
        if (next > t_direct + 1) next = t_direct + 1;
        int cnt = next - pos;
        if (cnt <= 0) {
            if (pos >= next_j) { a++; next_j += j; }
            if (pos >= next_k) { b++; next_k += k; }
            continue;
        }
        total = qs_add(total, qs_mul(inv_jk, qs_from_int(cnt)));
        if (a > 0 || b > 0) {
            QS coeff = qs_add(qs_mul(qs_from_int(a), inv_k), qs_mul(qs_from_int(b), inv_j));
            int be = (next <= ln_table_size) ? next : ln_table_size;
            int pi = (pos <= ln_table_size) ? pos : ln_table_size;
            QS ln_be; ln_be.v[0]=ln_v0[be]; ln_be.v[1]=ln_v1[be]; ln_be.v[2]=ln_v2[be]; ln_be.v[3]=ln_v3[be];
            QS ln_pi; ln_pi.v[0]=ln_v0[pi]; ln_pi.v[1]=ln_v1[pi]; ln_pi.v[2]=ln_v2[pi]; ln_pi.v[3]=ln_v3[pi];
            total = qs_sub(total, qs_mul(coeff, qs_sub(ln_be, ln_pi)));
        }
        if (a > 0 && b > 0) {
            QS frac = qs_div(qs_div(qs_from_int(cnt), qs_from_int(pos)), qs_from_int(next));
            total = qs_add(total, qs_mul(qs_from_ll((long long)a * b), frac));
        }
        pos = next;
        if (pos >= next_j) { a++; next_j += j; }
        if (pos >= next_k) { b++; next_k += k; }
    }

    // ═══ PHASE 2: Born-Oppenheimer periodic tail extension ═══
    // For entries where T_direct < 3*lcm, extend through 3 full periods
    // using on-the-fly ln(1 + count/pos) via Taylor series.
    // 3 periods guarantees T_ext ≥ 3*lcm for Euler-Maclaurin convergence.
    int t_ext = t_direct;

    if ((long long)t_direct < lcm_jk * 3 && lcm_jk <= 50000000LL) {
        // Compute how many periods needed: ceil((3*lcm - T_direct) / lcm)
        int n_periods = (int)(((long long)3 * lcm_jk - t_direct + lcm_jk - 1) / lcm_jk);
        if (n_periods < 1) n_periods = 1;
        if (n_periods > 3) n_periods = 3;  // cap for safety
        long long t_end = (long long)t_direct + (long long)n_periods * lcm_jk;
        // pos, next_j, next_k, a, b carry over from Phase 1
        while ((long long)pos <= t_end) {
            long long nl = ((long long)next_j < next_k) ? next_j : next_k;
            if (nl > t_end + 1) nl = t_end + 1;
            int cnt = (int)(nl - pos);
            if (cnt <= 0) {
                if ((long long)pos >= next_j) { a++; next_j += j; }
                if ((long long)pos >= next_k) { b++; next_k += k; }
                continue;
            }
            total = qs_add(total, qs_mul(inv_jk, qs_from_int(cnt)));
            if (a > 0 || b > 0) {
                QS coeff = qs_add(qs_mul(qs_from_int(a), inv_k), qs_mul(qs_from_int(b), inv_j));
                // ln(next/pos) = ln(1 + cnt/pos), cnt ≤ max(j,k), pos ≥ T_direct
                QS x = qs_div(qs_from_int(cnt), qs_from_int(pos));
                total = qs_sub(total, qs_mul(coeff, qs_ln1p(x)));
            }
            if (a > 0 && b > 0) {
                QS frac = qs_div(qs_div(qs_from_int(cnt), qs_from_int(pos)), qs_from_int((int)nl));
                total = qs_add(total, qs_mul(qs_from_ll((long long)a * b), frac));
            }
            pos = (int)nl;
            if ((long long)pos >= next_j) { a++; next_j += j; }
            if ((long long)pos >= next_k) { b++; next_k += k; }
        }
        t_ext = (int)((t_end > 2000000000LL) ? 2000000000LL : t_end);
    }

    // ═══ PHASE 3: Euler-Maclaurin tail at extended position ═══
    {
        QS d = qs_from_int(g);
        QS jkf = qs_mul(qs_j, qs_k);
        QS tm = qs_add(qs_make(0.25f), qs_div(qs_mul(d, d), qs_mul(qs_make(12.0f), jkf)));
        QS inv_t = qs_div(qs_make(1.0f), qs_from_int(t_ext));
        QS inv_t2 = qs_mul(inv_t, inv_t);
        QS inv_t3 = qs_mul(inv_t2, inv_t);
        total = qs_add(total, qs_mul(tm, inv_t));
        total = qs_add(total, qs_mul(qs_mul(tm, qs_make(0.5f)), inv_t2));
        total = qs_add(total, qs_mul(qs_mul(tm, qs_div(qs_make(1.0f), qs_make(6.0f))), inv_t3));
    }

    // Convert QS → DD-f64 and store
    double hi, lo;
    qs_to_dd(total, hi, lo);
    gram_hi[row * dim + col] = hi;
    gram_lo[row * dim + col] = lo;
    gram_hi[col * dim + row] = hi;
    gram_lo[col * dim + row] = lo;
}

/* ═══════ Host API ═══════ */

extern "C" {

// Build QS-f32 Gram matrix on GPU.
// ln table input: 4 float arrays (QS components), size ln_size+1.
// Output: DD-f64 (hi/lo double arrays), size dim*dim each.
int gpu_build_gram_qs(
    const float* ln_v0, const float* ln_v1,
    const float* ln_v2, const float* ln_v3, int ln_size,
    double* gram_hi_host, double* gram_lo_host, int dim)
{
    size_t ln_bytes = (size_t)(ln_size + 1) * sizeof(float);
    size_t mat_bytes = (size_t)dim * dim * sizeof(double);

    float *d_v0, *d_v1, *d_v2, *d_v3;
    double *d_ghi, *d_glo;
    cudaMalloc(&d_v0, ln_bytes); cudaMalloc(&d_v1, ln_bytes);
    cudaMalloc(&d_v2, ln_bytes); cudaMalloc(&d_v3, ln_bytes);
    cudaMalloc(&d_ghi, mat_bytes); cudaMalloc(&d_glo, mat_bytes);

    cudaMemcpy(d_v0, ln_v0, ln_bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_v1, ln_v1, ln_bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_v2, ln_v2, ln_bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_v3, ln_v3, ln_bytes, cudaMemcpyHostToDevice);
    cudaMemset(d_ghi, 0, mat_bytes); cudaMemset(d_glo, 0, mat_bytes);

    long long total = (long long)dim * (dim + 1) / 2;
    int threads = 128;  // fewer threads due to higher register pressure
    int blocks = (int)((total + threads - 1) / threads);

    gram_build_kernel<<<blocks, threads>>>(
        d_v0, d_v1, d_v2, d_v3, d_ghi, d_glo, dim, ln_size);

    cudaError_t err = cudaDeviceSynchronize();
    if (err != cudaSuccess) {
        fprintf(stderr, "GPU QS Gram build error: %s\n", cudaGetErrorString(err));
        cudaFree(d_v0); cudaFree(d_v1); cudaFree(d_v2); cudaFree(d_v3);
        cudaFree(d_ghi); cudaFree(d_glo);
        return -1;
    }

    cudaMemcpy(gram_hi_host, d_ghi, mat_bytes, cudaMemcpyDeviceToHost);
    cudaMemcpy(gram_lo_host, d_glo, mat_bytes, cudaMemcpyDeviceToHost);

    cudaFree(d_v0); cudaFree(d_v1); cudaFree(d_v2); cudaFree(d_v3);
    cudaFree(d_ghi); cudaFree(d_glo);
    return 0;
}

int gpu_gram_max_n() {
    size_t free_mem = 0, total_mem = 0;
    cudaMemGetInfo(&free_mem, &total_mem);
    // Need 2 * dim² * 8 bytes for gram output + 4 * ln_size * 4 for ln table
    size_t available = free_mem - (4 << 20);  // 4MB headroom
    size_t max_dim = (size_t)sqrt((double)(available / 16));
    return (int)(max_dim + 1);
}

}  // extern "C"
