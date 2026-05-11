//! GPU Gram matrix builder — DD precision with MPFR-128 ln table.

use cathedral_utils::{cache, arith};
use rug::Float;
use std::time::Instant;

#[link(name = "gramgpu", kind = "dylib")]
extern "C" {
    fn gpu_gram_build_dd(
        output: *mut f64, max_n: i32,
        ln_hi: *const f64, ln_lo: *const f64, ln_count: i32,
    ) -> i32;
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let max_n: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(100);
    let dim = max_n - 1;

    println!();
    println!("  ╔═══════════════════════════════════════════════════════════════╗");
    println!("  ║  GPU GRAM MATRIX — DD on CUDA (MPFR-128 ln table)");
    println!("  ║  N = {}  ·  dim = {}  ·  {} entries", max_n, dim, dim*(dim+1)/2);
    println!("  ╚═══════════════════════════════════════════════════════════════╝");
    println!();

    // Step 1: Build ln(1+1/n) table using MPFR-128, extract DD (hi, lo)
    let ln_max = (max_n * 5).max(200_000).min(200_000);
    println!("  Building MPFR-128 ln table (n=0..{})...", ln_max);
    let t0 = Instant::now();
    let p = 128;
    let mut ln_hi = vec![0.0f64; ln_max + 1];
    let mut ln_lo = vec![0.0f64; ln_max + 1];
    for n in 1..=ln_max {
        // ln(1 + 1/n) at 128-bit MPFR
        let nf = Float::with_val(p, n as u64);
        let ratio = Float::with_val(p, 1u32) + Float::with_val(p, Float::with_val(p, 1u32) / &nf);
        let ln_val = ratio.ln();
        // Extract DD pair: hi = f64(ln_val), lo = f64(ln_val - hi)
        let hi = ln_val.to_f64();
        let lo = (ln_val - Float::with_val(p, hi)).to_f64();
        ln_hi[n] = hi;
        ln_lo[n] = lo;
    }
    let table_time = t0.elapsed().as_secs_f64();

    // Verify
    println!("    ln(1+1/1) = {:.18e} + {:.18e}", ln_hi[1], ln_lo[1]);
    println!("    f64 ln(2) = {:.18e}", 2.0f64.ln());
    println!("    DD ln(2)  = {:.18e}", ln_hi[1] + ln_lo[1]);
    println!("    lo/hi     = {:.3e}", (ln_lo[1] / ln_hi[1]).abs());
    println!("  \x1b[32m✓ MPFR-128 ln table ready in {:.3}s\x1b[0m", table_time);

    // Step 2: GPU DD Gram build
    println!();
    let mut gpu_data = vec![0.0f64; dim * dim];
    let t0 = Instant::now();
    let status = unsafe {
        gpu_gram_build_dd(
            gpu_data.as_mut_ptr(), max_n as i32,
            ln_hi.as_ptr(), ln_lo.as_ptr(), (ln_max + 1) as i32,
        )
    };
    let gpu_time = t0.elapsed().as_secs_f64();
    if status != 0 { eprintln!("  ✗ GPU kernel failed"); return; }
    println!("  \x1b[32m✓ GPU DD Gram matrix built in {:.3}s\x1b[0m", gpu_time);

    // Step 3: Compare
    let cache_dir = cache::cache_dir();
    let mut cpu_ref = None;
    if let Ok(entries) = std::fs::read_dir(&cache_dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with("gram_N") && name.ends_with(".bin") {
                if let Some(g) = cache::load_gram(&entry.path()) {
                    if g.max_n >= max_n
                        && cpu_ref.as_ref().is_none_or(|c: &cathedral_utils::gram::GramMatrix| g.precision > c.precision) {
                            cpu_ref = Some(g);
                        }
                }
            }
        }
    }

    if let Some(ref cpu) = cpu_ref {
        let mut max_rel = 0.0f64;
        let mut sum_rel = 0.0f64;
        let mut worst_j = 0usize;
        let mut worst_k = 0usize;
        let mut count = 0usize;
        for i in 0..dim {
            for j in i..dim {
                let cv = cpu.data[i * cpu.max_dim + j];
                let gv = gpu_data[i * dim + j];
                if cv.abs() > 1e-30 {
                    let rel = ((gv - cv) / cv).abs();
                    if rel > max_rel { max_rel = rel; worst_j = i+2; worst_k = j+2; }
                    sum_rel += rel; count += 1;
                }
            }
        }
        let mean_rel = sum_rel / count as f64;
        let digits = if mean_rel > 0.0 { -mean_rel.log10() } else { 16.0 };
        println!();
        println!("  \x1b[1m═══ GPU DD vs CPU MPFR-{} ═══\x1b[0m", cpu.precision);
        println!("    max rel error:  {:.3e} (G({},{}))", max_rel, worst_j, worst_k);
        println!("    mean rel error: {:.3e}", mean_rel);
        println!("    effective digits: \x1b[32m{:.1}\x1b[0m", digits);
        println!("    entries: {}", count);
    }

    // d²
    println!();
    let bvec = arith::b_vector(dim);
    let g_mat = nalgebra::DMatrix::from_fn(dim, dim, |i, j| gpu_data[i * dim + j]);
    let bv = nalgebra::DVector::from_column_slice(&bvec[..dim]);
    if let Some(chol) = g_mat.cholesky() {
        let c = chol.solve(&bv);
        let d2 = 1.0 - bv.dot(&c);
        println!("  \x1b[32md²_{} (GPU DD) = {:.15e}\x1b[0m", max_n, d2);
        if let Some(ref cpu) = cpu_ref {
            let (sub, _) = cpu.extract_submatrix(max_n);
            let g_cpu = nalgebra::DMatrix::from_fn(dim, dim, |i, j| sub[i * dim + j]);
            if let Some(chol_cpu) = g_cpu.cholesky() {
                let c2 = chol_cpu.solve(&bv);
                let d2_cpu = 1.0 - bv.dot(&c2);
                println!("  d²_{} (CPU)    = {:.15e}", max_n, d2_cpu);
                println!("  agreement:     {:.3e}", (d2 - d2_cpu).abs() / d2_cpu.abs());
            }
        }
    }

    println!();
    println!("  \x1b[1mTiming:\x1b[0m  MPFR ln table {:.3}s + GPU {:.3}s = {:.3}s total",
        table_time, gpu_time, table_time + gpu_time);
    println!();
}
