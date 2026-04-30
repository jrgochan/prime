// CATHEDRAL GPU GRAM KERNEL v7 — Accurate DD add (not sloppy)

#include <cstdint>
#include <cstdio>
#include <cmath>

struct DD {
    double hi, lo;
    __device__ static DD zero() { return {0.0, 0.0}; }
    __device__ static DD from_f64(double v) { return {v, 0.0}; }
    __device__ static DD from_int(int64_t v) { return {(double)v, 0.0}; }
    __device__ static DD from_pair(double h, double l) { return {h, l}; }
    __device__ double to_f64() const { return hi + lo; }
};

__device__ __noinline__
void two_sum(double a, double b, double &s, double &e) {
    s = a + b;
    double v = s - a;
    e = (a - (s - v)) + (b - v);
}

__device__ __noinline__
void quick_two_sum(double a, double b, double &s, double &e) {
    s = a + b;
    e = b - (s - a);
}

__device__ __noinline__
void two_prod(double a, double b, double &p, double &e) {
    p = a * b;
    e = __fma_rn(a, b, -p);
}

// ACCURATE DD add (IEEE 754 compliant, not sloppy)
__device__ DD dd_add(DD a, DD b) {
    double s1, s2, t1, t2;
    two_sum(a.hi, b.hi, s1, s2);
    two_sum(a.lo, b.lo, t1, t2);
    s2 += t1;
    quick_two_sum(s1, s2, s1, s2);
    s2 += t2;
    quick_two_sum(s1, s2, s1, s2);
    return {s1, s2};
}

__device__ DD dd_sub(DD a, DD b) { return dd_add(a, {-b.hi, -b.lo}); }

__device__ DD dd_mul(DD a, DD b) {
    double p1, p2;
    two_prod(a.hi, b.hi, p1, p2);
    p2 += a.hi * b.lo + a.lo * b.hi;
    quick_two_sum(p1, p2, p1, p2);
    return {p1, p2};
}

__device__ DD dd_div(DD a, DD b) {
    double q1 = a.hi / b.hi;
    DD r = dd_sub(a, dd_mul({q1,0}, b));
    double q2 = r.hi / b.hi;
    r = dd_sub(r, dd_mul({q2,0}, b));
    double q3 = r.hi / b.hi;
    double s1, s2;
    quick_two_sum(q1, q2, s1, s2);
    return dd_add({s1, s2}, {q3, 0});
}

__device__ int dev_gcd(int a, int b) {
    while (b) { int t = b; b = a % b; a = t; }
    return a;
}

__global__ void gram_kernel_dd(
    double *output, int dim,
    const double *ln_hi, const double *ln_lo, int ln_max
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = dim * (dim + 1) / 2;
    if (idx >= total) return;

    int row = 0, col = 0;
    int remaining = idx;
    for (row = 0; row < dim; row++) {
        int width = dim - row;
        if (remaining < width) { col = row + remaining; break; }
        remaining -= width;
    }

    int j = row + 2;
    int k = col + 2;

    DD inv_jk = dd_div(DD::from_int(1), dd_mul(DD::from_int(j), DD::from_int(k)));
    DD inv_jf = dd_div(DD::from_int(1), DD::from_int(j));
    DD inv_kf = dd_div(DD::from_int(1), DD::from_int(k));

    int g = dev_gcd(j, k);
    int lcm_jk = (j / g) * k;
    int t_direct = min(max(lcm_jk * 5, 5000), min(200000, ln_max));

    DD total_sum = DD::zero();

    for (int n = 1; n <= t_direct; n++) {
        int a_int = n / j;
        int b_int = n / k;
        DD ln_term = DD::from_pair(ln_hi[n], ln_lo[n]);
        DD a_coeff = dd_mul(DD::from_int(a_int), inv_kf);
        DD b_coeff = dd_mul(DD::from_int(b_int), inv_jf);
        DD ab_coeff = dd_mul(dd_add(a_coeff, b_coeff), ln_term);
        DD term = dd_sub(inv_jk, ab_coeff);
        if (a_int > 0 && b_int > 0) {
            DD num = DD::from_int((int64_t)a_int * b_int);
            DD den = dd_mul(DD::from_int(n), DD::from_int(n + 1));
            term = dd_add(term, dd_div(num, den));
        }
        total_sum = dd_add(total_sum, term);
    }

    // Euler-Maclaurin tail (DD precision)
    DD df = DD::from_int(g);
    DD jkf = dd_mul(DD::from_int(j), DD::from_int(k));
    DD twelve = DD::from_f64(12.0);
    DD tail_frac = dd_div(dd_mul(df, df), dd_mul(twelve, jkf));
    DD tail_mean = dd_add(DD::from_f64(0.25), tail_frac);
    DD inv_t = dd_div(DD::from_int(1), DD::from_int(t_direct));
    DD inv_t2 = dd_mul(inv_t, inv_t);
    DD inv_t3 = dd_mul(inv_t2, inv_t);
    total_sum = dd_add(total_sum, dd_mul(tail_mean, inv_t));
    total_sum = dd_add(total_sum, dd_mul(dd_mul(tail_mean, DD::from_f64(0.5)), inv_t2));
    DD sixth = dd_div(DD::from_int(1), DD::from_int(6));
    total_sum = dd_add(total_sum, dd_mul(dd_mul(tail_mean, sixth), inv_t3));

    double result = total_sum.to_f64();
    output[row * dim + col] = result;
    if (row != col) output[col * dim + row] = result;
}

extern "C" {
int gpu_gram_build_dd(
    double *host_output, int max_n,
    const double *host_ln_hi, const double *host_ln_lo, int ln_count
) {
    int dim = max_n - 1;
    int total = dim * (dim + 1) / 2;
    size_t matrix_bytes = (size_t)dim * dim * sizeof(double);
    size_t ln_bytes = (size_t)ln_count * sizeof(double);

    double *d_output, *d_ln_hi, *d_ln_lo;
    cudaMalloc(&d_output, matrix_bytes);
    cudaMalloc(&d_ln_hi, ln_bytes);
    cudaMalloc(&d_ln_lo, ln_bytes);
    cudaMemset(d_output, 0, matrix_bytes);
    cudaMemcpy(d_ln_hi, host_ln_hi, ln_bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_ln_lo, host_ln_lo, ln_bytes, cudaMemcpyHostToDevice);

    int threads = 256;
    int blocks = (total + threads - 1) / threads;
    printf("  GPU DD v7: %d entries, %d blocks x %d threads\n", total, blocks, threads);
    gram_kernel_dd<<<blocks, threads>>>(d_output, dim, d_ln_hi, d_ln_lo, ln_count - 1);
    cudaDeviceSynchronize();

    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        printf("  CUDA error: %s\n", cudaGetErrorString(err));
        cudaFree(d_output); cudaFree(d_ln_hi); cudaFree(d_ln_lo);
        return -1;
    }
    cudaMemcpy(host_output, d_output, matrix_bytes, cudaMemcpyDeviceToHost);
    cudaFree(d_output); cudaFree(d_ln_hi); cudaFree(d_ln_lo);
    return 0;
}
}
