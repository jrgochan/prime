//! Hardy Z zero finder — hunt zeros at ANY height using the Riemann-Siegel formula.
//!
//! Precision modes:
//!   --hd       : DD arg reduction + precomputed log table (~5× slower, t ≈ 10^15)
//!   --hd-full  : Full DD cos (Taylor series) (~100× slower, t ≈ 10^28)
//!   (default)  : Standard f64 (fast, t ≈ 10^12)

use cathedral_utils::riemann_siegel::{
    hardy_z, hardy_z_hd, hardy_z_hd_fast_with_table, DdLogTable,
};
use cathedral_utils::zeta_zeros;
use std::f64::consts::PI;
use std::time::Instant;

/// HD precision level.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum HdMode {
    Off,
    Fast,
    Full,
}

pub fn run(t_start: f64, t_end: f64, refine: bool, hd: HdMode) {
    let mode_label = match hd {
        HdMode::Off => "Standard (f64 ~15 digits)",
        HdMode::Fast => "HD Fast (DD log table + f64 cos)",
        HdMode::Full => "HD Full (DD everywhere — SLOW)",
    };
    println!("🌀 HARDY Z ZERO FINDER in [{:.2}, {:.2}]", t_start, t_end);
    println!("   Precision: {}", mode_label);

    let n_max = ((t_end / (2.0 * PI)).sqrt()) as usize;
    let expected_gap = zeta_zeros::expected_zero_gap(t_start);

    println!(
        "   Riemann-Siegel terms: ~{} | Expected gap: {:.4} | Expected zeros: ~{:.0}",
        n_max,
        expected_gap,
        zeta_zeros::riemann_n_of_t(t_end) - zeta_zeros::riemann_n_of_t(t_start)
    );

    // Precompute DD log table if using HD fast mode
    let table = if hd == HdMode::Fast {
        let build_start = Instant::now();
        let t = DdLogTable::new(n_max);
        let build_time = build_start.elapsed();
        println!(
            "   DD log table: {} entries precomputed in {:.2?}",
            n_max, build_time
        );
        Some(t)
    } else {
        None
    };

    println!();

    let start = Instant::now();

    // Dispatcher closure
    let z_eval = |t: f64| -> f64 {
        match hd {
            HdMode::Off => hardy_z(t),
            HdMode::Fast => hardy_z_hd_fast_with_table(t, table.as_ref().unwrap()),
            HdMode::Full => hardy_z_hd(t),
        }
    };

    let dt = (expected_gap * 0.2).max(0.001).min(0.1);
    let mut t = t_start;
    let mut z_prev = z_eval(t);
    let mut zeros = Vec::new();

    while t < t_end {
        let t_next = t + dt;
        let z_next = z_eval(t_next);

        if z_prev * z_next < 0.0 {
            let (mut lo, mut hi) = (t, t_next);
            let mut zlo = z_prev;
            for _ in 0..64 {
                let mid = (lo + hi) / 2.0;
                let zm = z_eval(mid);
                if zlo * zm < 0.0 {
                    hi = mid;
                } else {
                    lo = mid;
                    zlo = zm;
                }
            }
            zeros.push((lo + hi) / 2.0);
        }

        t = t_next;
        z_prev = z_next;
    }

    let elapsed = start.elapsed();

    println!(
        "    {:>4}  {:>20}  {:>12}  {:>12}  {:>12}",
        "#", "t (zero)", "Z(t-ε)", "Z(t+ε)", "Gap from prev"
    );
    println!(
        "    {:>4}  {:>20}  {:>12}  {:>12}  {:>12}",
        "────", "────────────────────", "────────────", "────────────", "─────────────"
    );

    for (i, &z) in zeros.iter().enumerate() {
        let z_before = z_eval(z - 0.001);
        let z_after = z_eval(z + 0.001);
        let gap = if i > 0 {
            format!("{:.6}", z - zeros[i - 1])
        } else {
            "—".to_string()
        };

        let known_marker = match zeta_zeros::nearest_zero(z) {
            Some((_, kz)) if (kz - z).abs() < 0.01 => " ✓",
            _ => " ★",
        };

        println!(
            "    {:>4}  {:>20.14}  {:>12.6}  {:>12.6}  {:>12}{}",
            i + 1,
            z,
            z_before,
            z_after,
            gap,
            known_marker
        );
    }

    println!();
    println!(
        "  Found {} zeros in {:.2?} ({:.1} zeros/sec)",
        zeros.len(),
        elapsed,
        zeros.len() as f64 / elapsed.as_secs_f64()
    );
    println!("  ✓ = matches known table  ★ = newly computed");

    if refine && zeros.len() >= 2 {
        println!();
        println!("  ── Gap Statistics ──");
        let gaps: Vec<f64> = zeros.windows(2).map(|w| w[1] - w[0]).collect();
        let mean_gap = gaps.iter().sum::<f64>() / gaps.len() as f64;
        let min_gap = gaps.iter().cloned().fold(f64::MAX, f64::min);
        let max_gap = gaps.iter().cloned().fold(0.0f64, f64::max);
        let expected = zeta_zeros::expected_zero_gap((t_start + t_end) / 2.0);

        println!(
            "    Mean gap:     {:.6} (expected: {:.6})",
            mean_gap, expected
        );
        println!("    Min gap:      {:.6}", min_gap);
        println!("    Max gap:      {:.6}", max_gap);
        println!(
            "    Ratio max/mean: {:.3} (GUE predicts ~2.5–3.0)",
            max_gap / mean_gap
        );
    }
}
