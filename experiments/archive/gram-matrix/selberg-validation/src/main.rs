#![allow(unused, dead_code)]
/// Quick verification: does the CONSTANT witness v_k = c achieve O(1/log N)?
///
/// For v_k = c (constant), f(x) = c · Σ{k/x} = c·F(x).
/// L² error = 1 - 2c·B + c²·Q where B = ∫F, Q = ∫F².
/// Optimal c = B/Q gives L² = 1 - B²/Q = Var(F)/Q.

use std::io::Write;

const N_MAX: usize = 1000;
const QUAD_PTS: usize = 50_000;

fn main() {
    println!("Constant Witness Analysis\n");

    let basis_ip: Vec<f64> = (0..=N_MAX)
        .map(|k| if k == 0 { 0.0 } else { compute_basis_ip(k) })
        .collect();

    let mut file = std::fs::File::create("results/constant_witness.csv").unwrap();
    writeln!(file, "N,B,Q,B_sq_over_Q,l2_error,l2_times_logN,l2_times_N,var_F,var_over_B_sq").unwrap();

    println!("{:>5}  {:>10}  {:>10}  {:>10}  {:>10}  {:>10}  {:>10}",
        "N", "B=Σb_k", "Q=ΣG_jk", "1-B²/Q", "err·logN", "err·N", "Var(F)/B²");
    println!("{}", "─".repeat(80));

    for n in (2..=20).chain((25..=100).step_by(5)).chain((100..=N_MAX).step_by(25)) {
        let dim = n - 1;
        let log_n = (n as f64).ln();

        // B = Σ b_k
        let big_b: f64 = (1..=dim).map(|k| basis_ip[k]).sum();

        // Q = Σ_{j,k} G_{jk} = ∫₀¹ F(x)² dx where F = Σ{k/x}
        // Compute by quadrature
        let dx = 1.0 / QUAD_PTS as f64;
        let mut big_q = 0.0f64;
        for i in 0..QUAD_PTS {
            let x = (i as f64 + 0.5) * dx;
            let f_x: f64 = (1..=dim).map(|k| fract(k as f64 / x)).sum();
            big_q += f_x * f_x;
        }
        big_q *= dx;

        let l2_error = 1.0 - big_b * big_b / big_q;
        let var_f = big_q - big_b * big_b;

        writeln!(file, "{},{:.10},{:.10},{:.10},{:.10},{:.10},{:.10},{:.10},{:.10}",
            n, big_b, big_q, big_b*big_b/big_q,
            l2_error, l2_error * log_n, l2_error * (dim as f64),
            var_f, var_f / (big_b * big_b)
        ).unwrap();

        println!("{:>5}  {:>10.4}  {:>10.2}  {:>10.6}  {:>10.6}  {:>10.4}  {:>10.6}",
            n, big_b, big_q, l2_error, l2_error * log_n, l2_error * dim as f64,
            var_f / (big_b * big_b));
    }
    println!("\nOutput: results/constant_witness.csv");
}

fn compute_basis_ip(k: usize) -> f64 {
    let kf = k as f64;
    let mut sum = 0.0;
    for n in k..=(10 * k + 50000) {
        let nf = n as f64;
        sum += kf * ((nf + 1.0) / nf).ln() - kf / (nf + 1.0);
    }
    sum
}

fn fract(x: f64) -> f64 { x - x.floor() }
